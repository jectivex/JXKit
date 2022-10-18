import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A JavaScript execution context. This is a cross-platform analogue to the Objective-C `JavaScriptCore.JSContext`.
///
/// This wraps a `JSGlobalContextRef`, and is the equivalent of `JavaScriptCore.JSContext`
open class JXContext {
    /// The virtual machine associated with this context
    public let vm: JXVM

    /// Whether scripts evaluated by this context should be assessed in `strict` mode.
    public let strict: Bool

    /// The underlying `JSGlobalContextRef` that is wrapped by this context
    public let contextRef: JSGlobalContextRef

    private var strictEvaluated: Bool = false

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
    ///   - strict: Whether to evaluate in strict mode.
    public init(vm: JXVM = JXVM(), strict: Bool = true) {
        self.vm = vm
        self.contextRef = JSGlobalContextCreateInGroup(vm.groupRef, nil)
        self.strict = strict
    }

    /// Wraps an existing `JSGlobalContextRef` in a `JXContext`. Address space will be shared between both contexts.
    ///
    /// - Parameters:
    ///   - context: The shared JXContext to use.
    ///   - strict: Whether to evaluate in strict mode.
    public init(context: JXContext, strict: Bool = true) {
        self.vm = JXVM(groupRef: JSContextGetGroup(context.contextRef))
        self.contextRef = context.contextRef
        self.strict = strict
        self.spi = context.spi
        JSGlobalContextRetain(context.contextRef)
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

    /// Evaulates the JavaScript.
    @discardableResult public func eval(_ script: String, this: JXValue? = nil) throws -> JXValue {
        if strict == true && strictEvaluated == false {
            let useStrict = "\"use strict\";\n" // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Strict_mode
            let script = useStrict.withCString(JSStringCreateWithUTF8CString)
            defer { JSStringRelease(script) }
            let _ = try trying {
                JSEvaluateScript(contextRef, script, this?.valueRef, nil, 0, $0)
            }
            strictEvaluated = true
        }

        let script = script.withCString(JSStringCreateWithUTF8CString)

        defer { JSStringRelease(script) }

        let result = try trying {
            JSEvaluateScript(contextRef, script, this?.valueRef, nil, 0, $0)
        }

        return result.map { JXValue(context: self, valueRef: $0) } ?? JXValue(undefinedIn: self)
    }

    /// Asynchronously evaulates the given script.
    ///
    /// The script is expected to return a `Promise` either directly or through the implicit promise
    /// that is created in async calls.
    @discardableResult public func eval(_ script: String, method: Bool = true, this: JXValue? = nil, priority: TaskPriority) async throws -> JXValue {
        let promise = try eval(script, this: this)
        guard try promise.isPromise else {
            throw JXErrors.asyncEvalMustReturnPromise
        }

        let then = try promise["then"]
        guard then.isFunction else {
            throw JXErrors.invalidAsyncPromise
        }

        return try await withCheckedThrowingContinuation { [weak self] c in
            do {
                guard let self = self else {
                    return c.resume(throwing: JXErrors.cannotCreatePromise)
                }

                let fulfilled = JXValue(newFunctionIn: self) { jxc, this, args in
                    c.resume(returning: args.first ?? JXValue(undefinedIn: jxc))
                    return JXValue(undefinedIn: jxc)
                }

                let rejected = JXValue(newFunctionIn: self) { jxc, this, arg in
                    c.resume(throwing: arg.first.map({ JXEvalError(context: jxc, valueRef: $0.valueRef) }) ?? JXErrors.cannotCreatePromise)
                    return JXValue(undefinedIn: jxc)
                }

                let presult = try then.call(withArguments: [fulfilled, rejected], this: promise)

                // then() should return a promise as well
                if try !presult.isPromise {
                    // We can't throw here because it could complete the promise multiple times
                    throw JXErrors.asyncEvalMustReturnPromise
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
    ///   - sourceURL: A URL for the script's source file. This is only used when reporting exceptions. Pass `nil` to omit source file information in exceptions.
    ///   - startingLineNumber: An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions.
    /// - Returns: true if the script is syntactically correct; otherwise false.
    @inlinable public func checkSyntax(_ script: String, sourceURL URLString: String? = nil, startingLineNumber: Int = 0) throws -> Bool {
        let script = script.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(script) }

        let sourceURL = URLString?.withCString(JSStringCreateWithUTF8CString)
        defer { sourceURL.map(JSStringRelease) }

        return try trying {
            JSCheckScriptSyntax(contextRef, script, sourceURL, Int32(startingLineNumber), $0)
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

    /// Creates a new array in this context.
    @inlinable public func array(_ values: [JXValue]) throws -> JXValue {
        let array = try JXValue(newArrayIn: self)
        for (index, value) in values.enumerated() {
            try array.setElement(value, at: index)
        }
        return array
    }

    @inlinable public func date(_ value: Date) throws -> JXValue {
        try JXValue(date: value, in: self)
    }

    @inlinable public func data<D: DataProtocol>(_ value: D) throws -> JXValue {
        try JXValue(newArrayBufferWithBytes: value, in: self)
    }

    @inlinable public func error<E: Error>(_ error: E) throws -> JXValue {
        try JXValue(newErrorFromMessage: "\(error)", in: self)
    }

    /// Attempts to convey the given value into this JavaScript context.
    ///
    /// - Throws: `JXErrors.cannotConvey` if the type cannot be conveyed to JavaScript.
    /// - Seealso: `JXValue.convey` to convey back from JavaScript.
    public func convey(_ value: Any?) throws -> JXValue {
        guard let value else {
            return null()
        }
        guard let spi = self.spi else {
            return try conveyIfConvertible(value) ?? conveyEncodable(value)
        }

        // Break down the value so that we can pass individual array and dict elements through our service provider
        if let jxValue = value as? JXValue {
            return jxValue
        } else if let array = value as? [Any] {
            let jxArray = try array.map { try convey($0) }
            return try self.array(jxArray)
        } else if let dictionary = value as? [String: Any] {
            let jxDictionary = try dictionary.reduce(into: [:]) { result, entry in
                result[entry.key] = try convey(entry.value)
            }
            return try object(fromDictionary: jxDictionary)
        } else if let jxValue = try conveyIfConvertible(value) {
            return jxValue
        } else if let jxValue = try spi.toJX(value, in: self) {
            return jxValue
        } else {
            return try conveyEncodable(value)
        }
    }

    private func conveyIfConvertible(_ value: Any) throws -> JXValue? {
        guard let convertible = value as? JXConvertible else {
            return nil
        }
        return try convertible.toJX(in: self)
    }

    private func conveyEncodable(_ value: Any) throws -> JXValue {
        guard let encodable = value as? Encodable else {
            throw JXErrors.cannotConvey(type(of: value))
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
        throw JXErrors.cannotCreateFromJSON
    }

    /// Attempts the operation whose failure is expected to set the given error pointer.
    ///
    /// When the error pointer is set, a ``JXEvalError`` will be thrown.
    @inlinable internal func trying<T>(function: (UnsafeMutablePointer<JSValueRef?>) throws -> T?) throws -> T! {
        var errorPointer: JSValueRef?
        let result = try function(&errorPointer)
        if let errorPointer = errorPointer {
            throw JXEvalError(context: self, valueRef: errorPointer)
        } else {
            return result
        }
    }
}

/// Optional service provider integration points.
public protocol JXContextSPI {
    func toJX(_ value: Any, in context: JXContext) throws -> JXValue?
    func fromJX<T>(_ value: JXValue, to type: T.Type) throws -> T?
}

extension JXContextSPI {
    public func toJX(_ value: Any, in context: JXContext) throws -> JXValue? {
        return nil
    }

    public func fromJX<T>(_ value: JXValue, to type: T.Type) throws -> T? {
        return nil
    }
}
