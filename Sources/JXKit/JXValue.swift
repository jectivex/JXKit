//
//  JavaScript values
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

// MARK: JXValue

/// A JavaScript object.
///
/// This wraps a `JSObjectRef`, and is the equivalent of `JavaScriptCore.JSValue`
@available(macOS 11, iOS 12, tvOS 12, *)
public final class JXValue {
    public let env: JXContext
    public let value: JXValueRef

    public init(env: JXContext, value: JXValueRef) {
        JSValueProtect(env.context, value)
        self.env = env
        self.value = value
    }

    deinit {
        JSValueUnprotect(env.context, value)
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {
    @usableFromInline static let rfc3339: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()

}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Creates a JavaScript value of the `undefined` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(undefinedIn env: JXContext) {
        self.init(env: env, value: JSValueMakeUndefined(env.context))
    }

    /// Creates a JavaScript value of the `null` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(nullIn env: JXContext) {
        self.init(env: env, value: JSValueMakeNull(env.context))
    }

    /// Creates a JavaScript `Boolean` value.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(bool value: Bool, in env: JXContext) {
        self.init(env: env, value: JSValueMakeBoolean(env.context, value))
    }

    /// Creates a JavaScript value of the `Number` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(double value: Double, in env: JXContext) {
        self.init(env: env, value: JSValueMakeNumber(env.context, value))
    }

    /// Creates a JavaScript value of the `String` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(string value: String, in env: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(env: env, value: JSValueMakeString(env.context, value))
    }

    /// Creates a JavaScript value of the parsed `JSON`.
    ///
    /// - Parameters:
    ///   - value: The JSON value to parse
    ///   - context: The execution context to use.
    @inlinable public convenience init?(json value: String, in env: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        guard let json = JSValueMakeFromJSONString(env.context, value) else {
            return nil // TODO: throw error
        }
        self.init(env: env, value: json)
    }

    /// Creates a JavaScript `Date` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(date value: Date, in env: JXContext) {
        let arguments = [JXValue(string: JXValue.rfc3339.string(from: value), in: env)]
        let object = JSObjectMakeDate(env.context, 1, arguments.map { $0.value }, &env._currentError)
        self.init(env: env, value: object!)
    }

    /// Creates a JavaScript `RegExp` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - pattern: The pattern of regular expression.
    ///   - flags: The flags pass to the constructor.
    ///   - context: The execution context to use.
    @inlinable public convenience init(newRegularExpressionFromPattern pattern: String, flags: String, in env: JXContext) {
        let arguments = [JXValue(string: pattern, in: env), JXValue(string: flags, in: env)]
        let object = JSObjectMakeRegExp(env.context, 2, arguments.map { $0.value }, &env._currentError)
        self.init(env: env, value: object!)
    }

    /// Creates a JavaScript `Error` object, as if by invoking the built-in `Error` constructor.
    ///
    /// - Parameters:
    ///   - message: The error message.
    ///   - context: The execution context to use.
    @inlinable public convenience init(newErrorFromMessage message: String, in env: JXContext) {
        let arguments = [JXValue(string: message, in: env)]
        self.init(env: env, value: JSObjectMakeError(env.context, 1, arguments.map { $0.value }, &env._currentError))
    }

    /// Creates a JavaScript `Object`.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newObjectIn env: JXContext) {
        self.init(env: env, value: JSObjectMake(env.context, nil, nil))
    }

    /// Creates a JavaScript `Object` with prototype.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - prototype: The prototype to be used.
    @inlinable public convenience init(newObjectIn env: JXContext, prototype: JXValue) {
        let obj = env.objectPrototype.invokeMethod("create", withArguments: [prototype])
        self.init(env: env, value: obj.value)
    }

    /// Creates a JavaScript `Array` object.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newArrayIn env: JXContext, values: [JXValue]? = nil) {
        self.init(env: env, value: JSObjectMakeArray(env.context, 0, nil, &env._currentError))
        if let values = values {
            for (index, element) in values.enumerated() {
                self[UInt32(index)] = element
            }
        }
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue: CustomStringConvertible {

    @inlinable public var description: String {
        if self.isUndefined { return "undefined" }
        if self.isNull { return "null" }
        if self.isBoolean { return "\(self.booleanValue)" }
        if self.isNumber { return "\(self.numberValue!)" }
        if self.isString { return "\"\(self.stringValue!.unicodeScalars.reduce(into: "") { $0 += $1.escaped(asASCII: false) })\"" }
        return self.invokeMethod("toString", withArguments: []).stringValue!
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue: Error {

}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Object’s prototype.
    @inlinable public var prototype: JXValue {
        get {
            let prototype = JSObjectGetPrototype(env.context, value)
            return prototype.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
        }
        set {
            JSObjectSetPrototype(env.context, value, newValue.value)
        }
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Tests whether a JavaScript value’s type is the undefined type.
    @inlinable public var isUndefined: Bool {
        JSValueIsUndefined(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the null type.
    @inlinable public var isNull: Bool {
        JSValueIsNull(env.context, value)
    }

    /// Tests whether a JavaScript value is Boolean.
    @inlinable public var isBoolean: Bool {
        JSValueIsBoolean(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the number type.
    @inlinable public var isNumber: Bool {
        JSValueIsNumber(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the string type.
    @inlinable public var isString: Bool {
        JSValueIsString(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the object type.
    @inlinable public var isObject: Bool {
        JSValueIsObject(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the date type.
    @inlinable public var isDate: Bool {
        self.isInstance(of: env.datePrototype)
    }

    /// Tests whether a JavaScript value’s type is the array type.
    @inlinable public var isArray: Bool {
        let result = env.arrayPrototype.invokeMethod("isArray", withArguments: [self])
        return JSValueToBoolean(env.context, result.value)
    }

    /// Tests whether an object can be called as a constructor.
    @inlinable public var isConstructor: Bool {
        isObject && JSObjectIsConstructor(env.context, value)
    }

    /// Tests whether an object can be called as a function.
    @inlinable public var isFunction: Bool {
        isObject && JSObjectIsFunction(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the error type.
    @inlinable public var isError: Bool {
        self.isInstance(of: env.errorPrototype)
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    @inlinable public var isFrozen: Bool {
        env.objectPrototype.invokeMethod("isFrozen", withArguments: [self]).booleanValue
    }

    @inlinable public var isExtensible: Bool {
        env.objectPrototype.invokeMethod("isExtensible", withArguments: [self]).booleanValue
    }

    @inlinable public var isSealed: Bool {
        env.objectPrototype.invokeMethod("isSealed", withArguments: [self]).booleanValue
    }

    @inlinable public func freeze() {
        env.objectPrototype.invokeMethod("freeze", withArguments: [self])
    }

    @inlinable public func preventExtensions() {
        env.objectPrototype.invokeMethod("preventExtensions", withArguments: [self])
    }

    @inlinable public func seal() {
        env.objectPrototype.invokeMethod("seal", withArguments: [self])
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Returns the JavaScript boolean value.
    @inlinable public var booleanValue: Bool {
        JSValueToBoolean(env.context, value)
    }

    /// Returns the JavaScript number value.
    @inlinable public var numberValue: Double? {
        var exception: JSObjectRef?
        //if !JSValueIsNumber(env.context, value) { return nil }
        let result = JSValueToNumber(env.context, value, &exception)
        return exception == nil ? result : nil
    }

    /// Returns the JavaScript string value.
    @inlinable public var stringValue: String? {
        let str = JSValueToStringCopy(env.context, value, nil)
        defer { str.map(JSStringRelease) }
        return str.map(String.init)
    }

    @inlinable public var dateValue: Date? {
        //dateValueMS
        dateValueISO
    }

    //    /// Returns the JavaScript date value.
    //    @inlinable public var dateValueMS: Date? {
    //        if !isDate {
    //            return nil
    //        }
    //        let result = self.invokeMethod("getTime", withArguments: [])
    //        return result.numberValue.flatMap { Date(timeIntervalSince1970: $0) }
    //    }

    /// Returns the JavaScript date value.
    @inlinable public var dateValueISO: Date? {
        if !isDate {
            return nil
        }
        let result = self.invokeMethod("toISOString", withArguments: [])
        return result.stringValue.flatMap { JXValue.rfc3339.date(from: $0) }
    }

    /// Returns the JavaScript array.
    @inlinable public var array: [JXValue]? {
        guard self.isArray else { return nil }
        return (0..<UInt32(self.count)).map { self[$0] }
    }

    /// Returns the JavaScript object as dictionary.
    @inlinable public var dictionary: [String: JXValue]? {
        !isObject ? nil : self.properties.reduce(into: [:]) { $0[$1] = self[$1] }
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Calls an object as a function.
    ///
    /// - Parameters:
    ///   - arguments: The arguments pass to the function.
    ///   - this: The object to use as `this`, or `nil` to use the global object as `this`.
    ///
    /// - Returns: The object that results from calling object as a function
    @discardableResult @inlinable public func call(withArguments arguments: [JXValue] = [], this: JXValue? = nil) -> JXValue {
        if !isFunction {
            // we should have already validated that it is a function
            fatalError("target was not a function")
        }
        let result = JSObjectCallAsFunction(env.context, value, this?.value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, &env._currentError)
        return result.map {
            let v = JXValue(env: env, value: $0)
            //print("CALLING:", $0, "this:", this?.value, "err:", env._currentError, v.isUndefined)
            //assert(!v.isUndefined)
            return v
        } ?? JXValue(undefinedIn: env)
    }

    /// Calls an object as a constructor.
    ///a
    /// - Parameters:
    ///   - arguments: The arguments pass to the function.
    ///
    /// - Returns: The object that results from calling object as a constructor.
    @inlinable public func construct(withArguments arguments: [JXValue]) -> JXValue {
        let result = JSObjectCallAsConstructor(env.context, value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, &env._currentError)
        return result.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
    }

    /// Invoke an object's method.
    ///
    /// - Parameters:
    ///   - name: The name of method.
    ///   - arguments: The arguments pass to the function.
    ///
    /// - Returns: The object that results from calling the method.
    @discardableResult
    @inlinable public func invokeMethod(_ name: String, withArguments arguments: [JXValue]) -> JXValue {
        self[name].call(withArguments: arguments, this: self)
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Tests whether two JavaScript values are strict equal, as compared by the JS `===` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    ///
    /// - Returns: true if the two values are strict equal; otherwise false.
    @inlinable public func isEqual(to other: JXValue) -> Bool {
        JSValueIsStrictEqual(env.context, value, other.value)
    }

    /// Tests whether two JavaScript values are equal, as compared by the JS `==` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    ///
    /// - Returns: true if the two values are equal; false if they are not equal or an exception is thrown.
    @inlinable public func isEqualWithTypeCoercion(to other: JXValue) -> Bool {
        JSValueIsEqual(env.context, value, other.value, &env._currentError)
    }

    /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the `isInstance(of:)` operator.
    ///
    /// - Parameters:
    ///   - other: The constructor to test against.
    ///
    /// - Returns: true if the value is an object constructed by constructor, as compared by the JS isInstance(of:) operator; otherwise false.
    @inlinable public func isInstance(of other: JXValue) -> Bool {
        JSValueIsInstanceOfConstructor(env.context, value, other.value, &env._currentError)
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Get the names of an object’s enumerable properties.
    @inlinable public var properties: [String] {
        if !isObject { return [] }

        let _list = JSObjectCopyPropertyNames(env.context, value)
        defer { JSPropertyNameArrayRelease(_list) }

        let count = JSPropertyNameArrayGetCount(_list)
        let list = (0..<count).map { JSPropertyNameArrayGetNameAtIndex(_list, $0)! }

        return list.map(String.init)
    }

    /// Tests whether an object has a given property.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the object has `property`, otherwise false.
    @inlinable public func hasProperty(_ property: String) -> Bool {
        let property = property.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(property) }
        return JSObjectHasProperty(env.context, value, property)
    }

    /// Deletes a property from an object.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    @inlinable public func removeProperty(_ property: String) -> Bool {
        let property = property.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(property) }
        return JSObjectDeleteProperty(env.context, value, property, &env._currentError)
    }

    /// Checks if a property exists
    ///
    /// - Parameters:
    ///   - property: The property's key (usually a string or number).
    ///
    /// - Returns: true if a property with the given key exists
    @discardableResult
    @inlinable public func hasProperty(_ property: JXValue) -> Bool {
        if !isObject { return false }
        return JSObjectHasPropertyForKey(env.context, value, property.value, &env._currentError)
    }

    /// Deletes a property from an object or array.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    @inlinable public func deleteProperty(_ property: JXValue) -> Bool {
        JSObjectDeletePropertyForKey(env.context, value, property.value, &env._currentError)
    }

    /// The value of the property.
    @inlinable public subscript(propertyName: String) -> JXValue {
        get {
            if !isObject { return env.undefined() }
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            let result = JSObjectGetProperty(env.context, value, property, &env._currentError)
            return result.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
        }

        set {
            if !isObject { return }
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            JSObjectSetProperty(env.context, value, property, newValue.value, 0, &env._currentError)
        }
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {
    /// The length of the object.
    @inlinable public var count: Int {
        let dbl = self["length"].numberValue ?? 0
        return dbl.isNaN || dbl.isSignalingNaN || dbl.isInfinite == true ? 0 : Int(dbl)
    }

    /// The value in object at index.
    @inlinable public subscript(index: UInt32) -> JXValue {
        get {
            let result = JSObjectGetPropertyAtIndex(env.context, value, index, &env._currentError)
            return result.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
        }

        set {
            JSObjectSetPropertyAtIndex(env.context, value, UInt32(index), newValue.value, &env._currentError)
        }
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {
    /// Returns the JavaScript string with the given indentation. This should be the same as the output of `JSON.stringify`.
    @inlinable public func toJSON(indent: UInt32 = 0) throws -> String {
        var ex: JSValueRef?
        let str = JSValueCreateJSONString(env.context, value, indent, &ex)
        if let ex = ex { throw JXValue(env: env, value: ex) }
        defer { str.map(JSStringRelease) }
        return str.map(String.init) ?? "null"
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - length: Length of new `ArrayBuffer` object.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithLength length: Int, in env: JXContext) {
        let obj = env.arrayBufferPrototype.construct(withArguments: [JXValue(double: Double(length), in: env)])
        self.init(env: env, value: obj.value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to be used as the backing store of the `ArrayBuffer` object.
    ///   - deallocator: The allocator to use to deallocate the external buffer when the `ArrayBuffer` object is deallocated.
    ///   - context: The execution context to use.
    public convenience init(
        newArrayBufferWithBytesNoCopy bytes: UnsafeMutableRawBufferPointer,
        deallocator: @escaping (UnsafeMutableRawBufferPointer) -> Void,
        in env: JXContext
    ) {

        typealias Deallocator = () -> Void

        let info: UnsafeMutablePointer<Deallocator> = .allocate(capacity: 1)
        info.initialize(to: { deallocator(bytes) })

        self.init(env: env,
                  value: JSObjectMakeArrayBufferWithBytesNoCopy(env.context, bytes.baseAddress, bytes.count, { _, info in
            guard let info = info?.assumingMemoryBound(to: Deallocator.self) else { return }
            info.pointee()
            info.deinitialize(count: 1).deallocate()
        },
                                                                info,
                                                                &env._currentError
                                                               )
        )
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to copy.
    ///   - context: The execution context to use.
    public convenience init<S: DataProtocol>(newArrayBufferWithBytes bytes: S, in env: JXContext) {

        let buffer: UnsafeMutableRawPointer = .allocate(byteCount: bytes.count, alignment: MemoryLayout<UInt8>.alignment)
        bytes.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count))

        self.init(env: env, value: JSObjectMakeArrayBufferWithBytesNoCopy(env.context, buffer, bytes.count, { buffer, _ in buffer?.deallocate() }, nil, &env._currentError))
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {
    /// Tests whether a JavaScript value’s type is the `ArrayBuffer` type.
    public var isArrayBuffer: Bool {
        self.isInstance(of: env.arrayBufferPrototype)
    }

    /// The length (in bytes) of the `ArrayBuffer`.
    public var byteLength: Int {
        Int(self["byteLength"].numberValue ?? 0)
    }

    /// Copy the bytes of `ArrayBuffer`.
    public func copyBytes() -> Data? {
        guard self.isArrayBuffer else { return nil }
        let length = JSObjectGetArrayBufferByteLength(env.context, value, &env._currentError)
        return Data(bytes: JSObjectGetArrayBufferBytesPtr(env.context, value, &env._currentError), count: length)
    }
}

public extension String {
    /// Creates a `Swift.String` from a `JXStringRef`
    @inlinable init(_ str: JXStringRef) {
        self.init(utf16CodeUnits: JSStringGetCharactersPtr(str), count: JSStringGetLength(str))
    }
}


// MARK: Functions


/// A function definition, used when defining callbacks.
@available(macOS 11, iOS 12, tvOS 12, *)
public typealias JXFunction = (JXContext, JXValue?, [JXValue]) throws -> JXValue


@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {
    /// Creates a JavaScript value of the function type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - callback: The callback function.
    ///
    /// - Note: This object is callable as a function (due to `JSClassDefinition.callAsFunction`), but the JavaScript runtime doesn't treat is exactly like a function. For example, you cannot call "apply" on it. It could be better to use `JSObjectMakeFunctionWithCallback`, which may act more like a "true" JavaScript function.
    public convenience init(newFunctionIn env: JXContext, callback: @escaping JXFunction) {
        let info: UnsafeMutablePointer<JXFunctionInfo> = .allocate(capacity: 1)
        info.initialize(to: JXFunctionInfo(context: env, callback: callback))

        var def = JSClassDefinition()
        def.finalize = JXFunctionFinalize
        def.callAsConstructor = JXFunctionConstructor
        def.callAsFunction = JXFunctionCallback
        def.hasInstance = JXFunctionInstanceOf

        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }

        self.init(env: env, value: JSObjectMake(env.context, _class, info))
    }

    public static func createPromise(in env: JXContext) throws -> JXPromise {
        var resolveRef: JSObjectRef?
        var rejectRef: JSObjectRef?
        var exceptionRef: JSValueRef?

        // https://github.com/WebKit/WebKit/blob/b46f54e33e5cb968174e4d20392513e14d04839f/Source/JavaScriptCore/API/JSValue.mm#L158
        guard let promise = JSObjectMakeDeferredPromise(env.context, &resolveRef, &rejectRef, &exceptionRef) else {
            throw JXContext.Errors.cannotCreatePromise
        }

        if exceptionRef != nil {
            throw JXContext.Errors.cannotCreatePromise
        }

        guard let resolve = resolveRef else {
            throw JXContext.Errors.cannotCreatePromise
        }
        let resolveFunction = JXValue(env: env, value: resolve)

        guard let reject = rejectRef else {
            throw JXContext.Errors.cannotCreatePromise
        }
        let rejectFunction = JXValue(env: env, value: reject)

        return (promise, resolveFunction, rejectFunction)
    }

    /// Creates a promise and executes it immediately
    /// - Parameters:
    ///   - env: the context to use for creation
    ///   - executor: the executor callback
    public convenience init(newPromiseIn env: JXContext, executor: (JXContext, _ resolve: JXValue, _ reject: JXValue) throws -> ()) throws {
        let (promise, resolve, reject) = try Self.createPromise(in: env)
        try executor(env, resolve, reject)
        self.init(env: env, value: promise)
    }

    public convenience init(newPromiseResolvedWithResult result: JXValue, in env: JXContext) throws {
        try self.init(newPromiseIn: env) { ctx, resolve, reject in
            resolve.call(withArguments: [result])
        }
    }

    public convenience init(newPromiseRejectedWithResult reason: JXValue, in env: JXContext) throws {
        try self.init(newPromiseIn: env) { ctx, resolve, reject in
            reject.call(withArguments: [reason])
        }
    }

}

@available(macOS 11, iOS 12, tvOS 12, *)
private struct JXFunctionInfo {
    unowned let context: JXContext
    let callback: JXFunction
}

@available(macOS 11, iOS 12, tvOS 12, *)
public typealias JXPromise = (promise: JXValueRef, resolveFunction: JXValue, rejectFunction: JXValue)

@available(macOS 11, iOS 12, tvOS 12, *)
private func JXFunctionFinalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

@available(macOS 11, iOS 12, tvOS 12, *)
private func JXFunctionConstructor(_ ctx: JXContextRef?, _ object: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSObjectRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let env = info.pointee.context

    do {
        let arguments = (0..<argumentCount).map { JXValue(env: env, value: arguments![$0]!) }
        let result = try info.pointee.callback(env, nil, arguments)

        let prototype = JSObjectGetPrototype(env.context, object)
        JSObjectSetPrototype(env.context, result.value, prototype)

        return result.value
    } catch let error {
        let error = error as? JXValue ?? JXValue(newErrorFromMessage: "\(error)", in: env)
        exception?.pointee = error.value
        return nil
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
private func JXFunctionCallback(_ ctx: JXContextRef?, _ object: JSObjectRef?, _ this: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let env = info.pointee.context

    do {
        let this = this.map { JXValue(env: env, value: $0) }
        let arguments = (0..<argumentCount).map { JXValue(env: env, value: arguments![$0]!) }
        let result = try info.pointee.callback(env, this, arguments)
        return result.value
    } catch let error {
        let error = error as? JXValue ?? JXValue(newErrorFromMessage: "\(error)", in: env)
        exception?.pointee = error.value
        return nil
    }
}

@available(macOS 11, iOS 12, tvOS 12, *)
private func JXFunctionInstanceOf(_ ctx: JXContextRef?, _ constructor: JSObjectRef?, _ possibleInstance: JSValueRef?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> Bool {
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JXFunctionInfo.self)
    let env = info.pointee.context
    let pt1 = JSObjectGetPrototype(env.context, constructor)
    let pt2 = JSObjectGetPrototype(env.context, possibleInstance)
    return JSValueIsStrictEqual(env.context, pt1, pt2)
}


@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {

    /// Defines a property on the JavaScript object value or modifies a property’s definition.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///   - descriptor: The descriptor object.
    ///
    /// - Returns: true if the operation succeeds, otherwise false.
    @discardableResult
    public func defineProperty(_ property: String, _ descriptor: JXProperty) -> Bool {

        let desc = JXValue(newObjectIn: env)

        if let value = descriptor.value { desc["value"] = value }
        if let writable = descriptor.writable { desc["writable"] = JXValue(bool: writable, in: env) }
        if let getter = descriptor._getter {
            desc["get"] = getter
        } else if let getter = descriptor.getter {
            desc["get"] = JXValue(newFunctionIn: env) { _, this, _ in try getter(this!) }
        }
        if let setter = descriptor._setter {
            desc["set"] = setter
        } else if let setter = descriptor.setter {
            desc["set"] = JXValue(newFunctionIn: env) { context, this, arguments in
                try setter(this!, arguments[0])
                return JXValue(undefinedIn: context)
            }
        }
        if let configurable = descriptor.configurable {
            desc["configurable"] = JXValue(bool: configurable, in: env)
        }

        if let enumerable = descriptor.enumerable {
            desc["enumerable"] = JXValue(bool: enumerable, in: env)
        }

        env.objectPrototype.invokeMethod("defineProperty", withArguments: [self, JXValue(string: property, in: env), desc])

        return env.currentError == nil
    }

    public func propertyDescriptor(_ property: String) -> JXValue {
        env.objectPrototype.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, JXValue(string: property, in: env)])
    }
}


// MARK: Properties

/// A descriptor for property’s definition
@available(macOS 11, iOS 12, tvOS 12, *)
public struct JXProperty {
    public let value: JXValue?
    public let writable: Bool?
    fileprivate let _getter: JXValue?
    fileprivate let _setter: JXValue?
    public let getter: ((JXValue) throws -> JXValue)?
    public let setter: ((JXValue, JXValue) throws -> Void)?
    public var configurable: Bool? = nil
    public var enumerable: Bool? = nil

    /// Generic Descriptor
    ///
    /// Contains one or both of the keys enumerable or configurable. Use a genetic descriptor to modify the attributes of an existing
    /// data or accessor property, or to create a new data property.
    public init() {
        self.value = nil
        self.writable = nil
        self._getter = nil
        self._setter = nil
        self.getter = nil
        self.setter = nil
    }

    /// Data Descriptor
    ///
    /// Contains one or both of the keys value and writable, and optionally also contains the keys enumerable or configurable. Use a
    /// data descriptor to create or modify the attributes of a data property on an object (replacing any existing accessor property).
    public init(value: JXValue? = nil, writable: Bool? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) {
        self.value = value
        self.writable = writable
        self._getter = nil
        self._setter = nil
        self.getter = nil
        self.setter = nil
        self.configurable = configurable
        self.enumerable = enumerable
    }

    /// Accessor Descriptor
    ///
    /// Contains one or both of the keys get or set, and optionally also contains the keys enumerable or configurable. Use an accessor
    /// descriptor to create or modify the attributes of an accessor property on an object (replacing any existing data property).
    ///
    /// ```
    /// let desc = JXProperty(
    ///     getter: { this in this["private_val"] },
    ///     setter: { this, newValue in this["private_val"] = newValue }
    /// )
    /// ```
    public init(getter: ((JXValue) -> JXValue)? = nil, setter: ((JXValue, JXValue) -> Void)? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) {
        self.value = nil
        self.writable = nil
        self._getter = nil
        self._setter = nil
        self.getter = getter
        self.setter = setter
        self.configurable = configurable
        self.enumerable = enumerable
    }

    /// Accessor Descriptor
    ///
    /// Contains one or both of the keys get or set, and optionally also contains the keys enumerable or configurable. Use an accessor
    /// descriptor to create or modify the attributes of an accessor property on an object (replacing any existing data property).
    public init(getter: JXValue? = nil, setter: JXValue? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) {
        precondition(getter?.isFunction != false, "Invalid getter type")
        precondition(setter?.isFunction != false, "Invalid setter type")
        self.value = nil
        self.writable = nil
        self._getter = getter
        self._setter = setter
        self.getter = getter.map { getter in { this in getter.call(withArguments: [], this: this) } }
        self.setter = setter.map { setter in { this, newValue in setter.call(withArguments: [newValue], this: this) } }
        self.configurable = configurable
        self.enumerable = enumerable
    }
}


/// A type of JavaScript instance.
public enum JXType : Hashable {
    /// A boolean type.
    case boolean
    /// A number type.
    case number
    /// A date type.
    case date
    /// A buffer type
    case buffer
    /// A string type.
    case string
    /// An array type.
    case array
    /// An object type
    case object
}

@available(macOS 11, iOS 12, tvOS 12, *)
extension JXValue {
    @inlinable public var type: JXType? {
        if isUndefined { return nil }
        if isNull { return nil }
        if isBoolean { return .boolean }
        if isNumber { return .number }
        if isDate { return .date }
        if isString { return .string }
        if isArray { return .array }
        if isObject { return .object }
        return nil
    }
}
