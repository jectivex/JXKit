import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif
import struct Foundation.URL

/// A JavaScript execution context. This is a cross-platform analogue to the Objective-C `JavaScriptCore.JSContext`.
///
/// This wraps a `JSGlobalContextRef`, and is the equivalent of `JavaScriptCore.JSContext`
open class JXContext {
    /// Context configuration.
    public struct Configuration {
        /// Whether scripts evaluated by this context should be assessed in `strict` mode. Defaults to `true`.
        public var strict: Bool
        
        /// Whether dynamic reloading of JavaScript script resources is enabled.
        public var isDynamicReloadEnabled: Bool {
            return scriptLoader.didChange != nil
        }

        /// Whether `require` module support is enabled. Defaults to `true`.
        public var moduleRequireEnabled: Bool
        
        /// Configure a global script loader to use as the default when no loader is provided to the `Configuration`.
        ///
        /// - Seealso: ``JXContext/Configuration/scriptLoader``
        public static var defaultScriptLoader: JXScriptLoader = DefaultScriptLoader()

        /// The script loader to use for loading JavaScript script files. If the loader vends a non-nil `didChange` listener collection, dynamic reloading will be enabled.
        public var scriptLoader: JXScriptLoader
        
        public init(strict: Bool = true, moduleRequireEnabled: Bool = true, scriptLoader: JXScriptLoader = Self.defaultScriptLoader) {
            self.strict = strict
            self.moduleRequireEnabled = moduleRequireEnabled
            self.scriptLoader = scriptLoader
        }
    }
    
    /// The virtual machine associated with this context
    public let vm: JXVM

    /// Context confguration.
    public let configuration: Configuration

    /// The underlying `JSGlobalContextRef` that is wrapped by this context
    public let contextRef: JSGlobalContextRef

    private lazy var scriptManager = ScriptManager(context: self)
    private var strictEvaluated = false
    private var tryingRecursionGuard = false

    /// Class for instances that can hold references to peers (which ``JSObjectGetPrivate`` needs to work)
    @usableFromInline lazy var peerClass: JSClassRef = {
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
    public init(vm: JXVM = JXVM(), configuration: Configuration = Configuration()) {
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
    /// Evaluates the JavaScript.
    ///
    /// - Parameters:
    ///   - root: The root of the JavaScript resources, typically `Bundle.module.resourceURL` for a Swift package. This is used to locate any scripts referenced via `require`
    @discardableResult public func eval(_ script: String, this: JXValue? = nil, root: URL? = nil) throws -> JXValue {
        do {
            if let root {
                return try scriptManager.withRoot(root) {
                    return try evalPrivate(script, this: this)
                }
            } else {
                return try evalPrivate(script, this: this)
            }
        } catch {
            throw JXError(cause: error, script: script)
        }
    }

    /// Asynchronously evaluates the given script.
    ///
    /// The script is expected to return a `Promise` either directly or through the implicit promise that is created in async calls.
    ///
    /// - Parameters:
    ///   - root: The root of the JavaScript resources, typically `Bundle.module.resourceURL` for a Swift package. This is used to locate any scripts referenced via `require`
    @discardableResult public func eval(_ script: String, this: JXValue? = nil, root: URL? = nil, priority: TaskPriority) async throws -> JXValue {
        let promise = try eval(script, this: this, root: root)
        do {
            return try await evalPromise(promise, this: this, priority: priority)
        } catch {
            throw JXError(cause: error, script: script)
        }
    }
    
    private func evalPrivate(_ script: String, this: JXValue?) throws -> JXValue {
        if configuration.strict == true && !strictEvaluated {
            let useStrict = "\"use strict\";\n" // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode
            let script = useStrict.withCString(JSStringCreateWithUTF8CString)
            defer { JSStringRelease(script) }
            let _ = try trying {
                JSEvaluateScript(contextRef, script, this?.valueRef, nil, 0, $0)
            }
            strictEvaluated = true
        }
        
        // Allow SPI to perform pre-eval actions or even e.g. execute macros
        if let spiResult = try spi?.eval(script, this: this, in: self) {
            return spiResult
        }

        let script = script.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(script) }

        let result = try trying {
            JSEvaluateScript(contextRef, script, this?.valueRef, nil, 0, $0)
        }
        return result.map { JXValue(context: self, valueRef: $0) } ?? JXValue(undefinedIn: self)
    }
    
    private func evalPromise(_ promise: JXValue, this: JXValue?, priority: TaskPriority) async throws -> JXValue {
        guard try promise.isPromise else {
            throw JXError.asyncEvalMustReturnPromise(promise)
        }
        let then = try promise["then"]
        guard then.isFunction else {
            throw JXError(message: "The returned Promise does not have a 'then' function")
        }

        return try await withCheckedThrowingContinuation { [weak self] c in
            do {
                guard let self = self else {
                    return c.resume(throwing: JXError(message: "The JXContext was deallocated during the 'JXContext.eval(...) async' call"))
                }
                
                let fulfilled = JXValue(newFunctionIn: self) { jxc, this, args in
                    c.resume(returning: args.first ?? JXValue(undefinedIn: jxc))
                    return JXValue(undefinedIn: jxc)
                }
                
                let rejected = JXValue(newFunctionIn: self) { jxc, this, arg in
                    let error: JXError
                    if let jsError = arg.first {
                        error = JXError(jsError: jsError)
                    } else {
                        error = JXError(message: "The returned Promise was rejected")
                    }
                    c.resume(throwing: error)
                    return JXValue(undefinedIn: jxc)
                }
                
                let presult = try then.call(withArguments: [fulfilled, rejected], this: promise)
                
                // then() should return a promise as well
                if try !presult.isPromise {
                    // We can't throw here because it could complete the promise multiple times
                    throw JXError.asyncEvalMustReturnPromise(presult)
                }
            } catch {
                return c.resume(throwing: error)
            }
        }
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

    /// Makes the given values available as properties on the global object during the execution of the code within the given closure.
    ///
    /// - Parameters:
    ///   - values: Values to set on the global object. The values will be named $0, $1, $2, ...
    ///   - execute: The code to execute using the given values.
    /// - Returns: The result of the closure.
    @discardableResult public func withValues<R>(_ values: [JXValue], execute: () throws -> R) rethrows -> R {
        let propertyNames = (0..<values.count).map { "$\($0)"}
        let previousValues = try propertyNames.map { global.hasProperty($0) ? try global[$0] : nil }
        try values.enumerated().forEach { try global.setProperty(propertyNames[$0.offset], $0.element) }
        defer {
            previousValues.enumerated().forEach {
                let propertyName = propertyNames[$0.offset]
                do {
                    if let value = $0.element {
                        try global.setProperty(propertyName, value)
                    } else {
                        try global.deleteProperty(propertyName)
                    }
                } catch {
                }
            }
        }
        return try execute()
    }

    /// Makes the given values available as properties on the global object during the execution of the code within the given closure.
    ///
    /// - Parameters:
    ///   - values: Values to set on the global object. The values will be named $0, $1, $2, ...
    ///   - execute: The code to execute using the given values.
    /// - Returns: The result of the closure.
    @discardableResult public func withValues<R>(_ values: JXValue..., execute: () throws -> R) rethrows -> R {
        return try withValues(values, execute: execute)
    }

    /// Makes the given values available as properties on the global object during the execution of the code within the given closure.
    ///
    /// - Parameters:
    ///   - values: Values to set on the global object. The values will be named $0, $1, $2, ... The values will be `conveyed` to `JXValues`.
    ///   - execute: The code to execute using the given values.
    /// - Returns: The result of the closure.
    @discardableResult public func withValues<R>(_ values: [Any?], execute: () throws -> R) rethrows -> R {
        let jxvalues = try values.map { try convey($0) }
        return try withValues(jxvalues, execute: execute)
    }

    /// Makes the given values available as properties on the global object during the execution of the code within the given closure.
    ///
    /// - Parameters:
    ///   - values: Values to set on the global object. The values will be named $0, $1, $2, ... The values will be `conveyed` to `JXValues`.
    ///   - execute: The code to execute using the given values.
    /// - Returns: The result of the closure.
    @discardableResult public func withValues<R>(_ values: Any?..., execute: () throws -> R) rethrows -> R {
        return try withValues(values, execute: execute)
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
    @inlinable public func null() -> JXValue {
        JXValue(nullIn: self)
    }

    /// Creates a new `undefined` instance in the context.
    @inlinable public func undefined() -> JXValue {
        JXValue(undefinedIn: self)
    }

    /// Creates a new boolean with the given value in the context.
    @inlinable public func boolean(_ value: Bool) -> JXValue {
        JXValue(bool: value, in: self)
    }

    /// Creates a new number with the given value in the context.
    @inlinable public func number<F: BinaryFloatingPoint>(_ value: F) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    /// Creates a new number with the given value in the context.
    @inlinable public func number<I: BinaryInteger>(_ value: I) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    /// Creates a new string with the given value in the context.
    @inlinable public func string<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(string: String(value), in: self)
    }

    /// Creates a new Symbol with the given name in the context.
    @inlinable public func symbol<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(symbol: String(value), in: self)
    }

    /// Creates a new object in this context and assigns it the given peer object.
    @inlinable public func object(peer: AnyObject? = nil) -> JXValue {
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
    @inlinable public func object(fromDictionary properties: [String: JXValue]) throws -> JXValue {
        let object = self.object()
        try properties.forEach { entry in
            try object.setProperty(entry.key, entry.value)
        }
        return object
    }

    /// Creates an object with the given dictionary of properties.
    @inlinable public func object(fromDictionary properties: [String: Any]) throws -> JXValue {
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
    @inlinable public func `new`(_ typeName: String, withArguments arguments: [JXValue] = []) throws -> JXValue {
        // The only way to create a new class instance is with 'new X(...)', so generate that code
        let argumentsString = (0..<arguments.count).map({ "$\($0)" }).joined(separator: ",")
        let code = "new \(typeName)(\(argumentsString))"
        return try withValues(arguments) { try eval(code) }
    }

    /// Creates an instance of the named class or constructor function.
    ///
    /// - Parameters:
    ///   - typeName: Class or constructor function name.
    ///   - arguments: The arguments to pass to the constructor. The arguments will be `conveyed` to `JXValues`.
    @inlinable public func `new`(_ typeName: String, withArguments arguments: [Any]) throws -> JXValue {
        let jxarguments = try arguments.map { try convey($0) }
        return try self.new(typeName, withArguments: jxarguments)
    }

    /// Creates a new array in this context.
    @inlinable public func array(_ values: [JXValue]) throws -> JXValue {
        let array = try JXValue(newArrayIn: self)
        for (index, value) in values.enumerated() {
            try array.setElement(value, at: index)
        }
        return array
    }

    /// Creates a new array in this context.
    @inlinable public func array(_ values: [Any]) throws -> JXValue {
        let jxvalues = try values.map { try convey($0) }
        return try array(jxvalues)
    }

    @inlinable public func date(_ value: Date) throws -> JXValue {
        try JXValue(date: value, in: self)
    }

    @inlinable public func data<D: DataProtocol>(_ value: D) throws -> JXValue {
        try JXValue(newArrayBufferWithBytes: value, in: self)
    }

    /// Create a JavaScript Error with the given cause.
    ///
    /// - Seealso: ``JXValue/cause``
    @inlinable public func error<E: Error>(_ error: E) throws -> JXValue {
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
    @inlinable public func json(_ string: String) throws -> JXValue {
        if let value = JXValue(json: string, in: self) {
            return value
        }
        throw JXError(message: "Unable to create a JavaScript value from the given JSON", script: string)
    }

    /// Attempts the operation whose failure is expected to set the given error pointer.
    ///
    /// When the error pointer is set, a ``JXError`` will be thrown.
    @usableFromInline internal func trying<T>(function: (UnsafeMutablePointer<JSValueRef?>) throws -> T?) throws -> T! {
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
    /// Evaluate the JavaScript contained in the script in the given resource.
    ///
    /// - Parameters:
    ///   - resource: The JavaScript file to load, in the form `/path/file.js` or `/path/file`. Note the leading `/` because the resource path is not being interpreted relative to another resource.
    ///   - root: The root of the JavaScript resources, typically `Bundle.module.resourceURL` for a Swift package. This is used to locate the resource and any scripts it references via `require`.
    @discardableResult public func eval(resource: String, this: JXValue? = nil, root: URL) throws -> JXValue {
        return try scriptManager.withRoot(root) {
            return try scriptManager.eval(resource: resource, this: this)
        }
    }
    
    /// Asynchronously evaluate the JavaScript contained in the script in the given resource.
    ///
    /// The script is expected to return a `Promise` either directly or through the implicit promise that is created in async calls.
    ///
    /// - Parameters:
    ///   - resource: The JavaScript file to load, in the form `/path/file.js` or `/path/file`. Note the leading `/` because the resource path is not being interpreted relative to another resource.
    ///   - root: The root of the JavaScript resources, typically `Bundle.module.resourceURL` for a Swift package. This is used to locate the resource and any scripts it references via `require`.
    @discardableResult public func eval(resource: String, this: JXValue? = nil, root: URL, priority: TaskPriority) async throws -> JXValue {
        let promise = try eval(resource: resource, this: this, root: root)
        return try await evalPromise(promise, this: this, priority: priority)
    }

    /// Evaluate the given JavaScript with module semantics, returning its exports.
    ///
    /// - Parameters:
    ///   - keyPath: If given, the module exports will be integrated into the object at this key path from `global`.
    ///   - root: The root of the JavaScript resources, typically `Bundle.module.resourceURL` for a Swift package. This is used to locate any scripts referenced via `require`.
    @discardableResult public func evalModule(_ script: String, integratingExports keyPath: String? = nil, root: URL? = nil) throws -> JXValue {
        if let root {
            return try scriptManager.withRoot(root) {
                return try scriptManager.evalModule(script, integratingExports: keyPath)
            }
        } else {
            return try scriptManager.evalModule(script, integratingExports: keyPath)
        }
    }
    
    /// Evaluate the JavaScript contained in the given resource with module semantics, returning its exports.
    ///
    /// - Parameters:
    ///   - resource: The JavaScript file to load, in the form `/path/file.js` or `/path/file`. Note the leading `/` because the resource path is not being interpreted relative to another resource.
    ///   - keyPath: If given, the module exports will be integrated into the object at this key path from `global`.
    ///   - root: The root of the JavaScript resources, typically `Bundle.module.resourceURL` for a Swift package. This is used to locate the resource and any scripts it references via `require`.
    @discardableResult public func evalModule(resource: String, integratingExports keyPath: String? = nil, root: URL) throws -> JXValue {
        return try scriptManager.withRoot(root) {
            return try scriptManager.evalModule(resource: resource, integratingExports: keyPath)
        }
    }
    
    /// Listen for changes to JavaScript script resource IDs, if change monitoring is supported by the `JXScriptLoader`.
    public func onScriptsDidChange(perform: @escaping (Set<String>) -> Void) -> JXCancellable? {
        return scriptManager.didChange.add(perform)
    }
    
    /// Perform the given code while tracking its access to JavaScript script resource IDs.
    public func trackingScriptAccess<V>(perform: @escaping () throws -> V) throws -> (accessed: Set<String>, value: V) {
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
