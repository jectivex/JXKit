//
//  JavaScript execution context
//
import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: JXContext

/// A JavaScript execution context. This is a cross-platform analogue to the Objective-C `JavaScriptCore.JSContext`.
///
/// The `JXContext` used the system's `JavaScriptCore` C interface on Apple platforms, and `webkitgtk-4.0` on Linux platforms. Windows is TBD.
///
/// This wraps a `JSGlobalContextRef`, and is the equivalent of `JavaScriptCore.JSContext`
@available(macOS 11, iOS 13, tvOS 13, *)
public final class JXContext : JXEnv {
    public let group: JXContextGroup
    public let context: JSGlobalContextRef
    public var currentError: JXValue?
    public var exceptionHandler: ((JXContext?, JXValue?) -> Void)?

    /// Creates `JXContext` with the given `JXContextGroup`.  `JXValue` references may be used interchangably with multiple instances of `JXContext` with the same `JXContextGroup`, but sharing between  separate `JXContextGroup`s will result in undefined behavior.
    public init(group: JXContextGroup) {
        self.group = group
        self.context = JSGlobalContextCreateInGroup(group.group, nil)
    }

    /// Wraps an existing `JSGlobalContextRef` in a `JXContext`. Address space will be shared between both contexts.
    public init(context: JSGlobalContextRef) {
        self.group = JXContextGroup(group: JSContextGetGroup(context))
        self.context = context
        JSGlobalContextRetain(context)
    }

    /// Creates a new `JXContext` with a new `JXContextGroup` virtual machine.
    public convenience init() {
        self.init(group: JXContextGroup())
    }

    deinit {
        JSGlobalContextRelease(context)
    }

    @discardableResult public func eval(_ script: String, this: JXValue? = nil) throws -> JXValue {
        try trying {
            evaluateScript(script, this: this, withSourceURL: nil, startingLineNumber: 0)
        }
    }

    /// Asynchronously evaulates the given script
    @discardableResult public func eval(_ script: String, method: Bool = true, this: JXValue? = nil, priority: TaskPriority) async throws -> JXValue {

        try await withCheckedThrowingContinuation { [weak self] c in
            do {
                guard let self = self else {
                    return c.resume(throwing: Errors.cannotCreatePromise)
                }
                let promise = try eval(script, this: this)

                guard !promise.isFunction && !promise.isConstructor else { // should return a Promise, not a function
                    throw Errors.asyncEvalMustReturnPromise
                }

                guard promise.isObject && promise.stringValue == "[object Promise]" else {
                    throw Errors.asyncEvalMustReturnPromise
                }

                let then = promise["then"]
                guard then.isFunction else {
                    throw Errors.invalidAsyncPromise
                }

                let fulfilled = JXValue(newFunctionIn: self) { ctx, this, args in
                    c.resume(returning: args.first ?? JXValue(undefinedIn: ctx))
                    return JXValue(undefinedIn: ctx)
                }

                let rejected = JXValue(newFunctionIn: self) { ctx, this, arg in
                    c.resume(throwing: arg.first ?? Errors.cannotCreatePromise)
                    return JXValue(undefinedIn: ctx)
                }

                let presult = then.call(withArguments: [fulfilled, rejected], this: promise)

                // then() should return a promise as well
                if !presult.isObject || presult.stringValue != "[object Promise]" {
                    // we can't throw here because it could complete the promise multiple times
                    //throw Errors.asyncEvalMustReturnPromise
                    fatalError("Promise.then did not return a promise")
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
    ///
    /// - Returns: true if the script is syntactically correct; otherwise false.
    @inlinable public func checkScriptSyntax(_ script: String, sourceURL: URL? = nil, startingLineNumber: Int = 0) -> Bool {

        let script = script.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(script) }

        let sourceURL = sourceURL?.absoluteString.withCString(JSStringCreateWithUTF8CString)
        defer { sourceURL.map(JSStringRelease) }

        return JSCheckScriptSyntax(context, script, sourceURL, Int32(startingLineNumber), &_currentError)
    }

    /// Evaluates a string of JavaScript.
    ///
    /// - Parameters:
    ///   - script: The script to check for syntax errors.
    ///   - this: The object to use as this or `nil` to use the global object as this.
    ///   - sourceURL: A URL for the script's source file. This is only used when reporting exceptions. Pass `nil` to omit source file information in exceptions.
    ///   - startingLineNumber: An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions.
    ///
    /// - Returns: true if the script is syntactically correct; otherwise false.
    @discardableResult @inlinable public func evaluateScript(_ script: String, this: JXValue? = nil, withSourceURL sourceURL: URL? = nil, startingLineNumber: Int = 0) -> JXValue {

        let script = script.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(script) }

        let sourceURL = sourceURL?.absoluteString.withCString(JSStringCreateWithUTF8CString)
        defer { sourceURL.map(JSStringRelease) }

        let result = JSEvaluateScript(context, script, this?.value, sourceURL, Int32(startingLineNumber), &_currentError)

        return result.map { JXValue(env: self, value: $0) } ?? JXValue(undefinedIn: self)
    }

    @usableFromInline var _currentError: JSObjectRef? {
        get {
            currentError = nil
            return nil
        }

        set {
            guard let newValue = newValue else { return }
            if let callback = exceptionHandler {
                callback(self, JXValue(env: self, value: newValue))
            } else {
                currentError = JXValue(env: self, value: newValue)
            }
        }
    }

    /// Performs a JavaScript garbage collection.
    ///
    /// During JavaScript execution, you are not required to call this function; the JavaScript engine will garbage collect as needed.
    /// JavaScript values created within a context group are automatically destroyed when the last reference to the context group is released.
    public func garbageCollect() { JSGarbageCollect(context) }

    /// Returns the global context reference for this context
    public var jsGlobalContextRef: JSGlobalContextRef { context }

    /// The global object.
    public var global: JXValue {
        JXValue(env: self, value: JSContextGetGlobalObject(context))
    }

    /// Tests whether global has a given property.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the object has `property`, otherwise false.
    @inlinable public func hasProperty(_ property: String) -> Bool {
        global.hasProperty(property)
    }

    /// Deletes a property from global.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    @inlinable public func removeProperty(_ property: String) -> Bool {
        global.removeProperty(property)
    }

    /// Returns the global property at the given subscript
    @inlinable public subscript(property: String) -> JXValue {
        get { global[property] }
        set { global[property] = newValue }
    }

    /// Get the names of global’s enumerable properties
    @inlinable public var properties: [String] {
        global.properties
    }

    /// Checks for the presence of a top-level "exports" variable and creates it if it isn't already an object.
    @inlinable public func globalObject(property named: String) -> JXValue {
        let exp = self.global[named]
        if exp.isObject {
            return exp
        } else {
            let exp = self.object()
            self.global[named] = exp
            return exp
        }
    }

    enum Errors : Error {
        /// A required resource was missing
        case missingResource(String)
        /// An evaluation error occurred
        case evaluationErrorString(String)
        /// An evaluation error occurred
        case evaluationError(JXValue)
        /// An evaluation error occurred
        case evaluationErrorUnknown
        /// The API call requires a higher system version (e.g., for JS typed array support)
        case minimumSystemVersion
        /// Unable to create a new promise
        case cannotCreatePromise
        case cannotLoadScriptURL(URL, URLResponse)
        case asyncEvalMustReturnPromise
        case invalidAsyncPromise

    }

    #if !os(Linux) // URLSession.shared.data not available yet
    /// Runs the script at the given URL.
    /// - Parameter url: the URL from which to run the script
    /// - Parameter this: the `this` for the script
    /// - Throws: an error if the contents of the URL cannot be loaded, or if a JavaScript exception occurs
    /// - Returns: the value as returned by the script (which may be `isUndefined` for void)
    @available(macOS 12, iOS 15, tvOS 15, *)
    @discardableResult public func evaluate(remote url: URL, session: URLSession = .shared, this: JXValue? = nil) async throws -> JXValue {
        let (data, response) = try await session.data(for: URLRequest(url: url))
        if !(200..<300).contains((response as? HTTPURLResponse)?.statusCode ?? 0) {
            throw JXContext.Errors.cannotLoadScriptURL(url, response)
        }
        let script = String(data: data, encoding: .utf8) ?? ""
        let result = try eval(script, this: this)
        return result
    }
    #endif


    /// Invokes the given closure with the bytes without copying
    /// - Parameters:
    ///   - source: the data to use
    ///   - block: the block that passes the temporary JXValue wrapping the buffer data
    /// - Returns: the result of the closure
    public func withArrayBuffer<T>(source: Data, block: (JXValue) throws -> (T)) rethrows -> T {
        var source = source
        return try source.withUnsafeMutableBytes { bytes in
            let buffer = JXValue(newArrayBufferWithBytesNoCopy: bytes,
                deallocator: { _ in
                    //print("buffer deallocated")
                },
                in: self)
            return try block(buffer)
        }
    }

    /// Tries to execute the given operation, and throws any exceptions that may exists
    @inlinable public func trying<T>(operation: () throws -> T) throws -> T {
        let result = try operation()
        try throwException()
        return result
    }

    /// If an exception occurred, throw it and clear the current exception
    public func throwException() throws {
        if let error = self.currentError {
            defer { self.currentError = nil }
            // TODO: extract standard error properties into a structured Error instance
            if let string = error.stringValue {
                throw JXContext.Errors.evaluationErrorString(string)
            } else { // if let error = error as? Error & JXValue {
                throw JXContext.Errors.evaluationError(error)
//            } else {
//                throw JXContext.Errors.evaluationErrorUnknown
            }
        }
    }

    /// Returns the global "Object"
    public var objectPrototype: JXValue { global["Object"] }

    /// Returns the global "Date"
    public var datePrototype: JXValue { global["Date"] }

    /// Returns the global "Array"
    public var arrayPrototype: JXValue { global["Array"] }

    /// Returns the global "ArrayBuffer"
    public var arrayBufferPrototype: JXValue { global["ArrayBuffer"] }

    /// Returns the global "Error"
    public var errorPrototype: JXValue { global["Error"] }

    /// Whether the `JavaScriptCore` implementation on the current platform phohibits writable and executable memory (`mmap(MAP_JIT)`), thereby disabling the fast-path of the JavaScriptCore framework.
    ///
    /// Without the Allow Execution of JIT-compiled Code Entitlement, frameworks that rely on just-in-time (JIT) compilation will fall back to an interpreter.
    ///
    /// To add the entitlement to your app, first enable the Hardened Runtime capability in Xcode, and then under Runtime Exceptions, select Allow Execution of JIT-compiled Code.
    ///
    /// See: [Allow Execution of JIT-compiled Code Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_cs_allow-jit)
    public static let isHobbled: Bool = {
        // we could check for the hardened runtime's "com.apple.security.cs.allow-jit" property, but it is easier to just attempt to mmap PROT_WRITE|PROT_EXEC and see if it was successful

        let ptr = mmap(nil, Int(getpagesize()), PROT_WRITE|PROT_EXEC, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        if ptr == MAP_FAILED {
            return true // JIT forbidden
        } else {
            munmap(ptr, Int(getpagesize()))
            return false
        }
    }()

    @inlinable public func null() -> JXValue {
        JXValue(nullIn: self)
    }

    @inlinable public func undefined() -> JXValue {
        JXValue(undefinedIn: self)
    }

    @inlinable public func boolean(_ value: Bool) -> JXValue {
        JXValue(bool: value, in: self)
    }

    @inlinable public func number<F: BinaryFloatingPoint>(_ value: F) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    @inlinable public func number<I: BinaryInteger>(_ value: I) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    @inlinable public func string<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(string: String(value), in: self)
    }

    @inlinable public func object() -> JXValue {
        JXValue(newObjectIn: self)
    }

    /// Creates a new array in the environment
    @inlinable public func array(_ values: [JXValue]) -> JXValue {
        let array = JXValue(newArrayIn: self)
        for (index, value) in values.enumerated() {
            array[UInt32(index)] = value
        }
        return array
    }


    @inlinable public func date(_ value: Date) -> JXValue {
        JXValue(date: value, in: self)
    }

    @inlinable public func data<D: DataProtocol>(_ value: D) -> JXValue {
        JXValue(newArrayBufferWithBytes: value, in: self)
    }
}
