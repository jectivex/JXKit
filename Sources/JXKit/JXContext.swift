import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

/// A JavaScript execution context. This is a cross-platform analogue to the Objective-C `JavaScriptCore.JSContext`.
///
/// This wraps a `JSGlobalContextRef`, and is the equivalent of `JavaScriptCore.JSContext`
open class JXContext {
    /// Context configuration.
    public struct Configuration {
        /// Configure the default configuration for new contexts.
        public static var `default` = Configuration()

        /// Whether scripts evaluated by this context should be assessed in `strict` mode. Defaults to `true`.
        public var strict: Bool
        
        /// Whether dynamic reloading of JavaScript script resources is enabled.
        public var isDynamicReloadEnabled: Bool {
            return scriptLoader.didChange != nil
        }

        /// The script loader to use for loading JavaScript script files. If the loader vends a non-nil `didChange` listener collection, dynamic reloading will be enabled.
        public var scriptLoader: JXScriptLoader

        /// The logging function to use for JX log messages.
        public var log: (String) -> Void
        
        public init(strict: Bool = true, scriptLoader: JXScriptLoader? = nil, log: @escaping (String) -> Void = { print($0) }) {
            self.strict = strict
            self.scriptLoader = scriptLoader ?? DefaultScriptLoader()
            self.log = log
        }
    }
    
    /// The virtual machine associated with this context
    public let vm: JXVM

    /// Context confguration.
    public let configuration: Configuration

    /// The underlying `JSGlobalContextRef` that is wrapped by this context
    public let contextRef: JSGlobalContextRef

    private lazy var scriptManager = ScriptManager(context: self)
    private var evalInitialized = false
    private var tryingRecursionGuard = false

    /// Class for instances that can hold references to peers (which ``JSObjectGetPrivate`` needs to work)
    lazy var peerClass: JSClassRef = {
        var def = JSClassDefinition()
        def.finalize = {
            if let ptr = JSObjectGetPrivate($0) {
                // free any associated object that may be attached
                ptr.assumingMemoryBound(to: AnyObject?.self).deinitialize(count: 1)
                ptr.deallocate()
            }
        }
        self.peerClassCreated = true
        return JSClassCreate(&def)
    }()

    /// Whether we have instantated the peer class in this context or not
    private var peerClassCreated = false

    /// Creates `JXContext` with the given `JXVM`. `JXValue` references may be used interchangably with multiple instances of `JXContext` with the same `JXVM`, but sharing between  separate `JXVM`s will result in undefined behavior.
    ///
    /// - Parameters:
    ///   - vm: The shared virtual machine to use; defaults  to creating a new VM per context.
    ///   - configuration: Context configuration.
    public init(vm: JXVM = JXVM(), configuration: Configuration = .default) {
        self.vm = vm
        self.contextRef = JSGlobalContextCreateInGroup(vm.groupRef, nil)
        self.configuration = configuration
    }

    deinit {
        if peerClassCreated == true {
            JSClassRelease(peerClass)
        }
        JSGlobalContextRelease(contextRef)
    }

    /// For use by service providers only.
    public var spi: JXContextSPI?
}

extension JXContext {
    /// Evaluate the given JavaScript.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - this: Substitute a custom value to act as JavaScript `this` for the evaluation.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate any scripts referenced via `require`.
    /// - Returns: The result of executing the JavaScript.
    /// - Warning: The JavaScript is executed in the global scope. For scoped execution, consider `evalClosure`.
    @discardableResult public func eval(_ script: String, this: JXValue? = nil, root: URL? = nil) throws -> JXValue {
        return try scriptManager.eval(source: script, type: .inline, this: this, root: root)
    }

    /// Evaluate the given JavaScript script resource.
    ///
    /// - Parameters:
    ///   - resource: The JavaScript file containing code to evaluate.
    ///   - this: Substitute a custom value to act as JavaScript `this` for the evaluation.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate `resource` and any scripts referenced via `require`.
    /// - Returns: The result of executing the JavaScript.
    /// - Warning: The JavaScript is executed in the global scope. For scoped execution, consider `evalClosure`.
    @discardableResult public func eval(resource: String, this: JXValue? = nil, root: URL) throws -> JXValue {
        return try scriptManager.eval(source: resource, type: .resource, this: this, root: root)
    }
    
    /// Evaluate the given JavaScript as a closure, giving it its own scope for local functions and vars.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - arguments: Array of values to make available to the script as $0, $1, etc.
    ///   - this: Substitute a custom value to act as JavaScript `this` for the evaluation.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate any scripts referenced via `require`.
    /// - Returns: The value you `return` from the given JavaScript, otherwise `undefined`.
    @discardableResult public func evalClosure(_ script: String, withArguments arguments: [JXValue] = [], this: JXValue? = nil, root: URL? = nil) throws -> JXValue {
        return try scriptManager.evalClosure(source: script, type: .inline, withArguments: arguments, this: this, root: root)
    }

    /// Evaluate the given JavaScript as a closure, giving it its own scope for local functions and vars.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - arguments: Array of values to make available to the script as $0, $1, etc.
    ///   - this: Substitute a custom value to act as JavaScript `this` for the evaluation.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate any scripts referenced via `require`.
    /// - Returns: The value you `return` from the given JavaScript, otherwise `undefined`.
    @discardableResult public func evalClosure(resource: String, withArguments arguments: [JXValue] = [], this: JXValue? = nil, root: URL) throws -> JXValue {
        return try scriptManager.evalClosure(source: resource, type: .resource, withArguments: arguments, this: this, root: root)
    }

    /// Evaluate the given JavaScript as a closure, giving it its own scope for local functions and vars.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - this: Substitute a custom value to act as JavaScript `this` for the evaluation.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate any scripts referenced via `require`.
    /// - Returns: The value you `return` from the given JavaScript, otherwise `undefined`.
    @discardableResult public func evalClosure(_ script: String, withArguments arguments: [Any?], this: JXValue? = nil, root: URL? = nil) throws -> JXValue {
        let jxarguments = try arguments.map { try convey($0) }
        return try evalClosure(script, withArguments: jxarguments, this: this, root: root)
    }

    /// Evaluate the given JavaScript as a closure, giving it its own scope for local functions and vars.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - arguments: Array of values to make available to the script as $0, $1, etc.
    ///   - this: Substitute a custom value to act as JavaScript `this` for the evaluation.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate any scripts referenced via `require`.
    /// - Returns: The value you `return` from the given JavaScript, otherwise `undefined`.
    @discardableResult public func evalClosure(resource: String, withArguments arguments: [Any?], this: JXValue? = nil, root: URL) throws -> JXValue {
        let jxarguments = try arguments.map { try convey($0) }
        return try evalClosure(resource: resource, withArguments: jxarguments, this: this, root: root)
    }

    /// Evaluate the given JavaScript as a module.
    ///
    /// - Parameters:
    ///   - script: The JavaScript code to evaluate.
    ///   - keyPath: A value the module integrates exports into.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate any scripts referenced via `require`.
    /// - Returns: `module.exports`
    @discardableResult public func evalModule(_ script: String, integratingExports keyPath: String? = nil, root: URL? = nil) throws -> JXValue {
        return try scriptManager.evalModule(source: script, type: .inline, integratingExports: keyPath, root: root)
    }

    /// Evaluate the given JavaScript script resource as a module.
    ///
    /// - Parameters:
    ///   - resource: The JavaScript file containing code to evaluate.
    ///   - keyPath: A value the module integrates exports into.
    ///   - root: The root of the JavaScript resources, typically `Bundle.main.resourceURL` or `Bundle.module.resourceURL`. This is used to locate `resource` and any scripts referenced via `require`.
    /// - Returns: `module.exports`
    @discardableResult public func evalModule(resource: String, integratingExports keyPath: String? = nil, root: URL) throws -> JXValue {
        return try scriptManager.evalModule(source: resource, type: .resource, integratingExports: keyPath, root: root)
    }

    /// Internal function called by the `ScriptManager` to evaluate JavaScript code.
    func evalInternal(script: String, this: JXValue?) throws -> JXValue {
        try initializeEval()
        do {
            // Allow SPI to perform pre-eval actions or even e.g. execute macros
            if let spiResult = try spi?.eval(script, this: this, in: self) {
                return spiResult
            }

            let script = script.withCString(JSStringCreateWithUTF8CString)
            defer { JSStringRelease(script) }

            let resultRef = try trying {
                JSEvaluateScript(contextRef, script, this?.valueRef, nil, 0, $0)
            }
            return resultRef.map({ JXValue(context: self, valueRef: $0) }) ?? JXValue(undefinedIn: self)
        } catch {
            throw JXError(cause: error, script: script)
        }
    }

    private func initializeEval() throws {
        guard !evalInitialized else {
            return
        }
        if configuration.strict {
            let useStrict = "\"use strict\";\n" // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode
            let script = useStrict.withCString(JSStringCreateWithUTF8CString)
            defer { JSStringRelease(script) }
            let _ = try trying {
                JSEvaluateScript(contextRef, script, nil, nil, 0, $0)
            }
        }
        let log = JXValue(newFunctionIn: self) { [weak self] context, this, args in
            guard let self else {
                return context.undefined()
            }
            guard args.count == 1 else {
                throw JXError(message: "'console.log' expects a single argument")
            }
            try self.configuration.log(args[0].string)
            return self.undefined()
        }
        try global["console"].setProperty("log", log)
        evalInitialized = true
    }
    
    /// Checks for syntax errors in a string of JavaScript.
    ///
    /// - Parameters:
    ///   - script: The script to check for syntax errors.
    ///   - source: The script's source file. This is only used when reporting exceptions. Pass `nil` to omit source file information in exceptions.
    ///   - startingLineNumber: An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions.
    /// - Returns: true if the script is syntactically correct; otherwise false.
    public func checkSyntax(_ script: String, source: String? = nil, startingLineNumber: Int = 0) throws -> Bool {
        let script = script.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(script) }

        let sourceString = source?.withCString(JSStringCreateWithUTF8CString)
        defer { sourceString.map(JSStringRelease) }

        return try trying {
            JSCheckScriptSyntax(contextRef, script, sourceString, Int32(startingLineNumber), $0)
        }
    }

    /// Performs a JavaScript garbage collection.
    ///
    /// During JavaScript execution, you are not required to call this function; the JavaScript engine will garbage collect as needed.
    /// JavaScript values created within a context group are automatically destroyed when the last reference to the context group is released.
    public func garbageCollect() { JSGarbageCollect(contextRef) }

    /// The global object.
    public var global: JXValue {
        JXValue(context: self, valueRef: JSContextGetGlobalObject(contextRef))
    }

    /// Invokes the given closure with the bytes without copying.
    ///
    /// - Parameters:
    ///   - source: The data to use.
    ///   - block: The block that passes the temporary JXValue wrapping the buffer data.
    /// - Returns: The result of the closure.
    public func withArrayBuffer<T>(source: Data, block: (JXValue) throws -> (T)) throws -> T {
        var source = source
        return try source.withUnsafeMutableBytes { bytes in
            let buffer = try JXValue(newArrayBufferWithBytesNoCopy: bytes, deallocator: { _ in
                //print("buffer deallocated")
            }, in: self)
            return try block(buffer)
        }
    }

    /// Returns the global "Object" prototype.
    ///
    /// The Object type represents one of JavaScript's data types. It is used to store various keyed collections and more complex entities. Objects can be created using the Object() constructor or the object initializer / literal syntax.
    ///
    /// See: [MDN Object Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
    public var objectPrototype: JXValue {
        get throws {
            try global["Object"]
        }
    }

    /// Returns the global "Date" prototype.
    ///
    /// JavaScript Date objects represent a single moment in time in a platform-independent format. Date objects contain a Number that represents milliseconds since 1 January 1970 UTC.
    ///
    /// See: [MDN Date Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date)
    public var datePrototype: JXValue {
        get throws {
            try global["Date"]
        }
    }

    /// Returns the global "Array" prototype.
    ///
    /// The Array object, as with arrays in other programming languages, enables storing a collection of multiple items under a single variable name, and has members for performing common array operations.
    ///
    /// See: [MDN Array Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array)
    public var arrayPrototype: JXValue {
        get throws {
            try global["Array"]
        }
    }

    /// Returns the global "ArrayBuffer" prototype.
    ///
    /// The ArrayBuffer object is used to represent a generic, fixed-length raw binary data buffer.
    ///
    /// It is an array of bytes, often referred to in other languages as a "byte array". You cannot directly manipulate the contents of an ArrayBuffer; instead, you create one of the typed array objects or a DataView object which represents the buffer in a specific format, and use that to read and write the contents of the buffer.
    ///
    /// The ArrayBuffer() constructor creates a new ArrayBuffer of the given length in bytes. You can also get an array buffer from existing data, for example, from a Base64 string or from a local file.
    ///
    /// See: [MDN ArrayBuffer Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer)
    public var arrayBufferPrototype: JXValue {
        get throws {
            try global["ArrayBuffer"]
        }
    }

    /// Returns the global "Error" prototype.
    ///
    /// Error objects are thrown when runtime errors occur. The Error object can also be used as a base object for user-defined exceptions.
    ///
    /// See: [MDN Error Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error)
    public var errorPrototype: JXValue {
        get throws {
            try global["Error"]
        }
    }

    /// Returns the global "Promise" prototype.
    ///
    /// The Promise object represents the eventual completion (or failure) of an asynchronous operation and its resulting value.
    ///
    /// A Promise is a proxy for a value not necessarily known when the promise is created. It allows you to associate handlers with an asynchronous action's eventual success value or failure reason. This lets asynchronous methods return values like synchronous methods: instead of immediately returning the final value, the asynchronous method returns a promise to supply the value at some point in the future.
    ///
    /// See: [MDN Promise Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)
    public var promisePrototype: JXValue {
        get throws {
            try global["Promise"]
        }
    }

    /// Returns the global "Proxy" prototype.
    ///
    /// The Proxy object enables you to create a proxy for another object, which can intercept and redefine fundamental operations for that object.
    ///
    /// The Proxy object allows you to create an object that can be used in place of the original object, but which may redefine fundamental Object operations like getting, setting, and defining properties. Proxy objects are commonly used to log property accesses, validate, format, or sanitize inputs, and so on.
    ///
    /// See: [MDN Proxy Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Proxy)
    public var proxyPrototype: JXValue {
        get throws {
            try global["Proxy"]
        }
    }

    /// Creates a new `null` instance in the context.
    public func null() -> JXValue {
        JXValue(nullIn: self)
    }

    /// Creates a new `undefined` instance in the context.
    public func undefined() -> JXValue {
        JXValue(undefinedIn: self)
    }

    /// Creates a new boolean with the given value in the context.
    public func boolean(_ value: Bool) -> JXValue {
        JXValue(bool: value, in: self)
    }

    /// Creates a new number with the given value in the context.
    public func number<F: BinaryFloatingPoint>(_ value: F) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    /// Creates a new number with the given value in the context.
    public func number<I: BinaryInteger>(_ value: I) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    /// Creates a new string with the given value in the context.
    public func string<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(string: String(value), in: self)
    }

    /// Creates a new Symbol with the given name in the context.
    public func symbol<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(symbol: String(value), in: self)
    }

    /// Creates a new object in this context and assigns it the given peer object.
    public func object(peer: AnyObject? = nil) -> JXValue {
        guard let peer = peer else {
            return JXValue(newObjectIn: self)
        }

        let info: UnsafeMutablePointer<AnyObject?> = .allocate(capacity: 1)
        info.initialize(to: peer)
        let value = JXValue(context: self, valueRef: JSObjectMake(self.contextRef, peerClass, info))
        return value
    }

    /// Creates an object with the given dictionary of properties.
    ///
    /// - Parameters:
    ///   - properties: A dictionary of properties, such as that created by `JXValue.dictionary`.
    public func object(fromDictionary properties: [String: JXValue]) throws -> JXValue {
        let object = self.object()
        try properties.forEach { entry in
            try object.setProperty(entry.key, entry.value)
        }
        return object
    }

    /// Creates an object with the given dictionary of properties.
    public func object(fromDictionary properties: [String: Any]) throws -> JXValue {
        let jxproperties = try properties.reduce(into: [:]) { result, entry in
            result[entry.key] = try convey(entry.value)
        }
        return try object(fromDictionary: jxproperties)
    }

    /// Creates an instance of the named class or constructor function.
    ///
    /// - Parameters:
    ///   - typeName: Class or constructor function name.
    ///   - arguments: The arguments to pass to the constructor.
    public func `new`(_ typeName: String, withArguments arguments: [JXValue] = []) throws -> JXValue {
        // The only way to create a new class instance is with 'new X(...)', so generate that code
        let argumentsString = (0..<arguments.count).map({ "$\($0)" }).joined(separator: ",")
        let code = "return new \(typeName)(\(argumentsString))"
        return try evalClosure(code, withArguments: arguments)
    }

    /// Creates an instance of the named class or constructor function.
    ///
    /// - Parameters:
    ///   - typeName: Class or constructor function name.
    ///   - arguments: The arguments to pass to the constructor. The arguments will be `conveyed` to `JXValues`.
    public func `new`(_ typeName: String, withArguments arguments: [Any]) throws -> JXValue {
        let jxarguments = try arguments.map { try convey($0) }
        return try self.new(typeName, withArguments: jxarguments)
    }

    /// Creates a new array in this context.
    public func array(_ values: [JXValue]) throws -> JXValue {
        let array = try JXValue(newArrayIn: self)
        for (index, value) in values.enumerated() {
            try array.setElement(value, at: index)
        }
        return array
    }

    /// Creates a new array in this context.
    public func array(_ values: [Any]) throws -> JXValue {
        let jxvalues = try values.map { try convey($0) }
        return try array(jxvalues)
    }

    public func date(_ value: Date) throws -> JXValue {
        try JXValue(date: value, in: self)
    }

    public func data<D: DataProtocol>(_ value: D) throws -> JXValue {
        try JXValue(newArrayBufferWithBytes: value, in: self)
    }

    /// Create a JavaScript Error with the given cause.
    ///
    /// - Seealso: ``JXValue/cause``
    public func error<E: Error>(_ error: E) throws -> JXValue {
        try JXValue(newErrorFromCause: error, in: self)
    }

    /// Attempts to convey the given value into this JavaScript context.
    ///
    /// - Seealso: ``JXValue/convey(to:)`` to convey back from JavaScript.
    public func convey(_ value: Any?) throws -> JXValue {
        guard let value else {
            return null()
        }
        return try conveyIfConvertible(value) ?? spi?.toJX(value, in: self) ?? conveyEncodable(value)
    }

    private func conveyIfConvertible(_ value: Any) throws -> JXValue? {
        if let convertible = value as? JXConvertible {
            return try convertible.toJX(in: self)
        }
        if let rawRepresentable = value as? (any RawRepresentable) {
            return try convey(rawRepresentable.rawValue)
        }
        if value is () {
            return undefined()
        }
        return nil
    }

    private func conveyEncodable(_ value: Any) throws -> JXValue {
        guard let encodable = value as? Encodable else {
            // Encodable is our last fallback; this value cannot be conveyed
            throw JXError.cannotConvey(type(of: value), spi: spi, format: "Unable to convey native value '\(String(describing: value))' of type '%@' to a JavaScript value")
        }
        return try encode(encodable)
    }

    /// Create a ``JXValue`` from the given JSON string.
    ///
    /// - Parameters:
    ///   - string: The JSON string to parse.
    /// - Returns: The value if it could be created.
    public func json(_ string: String) throws -> JXValue {
        if let value = JXValue(json: string, in: self) {
            return value
        }
        throw JXError(message: "Unable to create a JavaScript value from the given JSON", script: string)
    }

    /// Attempts the operation whose failure is expected to set the given error pointer.
    ///
    /// When the error pointer is set, a ``JXError`` will be thrown.
    func trying<T>(function: (UnsafeMutablePointer<JSValueRef?>) throws -> T?) throws -> T! {
        var errorPointer: JSValueRef?
        let result = try function(&errorPointer)
        if let errorPointer = errorPointer {
            // Creating a JXError from the errorPointer may involve calling functions that throw errors,
            // though the errors are all handled internally. Guard against infinite recursion by short-
            // circuiting those cases
            if tryingRecursionGuard {
                return result
            } else {
                tryingRecursionGuard = true
                defer { tryingRecursionGuard = false }
                let error = JXValue(context: self, valueRef: errorPointer)
                throw JXError(jsError: error)
            }
        } else {
            return result
        }
    }
}

extension JXContext {
    /// Listen for changes to JavaScript script  IDs, if change monitoring is supported by the `JXScriptLoader`.
    public func onScriptsDidChange(perform: @escaping (Set<String>) -> Void) -> JXCancellable? {
        return scriptManager.didChange.add(perform)
    }
    
    /// Perform the given code while tracking its access to JavaScript script IDs.
    public func trackingScriptsAccess<V>(perform: @escaping () throws -> V) throws -> (accessed: Set<String>, value: V) {
        var accessed = Set<String>()
        let subscription = scriptManager.didAccess.add { accessed.formUnion($0) }
        defer { subscription.cancel() }
        let value = try perform()
        return (accessed, value)
    }
}

/// Optional service provider integration points.
public protocol JXContextSPI {
    func eval(_ script: String, this: JXValue?, in: JXContext) throws -> JXValue?
    func toJX(_ value: Any, in context: JXContext) throws -> JXValue?
    func fromJX<T>(_ value: JXValue, to type: T.Type) throws -> T?
    func require(_ value: JXValue) throws -> String?
    func errorDetail(conveying type: Any.Type) -> String?
}

extension JXContextSPI {
    public func eval(_ script: String, this: JXValue?, in: JXContext) throws -> JXValue? {
        return nil
    }
        
    public func toJX(_ value: Any, in context: JXContext) throws -> JXValue? {
        return nil
    }

    public func fromJX<T>(_ value: JXValue, to type: T.Type) throws -> T? {
        return nil
    }
    
    public func require(_ value: JXValue) throws -> String? {
        return nil
    }
    
    public func errorDetail(conveying type: Any.Type) -> String? {
        return nil
    }
}
