import struct Foundation.URL

/// Internal type to manage JavaScript script loading and caching.
final class ScriptManager {
    private weak var context: JXContext?
    private var scriptsSubscription: JXCancellable?
    private var requireFunctionInitialized = false
    private var moduleCache: [String: Module] = [:]
    private var evalStack: [(key: String?, url: URL?, root: URL)] = []
    private var scriptKeyGenerator = 0
    
    init(context: JXContext) {
        self.context = context
        self.scriptsSubscription = context.configuration.scriptLoader.didChange?.add { [weak self] in
            self?.scriptsDidChange(urls: $0)
        }
    }
    
    /// Invoked when scripts change.
    lazy var didChange = JXListenerCollection<(Set<String>) -> Void>()
    
    /// Invoked when scripts are accessed.
    lazy var didAccess = JXListenerCollection<(Set<String>) -> Void>()
    
    /// Perform a set of operations where any given resources use the given root URL.
    func withRoot(_ root: URL, perform: () throws -> JXValue) throws -> JXValue {
        try initializeRequireFunction()
        evalStack.append((nil, nil, root))
        defer { evalStack.removeLast() }
        return try perform()
    }
    
    /// Evaluate the given script as a JavaScript module, returning its exports.
    func eval(resource: String, this: JXValue?) throws -> JXValue {
        guard let context else {
            throw JXError.contextDeallocated()
        }
        guard let evalState = evalStack.last else {
            throw JXError.unknownScriptRoot(for: resource)
        }
        let url = try context.configuration.scriptLoader.scriptURL(resource: resource, relativeTo: evalState.url, root: evalState.root)
        guard let js = try context.configuration.scriptLoader.loadScript(from: url) else {
            throw JXError.scriptNotFound(resource)
        }
        // Add this resource to the stack so that it is recorded as a referrer of any modules it requires.
        // This resource is not a module, however, and so it doesn't have its own referrers, and changes to it will not propagate
        let key = key(for: url)
        didAccess.forEach { $0([key]) }
        evalStack.append((key, url, evalState.root))
        defer { evalStack.removeLast() }
        return try context.eval(js, this: this)
    }
    
    /// Evaluate the given script as a JavaScript module, returning its exports.
    ///
    /// - Parameters:
    ///   - keyPath: If given, the module exports will be integrated into the object at this key path from `global`.
    func evalModule(_ script: String, integratingExports keyPath: String? = nil) throws -> JXValue {
        // We only need to treat this as a full cached module if we have to integrate it into a key path and
        // it might include other namespaces or modules, which means we'll need to re-integrate if a dependency changes.
        // Otherwise we can treat it as transient
        if keyPath != nil, context?.configuration.moduleRequireEnabled == true, context?.configuration.isDynamicReloadEnabled == true {
            return try evalModule(script, resource: nil, integratingExports: keyPath, evalState: evalStack.last)
        } else {
            let exports = try evalTransientModule(script)
            try integrate(exports: exports, into: keyPath)
            return exports
        }
    }
    
    /// Evaluate the given resource as a JavaScript module, returning its exports.
    ///
    /// - Parameters:
    ///   - keyPath: If given, the module exports will be integrated into the object at this key path from `global`.
    func evalModule(resource: String, integratingExports keyPath: String? = nil) throws -> JXValue {
        guard let evalState = evalStack.last else {
            throw JXError.unknownScriptRoot(for: resource)
        }
        return try evalModule(nil, resource: resource, integratingExports: keyPath, evalState: evalState)
    }
    
    private func evalModule(_ script: String?, resource: String?, integratingExports keyPath: String?, evalState: (key: String?, url: URL?, root: URL)?) throws -> JXValue {
        guard let context else {
            throw JXError.contextDeallocated()
        }
        
        let js: String
        var module: Module? = nil
        var url: URL? = nil
        var cacheKey: String? = nil
        if let script {
            js = script
            if context.configuration.isDynamicReloadEnabled {
                let key = "s\(scriptKeyGenerator)"
                scriptKeyGenerator += 1
                module = Module(key: key, type: .js(script, evalState?.root))
            }
        } else if let resource, let evalState {
            let scriptURL = try context.configuration.scriptLoader.scriptURL(resource: resource, relativeTo: evalState.url, root: evalState.root)
            let key = key(for: scriptURL)
            didAccess.forEach { $0([key]) }
            
            // Already have cached exports?
            if var module = moduleCache[key] {
                if context.configuration.isDynamicReloadEnabled {
                    // Setup references before eval in case there are errors: when the script updates
                    // we want to be sure to update its references as well
                    module.referencedBy(key: evalState.key)
                    module.integratedInto(keyPath: keyPath)
                    moduleCache[key] = module
                }
                let exports = try module.exports(in: context)
                try integrate(exports: exports, into: keyPath)
                return exports
            }
            
            guard let script = try context.configuration.scriptLoader.loadScript(from: scriptURL) else {
                throw JXError.scriptNotFound(resource)
            }
            module = Module(key: key, type: .jsResource(scriptURL, evalState.root))
            js = script
            url = scriptURL
            cacheKey = key
        } else {
            throw JXError.internalError("script == nil && (resource == nil || evalState == nil)")
        }
        
        // Create a module reference before evaluating to avoid infinite recursion in the case of circular dependencies.
        // Also see note above about setting references before evaluating in case there is an error
        if var module {
            if context.configuration.isDynamicReloadEnabled {
                if let evalStateKey = evalState?.key {
                    module.referencedBy(key: evalStateKey)
                }
                if let keyPath {
                    module.integratedInto(keyPath: keyPath)
                }
            }
            moduleCache[module.key] = module
        }
        
        var popEvalStackIfNeeded = {}
        if let evalState {
            evalStack.append((module?.key, url, evalState.root))
            popEvalStackIfNeeded = { self.evalStack.removeLast() }
        }
        defer { popEvalStackIfNeeded() }

        let moduleScript = try toModuleScript(js, cacheKey: cacheKey)
        let exports = try context.eval(moduleScript)
        try integrate(exports: exports, into: keyPath)
        return exports
    }
    
    private func initializeRequireFunction() throws {
        guard !requireFunctionInitialized else {
            return
        }
        requireFunctionInitialized = true
        
        guard let context else {
            throw JXError.contextDeallocated()
        }
        
        let require = JXValue(newFunctionIn: context) { [weak self] context, this, args in
            guard let self else {
                return context.undefined()
            }
            guard args.count == 1 else {
                throw JXError(message: "'require' expects a single argument")
            }
            return try self.require(args[0])
        }
        try context.global.setProperty("require", require)
        try context.global.setProperty(Self.moduleExportsCacheObject, context.object())
    }
    
    /// Logic for the `require` JavaScript module function.
    private func require(_ value: JXValue) throws -> JXValue {
        guard !value.isString else {
            return try evalModule(resource: value.string)
        }
        // If something other than a file path is given, maybe the SPI can turn it into a key path
        // that the requiring script is dependent on
        guard try recordKeyPathReference(value) else {
            throw JXError(message: "'require' expects a file path string")
        }
        return value
    }

    /// Record that the given key path was accessed.
    @discardableResult func recordKeyPathReference(_ value: JXValue) throws -> Bool {
        guard let keyPath = try value.context.spi?.require(value) else {
            return false
        }
        didAccess.forEach { $0([keyPath]) }
        guard context?.configuration.isDynamicReloadEnabled == true, let referencedBy = evalStack.last?.key else {
            return true
        }
        // Record which JS modules 'require' a key path just as we record which JS modules
        // 'require' other JS modules. Key paths can change when any scripts they integrate change
        var module = moduleCache[keyPath] ?? Module(key: keyPath, type: .integrated(keyPath))
        if module.referencedBy(key: referencedBy) {
            moduleCache[keyPath] = module
        }
        return true
    }
    
    private func key(for url: URL) -> String {
        if let key = resourceURLToKey[url] {
            return key
        }
        let key = "_jxr\(resourceId)"
        resourceId += 1
        resourceURLToKey[url] = key
        return key
    }
    
    private var resourceURLToKey: [URL: String] = [:]
    private var resourceId = 0

    private func evalTransientModule(_ script: String) throws -> JXValue {
        guard let context else {
            throw JXError.contextDeallocated()
        }
        let moduleScript = try toModuleScript(script)
        return try context.eval(moduleScript)
    }
    
    private func integrate(exports: JXValue, into keyPath: String?) throws {
        guard let keyPath else {
            return
        }
        let (parent, property) = try exports.context.global.keyPath(keyPath)
        try parent[property].integrate(exports)
    }
    
    /// Return the JavaScript to run to evaluate the given script as a module.
    private func toModuleScript(_ script: String, cacheKey: String? = nil) throws -> String {
        try initializeImportFunction()
        let cacheExports: String
        if let cacheKey {
            cacheExports = "\(Self.moduleExportsCacheObject).\(cacheKey) = module.exports;"
        } else {
            cacheExports = ""
        }
        // Cache the empty exports before running the body to vend partial exports in cases of circular dependencies
        // Cache again after running the body in case it resets module.exports = x
        // Note that we use IIFEs to give private scopes and namespaces to the module code
        let js = """
(function() {
    const module = { exports: {} };
    \(cacheExports)
    const exports = module.exports;
    (function() {
        \(script)
    })()
    if (typeof(module.exports) === 'object' && module.exports.import === undefined) {
        module.exports.import = function() { \(Self.importFunction)(this); }
    }
    \(cacheExports)
    return module.exports;
})();
"""
        // print(js)
        return js
    }
    
    fileprivate static let moduleExportsCacheObject = "_jxModuleExportsCache"
    private static let importFunction = "_jxModuleImport"
    private var importFunctionInitialized = false
    
    private func initializeImportFunction() throws {
        guard !importFunctionInitialized else {
            return
        }
        importFunctionInitialized = true
        
        guard let context else {
            throw JXError.contextDeallocated()
        }
        let importFunction = JXValue(newFunctionIn: context) { context, this, args in
            guard args.count == 1 else {
                throw JXError.internalError("import")
            }
            let value = args[0]
            for entry in try value.dictionary {
                // Don't import the import function itself
                if entry.key != "import" {
                    try context.global.setProperty(entry.key, entry.value)
                }
            }
            return context.undefined()
        }
        try context.global.setProperty(Self.importFunction, importFunction)
    }
}

extension ScriptManager {
    private func scriptsDidChange(urls: Set<URL>) {
        // When a module changes, we have to reload that module and also all the modules that reference it,
        // as their exports could also be affected. And so on recursively. Perform a breadth-first traversal
        // of the reference graph to create an ordered list of modules to reload
        let keys = urls.map { key(for: $0) }
        var processKeyQueue = keys
        var seenKeys = Set(keys)
        var reloadKeys: [String] = []
        while !processKeyQueue.isEmpty {
            let key = processKeyQueue.removeFirst()
            reloadKeys.append(key)
            if let module = moduleCache[key] {
                let newKeys = module.referencedByKeys.union(module.integratedIntoKeyPaths).subtracting(seenKeys)
                processKeyQueue += newKeys
                seenKeys.formUnion(newKeys)
            }
        }
        reloadKeys.forEach { reloadModule(for: $0) }
        didChange.forEach { $0(seenKeys) }
    }
    
    // TODO: Error resiliency: use previous exports
    private func reloadModule(for key: String) {
        guard let module = moduleCache[key] else {
            return
        }
        switch module.type {
        case .js(let script, let root):
            do {
                print("Reloading JavaScript module script \(key)...")
                try reloadModule(module, script: script, url: nil, root: root)
            } catch {
                print("JavaScript module reload error: \(error)")
            }
        case .jsResource(let url, let root):
            do {
                print("Reloading JavaScript module at \(url.absoluteString)...")
                try reloadModule(module, script: nil, url: url, root: root)
            } catch {
                print("JavaScript module reload error: \(error)")
            }
        case .integrated:
            // Nothing to do. JS modules will integrate when they reload
            break
        }
    }
    
    private func reloadModule(_ module: Module, script: String?, url: URL?, root: URL?) throws {
        guard let context else {
            throw JXError.contextDeallocated()
        }
        let js: String
        let cacheKey: String?
        if let script {
            js = script
            cacheKey = nil
        } else if let url {
            guard let script = try context.configuration.scriptLoader.loadScript(from: url) else {
                throw JXError.scriptNotFound(url.absoluteString)
            }
            js = script
            cacheKey = module.key
        } else {
            throw JXError.internalError("script == nil && url == nil")
        }
        
        var popEvalStackIfNeeded = {}
        if let root {
            evalStack.append((module.key, url, root))
            popEvalStackIfNeeded = { self.evalStack.removeLast() }
        }
        defer { popEvalStackIfNeeded() }

        let moduleScript = try toModuleScript(js, cacheKey: cacheKey)
        let exports = try context.eval(moduleScript)
        for keyPath in module.integratedIntoKeyPaths {
            try integrate(exports: exports, into: keyPath)
        }
    }
}

private enum ModuleType {
    case js(String, URL?) // script, root URL
    case jsResource(URL, URL) // resource URL, root URL
    case integrated(String) // key path
}

private struct Module {
    let key: String
    let type: ModuleType
    private(set) var referencedByKeys = Set<String>()
    private(set) var integratedIntoKeyPaths = Set<String>()
    
    @discardableResult mutating func referencedBy(key: String?) -> Bool {
        guard let key else {
            return false
        }
        return referencedByKeys.insert(key).inserted
    }
    
    @discardableResult mutating func integratedInto(keyPath: String?) -> Bool {
        guard let keyPath else {
            return false
        }
        return integratedIntoKeyPaths.insert(keyPath).inserted
    }
    
    func exports(in context: JXContext) throws -> JXValue {
        switch type {
        case .js, .jsResource:
            return try context.global[ScriptManager.moduleExportsCacheObject][key]
        case .integrated(let keyPath):
            let (parent, property) = try context.global.keyPath(keyPath)
            return try parent[property]
        }
    }
}
