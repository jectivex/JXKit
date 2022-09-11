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
@available(macOS 11, iOS 13, tvOS 13, *)
public final class JXValue {
    @usableFromInline let env: JXContext
    @usableFromInline let value: JXValueRef

    public convenience init(env: JXContext, value: JXValue) {
        self.init(env: env, valueRef: value.value)
    }

    @usableFromInline internal init(env: JXContext, valueRef: JXValueRef) {
        JSValueProtect(env.context, valueRef)
        self.env = env
        self.value = valueRef
    }

    deinit {
        JSValueUnprotect(env.context, value)
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    @usableFromInline static let rfc3339: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()

}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {

    /// Creates a JavaScript value of the `undefined` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(undefinedIn env: JXContext) {
        self.init(env: env, valueRef: JSValueMakeUndefined(env.context))
    }

    /// Creates a JavaScript value of the `null` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(nullIn env: JXContext) {
        self.init(env: env, valueRef: JSValueMakeNull(env.context))
    }

    /// Creates a JavaScript `Boolean` value.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(bool value: Bool, in env: JXContext) {
        self.init(env: env, valueRef: JSValueMakeBoolean(env.context, value))
    }

    /// Creates a JavaScript value of the `Number` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(double value: Double, in env: JXContext) {
        self.init(env: env, valueRef: JSValueMakeNumber(env.context, value))
    }

    /// Creates a JavaScript value of the `String` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(string value: String, in env: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(env: env, valueRef: JSValueMakeString(env.context, value))
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
        self.init(env: env, valueRef: json)
    }

    /// Creates a JavaScript `Date` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(date value: Date, in env: JXContext) throws {
        let arguments = [JXValue(string: JXValue.rfc3339.string(from: value), in: env)]
        let object = try throwing(env: env) {
            JSObjectMakeDate(env.context, 1, arguments.map { $0.value }, $0)
        }
        self.init(env: env, valueRef: object!)
    }

    /// Creates a JavaScript `RegExp` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - pattern: The pattern of regular expression.
    ///   - flags: The flags pass to the constructor.
    ///   - context: The execution context to use.
    @inlinable public convenience init(newRegularExpressionFromPattern pattern: String, flags: String, in env: JXContext) throws {
        let arguments = [JXValue(string: pattern, in: env), JXValue(string: flags, in: env)]
        let object = try throwing(env: env) {
            JSObjectMakeRegExp(env.context, 2, arguments.map { $0.value }, $0)
        }
        self.init(env: env, valueRef: object!)
    }

    /// Creates a JavaScript `Error` object, as if by invoking the built-in `Error` constructor.
    ///
    /// - Parameters:
    ///   - message: The error message.
    ///   - context: The execution context to use.
    @inlinable public convenience init(newErrorFromMessage message: String, in env: JXContext) throws {
        let arguments = [JXValue(string: message, in: env)]
        let object = try throwing(env: env) {
            JSObjectMakeError(env.context, arguments.count, arguments.map { $0.value }, $0)
        }
        self.init(env: env, valueRef: object!)
    }

    /// Creates a JavaScript `Object`.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newObjectIn env: JXContext) {
        self.init(env: env, valueRef: JSObjectMake(env.context, nil, nil))
    }

    /// Creates a JavaScript `Object` with prototype.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - prototype: The prototype to be used.
    @inlinable public convenience init(newObjectIn env: JXContext, prototype: JXValue) throws {
        let obj = try env.objectPrototype.invokeMethod("create", withArguments: [prototype])
        self.init(env: env, valueRef: obj.value)
    }

    /// Creates a JavaScript `Array` object.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newArrayIn env: JXContext, values: [JXValue]? = nil) throws {
        let array = try throwing(env: env) {
            JSObjectMakeArray(env.context, 0, nil, $0)
        }
        self.init(env: env, valueRef: array!)
        if let values = values {
            for (index, element) in values.enumerated() {
                try self.setElement(element, at: UInt32(index))
            }
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue: CustomStringConvertible {

    @inlinable public var description: String {
        if self.isUndefined {
            return "undefined"
        }
        if self.isNull {
            return "null"
        }
        if self.isBoolean {
            return "\(self.booleanValue)"
        }
        if self.isNumber {
            return ((try? self.numberValue) ?? .nan).description
        }
        if self.isString {
            return (try? self.stringValue) ?? "string"
        }

        // better to not invoke a method from `description`
        //return try! self.invokeMethod("toString", withArguments: []).stringValue!
        
        return "[JXValue]"
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    /// Object’s prototype.
    @inlinable public var prototype: JXValue {
        get {
            let prototype = JSObjectGetPrototype(env.context, value)
            return prototype.map { JXValue(env: env, valueRef: $0) } ?? JXValue(undefinedIn: env)
        }
        set {
            JSObjectSetPrototype(env.context, value, newValue.value)
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
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

    /// Tests whether an object can be called as a constructor.
    @inlinable public var isConstructor: Bool {
        isObject && JSObjectIsConstructor(env.context, value)
    }

    /// Tests whether an object can be called as a function.
    @inlinable public var isFunction: Bool {
        isObject && JSObjectIsFunction(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the date type.
    @inlinable public var isDate: Bool {
        get throws {
            try isInstance(of: env.datePrototype)
        }
    }

    /// Tests whether a JavaScript value’s type is the array type.
    @inlinable public var isArray: Bool {
        get throws {
            let result = try env.arrayPrototype.invokeMethod("isArray", withArguments: [self])
            return JSValueToBoolean(env.context, result.value)
        }
    }

    /// Tests whether a JavaScript value’s type is the error type.
    @inlinable public var isError: Bool {
        get throws {
            try isInstance(of: env.errorPrototype)
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {

    @inlinable public var isFrozen: Bool {
        get throws {
            try env.objectPrototype.invokeMethod("isFrozen", withArguments: [self]).booleanValue
        }
    }

    @inlinable public var isExtensible: Bool {
        get throws {
            try env.objectPrototype.invokeMethod("isExtensible", withArguments: [self]).booleanValue
        }
    }

    @inlinable public var isSealed: Bool {
        get throws {
            try env.objectPrototype.invokeMethod("isSealed", withArguments: [self]).booleanValue
        }
    }

    @inlinable public func freeze() throws {
        try env.objectPrototype.invokeMethod("freeze", withArguments: [self])
    }

    @inlinable public func preventExtensions() throws {
        try env.objectPrototype.invokeMethod("preventExtensions", withArguments: [self])
    }

    @inlinable public func seal() throws {
        try env.objectPrototype.invokeMethod("seal", withArguments: [self])
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {

    /// Returns the JavaScript boolean value.
    @inlinable public var booleanValue: Bool {
        JSValueToBoolean(env.context, value)
    }

    /// Returns the JavaScript number value.
    @inlinable public var numberValue: Double {
        get throws {
            //if !JSValueIsNumber(env.context, value) { return nil }
            try throwing(env: env) {
                JSValueToNumber(env.context, value, $0)
            }
        }
    }

    /// Returns the JavaScript string value.
    @inlinable public var stringValue: String {
        get throws {
            let str = try throwing(env: env) {
                JSValueToStringCopy(env.context, value, $0)
            }
            defer { str.map(JSStringRelease) }
            return str.map(String.init) ?? ""
        }
    }

    @inlinable public var dateValue: Date? {
        get throws {
            //try dateValueMS
            return try dateValueISO
        }
    }

    //    /// Returns the JavaScript date value; this works, but loses the time zone
    //    @inlinable public var dateValueMS: Date? {
    //        if !isDate {
    //            return nil
    //        }
    //        let result = self.invokeMethod("getTime", withArguments: [])
    //        return result.numberValue.flatMap { Date(timeIntervalSince1970: $0) }
    //    }

    /// Returns the JavaScript date value.
    @inlinable public var dateValueISO: Date? {
        get throws {
            if !(try isDate) {
                return nil
            }
            let result = try invokeMethod("toISOString", withArguments: [])
            return try JXValue.rfc3339.date(from: result.stringValue)
        }
    }

    /// Returns the JavaScript array.
    @inlinable public var array: [JXValue] {
        get throws {
            return try (0..<UInt32(self.count)).map { try self[$0] }
        }
    }

    /// Returns the JavaScript object as dictionary.
    @inlinable public var dictionary: [String: JXValue]? {
        get throws {
            !isObject ? nil : try self.properties.reduce(into: [:]) { $0[$1] = try self[$1] }
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {

    /// Calls an object as a function.
    ///
    /// - Parameters:
    ///   - arguments: The arguments pass to the function.
    ///   - this: The object to use as `this`, or `nil` to use the global object as `this`.
    ///
    /// - Returns: The object that results from calling object as a function
    @discardableResult @inlinable public func call(withArguments arguments: [JXValue] = [], this: JXValue? = nil) throws -> JXValue {
        if !isFunction {
            // we should have already validated that it is a function
            throw JXErrors.callOnNonFunction
        }
        let result = try throwing(env: env) {
            JSObjectCallAsFunction(env.context, value, this?.value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, $0)
        }
        return result.map {
            let v = JXValue(env: env, valueRef: $0)
            return v
        } ?? JXValue(undefinedIn: env)
    }

    /// Calls an object as a constructor.
    ///a
    /// - Parameters:
    ///   - arguments: The arguments pass to the function.
    ///
    /// - Returns: The object that results from calling object as a constructor.
    @inlinable public func construct(withArguments arguments: [JXValue]) throws -> JXValue {
        let result = try throwing(env: env) {
            JSObjectCallAsConstructor(env.context, value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, $0)
        }
        return result.map { JXValue(env: env, valueRef: $0) } ?? JXValue(undefinedIn: env)
    }

    /// Invoke an object's method.
    ///
    /// - Parameters:
    ///   - name: The name of method.
    ///   - arguments: The arguments pass to the function.
    ///
    /// - Returns: The object that results from calling the method.
    @discardableResult
    @inlinable public func invokeMethod(_ name: String, withArguments arguments: [JXValue]) throws -> JXValue {
        try self[name].call(withArguments: arguments, this: self)
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
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
    @inlinable public func isEqualWithTypeCoercion(to other: JXValue) throws -> Bool {
        try throwing(env: env) {
            JSValueIsEqual(env.context, value, other.value, $0)
        }
    }

    /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the `isInstance(of:)` operator.
    ///
    /// - Parameters:
    ///   - other: The constructor to test against.
    ///
    /// - Returns: true if the value is an object constructed by constructor, as compared by the JS isInstance(of:) operator; otherwise false.
    @inlinable public func isInstance(of other: JXValue) throws -> Bool {
        try throwing(env: env) {
            JSValueIsInstanceOfConstructor(env.context, value, other.value, $0)
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
@usableFromInline func throwing<T>(env: JXContext, block: (UnsafeMutablePointer<JSValueRef?>) throws -> T?) throws -> T! {
    var val: JSValueRef?
    let result = try block(&val)
    if let val = val {
        throw JXErrors.jxerror(JXValue(env: env, valueRef: val))
    }
    return result
}

@available(macOS 11, iOS 13, tvOS 13, *)
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
    @inlinable public func removeProperty(_ property: String) throws -> Bool {
        let property = property.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(property) }
        return try throwing(env: env) {
            JSObjectDeleteProperty(env.context, value, property, $0)
        }
    }

    /// Checks if a property exists
    ///
    /// - Parameters:
    ///   - property: The property's key (usually a string or number).
    ///
    /// - Returns: true if a property with the given key exists
    @discardableResult
    @inlinable public func hasProperty(_ property: JXValue) throws -> Bool {
        if !isObject { return false }
        return try throwing(env: env) {
            JSObjectHasPropertyForKey(env.context, value, property.value, $0)
        }
    }

    /// Deletes a property from an object or array.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    @inlinable public func deleteProperty(_ property: JXValue) throws -> Bool {
        try throwing(env: env) {
            JSObjectDeletePropertyForKey(env.context, value, property.value, $0)
        }
    }

    /// The value of the property.
    @inlinable public subscript(propertyName: String) -> JXValue {
        get throws {
            if !isObject { return env.undefined() }
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            let result = try throwing(env: env) {
                JSObjectGetProperty(env.context, value, property, $0)
            }
            return result.map { JXValue(env: env, valueRef: $0) } ?? JXValue(undefinedIn: env)
        }
    }

    @inlinable public func setProperty(_ key: String, _ newValue: JXValue) throws {
        if !isObject {
            throw JXErrors.propertyAccessNonObject
        }

        let property = JSStringCreateWithUTF8CString(key)
        defer { JSStringRelease(property) }
        try throwing(env: env) {
            JSObjectSetProperty(env.context, value, property, newValue.value, 0, $0)
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    /// The length of the object.
    @inlinable public var count: Int {
        get throws {
            let dbl = try self["length"].numberValue
            return dbl.isNaN || dbl.isSignalingNaN || dbl.isInfinite == true ? 0 : Int(dbl)
        }
    }

    /// The value in object at index.
    @inlinable public subscript(index: UInt32) -> JXValue {
        get throws {
            let result = try throwing(env: env) {
                JSObjectGetPropertyAtIndex(env.context, value, index, $0)
            }
            return result.map { JXValue(env: env, valueRef: $0) } ?? JXValue(undefinedIn: env)
        }
    }

    @inlinable public func setElement(_ element: JXValue, at index: UInt32) throws {
        try throwing(env: env) {
            JSObjectSetPropertyAtIndex(env.context, value, index, element.value, $0)
        }
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    /// Returns the JavaScript string with the given indentation. This should be the same as the output of `JSON.stringify`.
    @inlinable public func toJSON(indent: UInt32 = 0) throws -> String {
        let str = try throwing(env: env) {
            JSValueCreateJSONString(env.context, value, indent, $0)
        }
        defer { str.map(JSStringRelease) }
        return str.map(String.init) ?? "null"
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - length: Length of new `ArrayBuffer` object.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithLength length: Int, in env: JXContext) throws {
        let obj = try env.arrayBufferPrototype.construct(withArguments: [JXValue(double: Double(length), in: env)])
        self.init(env: env, valueRef: obj.value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to be used as the backing store of the `ArrayBuffer` object.
    ///   - deallocator: The allocator to use to deallocate the external buffer when the `ArrayBuffer` object is deallocated.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithBytesNoCopy bytes: UnsafeMutableRawBufferPointer, deallocator: @escaping (UnsafeMutableRawBufferPointer) -> Void, in env: JXContext) throws {

        typealias Deallocator = () -> Void

        let info: UnsafeMutablePointer<Deallocator> = .allocate(capacity: 1)
        info.initialize(to: { deallocator(bytes) })

        let value = try throwing(env: env) {
            JSObjectMakeArrayBufferWithBytesNoCopy(env.context, bytes.baseAddress, bytes.count, { _, info in
                guard let info = info?.assumingMemoryBound(to: Deallocator.self) else { return }
                info.pointee()
                info.deinitialize(count: 1).deallocate()
            }, info, $0)
        }

        guard let value = value else {
            throw JXErrors.cannotCreateArrayBuffer
        }

        self.init(env: env, valueRef: value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to copy.
    ///   - context: The execution context to use.
    public convenience init<S: DataProtocol>(newArrayBufferWithBytes bytes: S, in env: JXContext) throws {

        let buffer: UnsafeMutableRawPointer = .allocate(byteCount: bytes.count, alignment: MemoryLayout<UInt8>.alignment)
        bytes.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count))

        guard let bufValue = try throwing(env: env, block: {
            JSObjectMakeArrayBufferWithBytesNoCopy(env.context, buffer, bytes.count, { buffer, _ in buffer?.deallocate() }, nil, $0)
        }) else {
            throw JXErrors.cannotCreateArrayBuffer
        }

        self.init(env: env, valueRef: bufValue)
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    /// Tests whether a JavaScript value’s type is the `ArrayBuffer` type.
    public var isArrayBuffer: Bool {
        get throws {
            try isInstance(of: env.arrayBufferPrototype)
        }
    }

    /// The length (in bytes) of the `ArrayBuffer`.
    public var byteLength: Int {
        get throws {
            try Int(self["byteLength"].numberValue)
        }
    }

    /// Copy the bytes of `ArrayBuffer`.
    public func copyBytes() throws -> Data? {
        guard try self.isArrayBuffer else { return nil }
        let length = try throwing(env: env) {
            JSObjectGetArrayBufferByteLength(env.context, value, $0)
        }
        return try throwing(env: env) {
            Data(bytes: JSObjectGetArrayBufferBytesPtr(env.context, value, $0), count: length!)
        }
    }
}

extension String {
    /// Creates a `Swift.String` from a `JXStringRef`
    @inlinable internal init(_ str: JXStringRef) {
        self.init(utf16CodeUnits: JSStringGetCharactersPtr(str), count: JSStringGetLength(str))
    }
}


// MARK: Functions


/// A function definition, used when defining callbacks.
@available(macOS 11, iOS 13, tvOS 13, *)
public typealias JXFunction = (JXContext, JXValue?, [JXValue]) throws -> JXValue


@available(macOS 11, iOS 13, tvOS 13, *)
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

        self.init(env: env, valueRef: JSObjectMake(env.context, _class, info))
    }

    public static func createPromise(in env: JXContext) throws -> JXPromise {
        var resolveRef: JSObjectRef?
        var rejectRef: JSObjectRef?

        // https://github.com/WebKit/WebKit/blob/b46f54e33e5cb968174e4d20392513e14d04839f/Source/JavaScriptCore/API/JSValue.mm#L158
        guard let promise = try throwing(env: env, block: {
            JSObjectMakeDeferredPromise(env.context, &resolveRef, &rejectRef, $0)
        }) else {
            throw JXErrors.cannotCreatePromise
        }

        guard let resolve = resolveRef else {
            throw JXErrors.cannotCreatePromise
        }
        let resolveFunction = JXValue(env: env, valueRef: resolve)

        guard let reject = rejectRef else {
            throw JXErrors.cannotCreatePromise
        }
        let rejectFunction = JXValue(env: env, valueRef: reject)

        return (JXValue(env: env, valueRef: promise), resolveFunction, rejectFunction)
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
            try resolve.call(withArguments: [result])
        }
    }

    public convenience init(newPromiseRejectedWithResult reason: JXValue, in env: JXContext) throws {
        try self.init(newPromiseIn: env) { ctx, resolve, reject in
            try reject.call(withArguments: [reason])
        }
    }

}

@available(macOS 11, iOS 13, tvOS 13, *)
private struct JXFunctionInfo {
    unowned let context: JXContext
    let callback: JXFunction
}

@available(macOS 11, iOS 13, tvOS 13, *)
public typealias JXPromise = (promise: JXValue, resolveFunction: JXValue, rejectFunction: JXValue)

@available(macOS 11, iOS 13, tvOS 13, *)
private func JXFunctionFinalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

@available(macOS 11, iOS 13, tvOS 13, *)
private func JXFunctionConstructor(_ ctx: JXContextRef?, _ object: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSObjectRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let env = info.pointee.context

    do {
        let arguments = (0..<argumentCount).map { JXValue(env: env, valueRef: arguments![$0]!) }
        let result = try info.pointee.callback(env, nil, arguments)

        let prototype = JSObjectGetPrototype(env.context, object)
        JSObjectSetPrototype(env.context, result.value, prototype)

        return result.value
    } catch let error {
        let error = (error as? JXValueError)?.value ?? (try? JXValue(newErrorFromMessage: "\(error)", in: env))
        exception?.pointee = error?.value
        return nil
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
private func JXFunctionCallback(_ ctx: JXContextRef?, _ object: JSObjectRef?, _ this: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let env = info.pointee.context

    do {
        let this = this.map { JXValue(env: env, valueRef: $0) }
        let arguments = (0..<argumentCount).map { JXValue(env: env, valueRef: arguments![$0]!) }
        let result = try info.pointee.callback(env, this, arguments)
        return result.value
    } catch let error {
        let error = (error as? JXValueError)?.value ?? (try? JXValue(newErrorFromMessage: "\(error)", in: env))
        exception?.pointee = error?.value
        return nil
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
private func JXFunctionInstanceOf(_ ctx: JXContextRef?, _ constructor: JSObjectRef?, _ possibleInstance: JSValueRef?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> Bool {
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JXFunctionInfo.self)
    let env = info.pointee.context
    let pt1 = JSObjectGetPrototype(env.context, constructor)
    let pt2 = JSObjectGetPrototype(env.context, possibleInstance)
    return JSValueIsStrictEqual(env.context, pt1, pt2)
}


@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {

    /// Defines a property on the JavaScript object value or modifies a property’s definition.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///   - descriptor: The descriptor object.
    ///
    /// - Returns: true if the operation succeeds, otherwise false.
    public func defineProperty(_ property: String, _ descriptor: JXProperty) throws {
        let desc = JXValue(newObjectIn: env)

        if let value = descriptor.value {
            try desc.setProperty("value", value)
        }

        if let writable = descriptor.writable {
            try desc.setProperty("writable", JXValue(bool: writable, in: env))
        }

        if let getter = descriptor._getter {
            try desc.setProperty("get", getter)
        } else if let getter = descriptor.getter {
            try desc.setProperty("get", JXValue(newFunctionIn: env) { _, this, _ in try getter(this!) })
        }

        if let setter = descriptor._setter {
            try desc.setProperty("set", setter)
        } else if let setter = descriptor.setter {
            try desc.setProperty("set", JXValue(newFunctionIn: env) { context, this, arguments in
                try setter(this!, arguments[0])
                return JXValue(undefinedIn: context)
            })
        }
        
        if let configurable = descriptor.configurable {
            try desc.setProperty("configurable", JXValue(bool: configurable, in: env))
        }

        if let enumerable = descriptor.enumerable {
            try desc.setProperty("enumerable", JXValue(bool: enumerable, in: env))
        }

        try env.objectPrototype.invokeMethod("defineProperty", withArguments: [self, JXValue(string: property, in: env), desc])
    }

    public func propertyDescriptor(_ property: String) throws -> JXValue {
        try env.objectPrototype.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, JXValue(string: property, in: env)])
    }
}


// MARK: Properties

/// A descriptor for property’s definition
@available(macOS 11, iOS 13, tvOS 13, *)
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
    public init(getter: ((JXValue) throws -> JXValue)? = nil, setter: ((JXValue, JXValue) throws -> Void)? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) {
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
    public init(getter: JXValue? = nil, setter: JXValue? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) throws {
        precondition(getter?.isFunction != false, "Invalid getter type")
        precondition(setter?.isFunction != false, "Invalid setter type")
        self.value = nil
        self.writable = nil
        self._getter = getter
        self._setter = setter
        self.getter = getter.map { getter in { this in try getter.call(withArguments: [], this: this) } }
        self.setter = setter.map { setter in { this, newValue in try setter.call(withArguments: [newValue], this: this) } }
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

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXValue {
    @inlinable public var type: JXType? {
        if isUndefined { return nil }
        if isNull { return nil }
        if isBoolean { return .boolean }
        if isNumber { return .number }
        if (try? isDate) == true { return .date }
        if isString { return .string }
        if (try? isArray) == true { return .array }
        if isObject { return .object }
        return nil
    }
}
