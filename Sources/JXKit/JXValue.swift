import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

/// A JavaScript object.
///
/// This wraps a `JSObjectRef`, and is the equivalent of `JavaScriptCore.JSValue`.
public class JXValue {
    public let context: JXContext
    let valueRef: JXValueRef

    public convenience init(context: JXContext, value: JXValue) {
        self.init(context: context, valueRef: value.valueRef)
    }

    init(context: JXContext, valueRef: JXValueRef) {
        JSValueProtect(context.contextRef, valueRef)
        self.context = context
        self.valueRef = valueRef
    }

    deinit {
        JSValueUnprotect(context.contextRef, valueRef)
    }
}

extension JXValue {
    static let rfc3339: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

extension JXValue {

    /// Creates a JavaScript value of the `undefined` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    convenience init(undefinedIn context: JXContext) {
        self.init(context: context, valueRef: JSValueMakeUndefined(context.contextRef))
    }

    /// Creates a JavaScript value of the `null` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    convenience init(nullIn context: JXContext) {
        self.init(context: context, valueRef: JSValueMakeNull(context.contextRef))
    }

    /// Creates a JavaScript `Boolean` value.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    convenience init(bool value: Bool, in context: JXContext) {
        self.init(context: context, valueRef: JSValueMakeBoolean(context.contextRef, value))
    }

    /// Creates a JavaScript value of the `Number` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    convenience init(double value: Double, in context: JXContext) {
        self.init(context: context, valueRef: JSValueMakeNumber(context.contextRef, value))
    }

    /// Creates a JavaScript value of the `String` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    convenience init(string value: String, in context: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(context: context, valueRef: JSValueMakeString(context.contextRef, value))
    }

    /// Creates a JavaScript value of the `Symbol` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    convenience init(symbol value: String, in context: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(context: context, valueRef: JSValueMakeSymbol(context.contextRef, value))
    }

    /// Creates a JavaScript value of the parsed `JSON`.
    ///
    /// - Parameters:
    ///   - value: The JSON value to parse
    ///   - context: The execution context to use.
    convenience init?(json value: String, in context: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        guard let json = JSValueMakeFromJSONString(context.contextRef, value) else {
            return nil // We just return nil since there is no error parameter
        }
        self.init(context: context, valueRef: json)
    }

    /// Creates a JavaScript `Date` object, as if by invoking the built-in `JSObjectMakeDate` constructor.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    convenience init(date value: Date, in context: JXContext) throws {
        let arguments = [JXValue(string: JXValue.rfc3339.string(from: value), in: context)]
        let object = try context.trying {
            JSObjectMakeDate(context.contextRef, 1, arguments.map { $0.valueRef }, $0)
        }
        self.init(context: context, valueRef: object!)
    }

    /// Creates a JavaScript `RegExp` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - pattern: The pattern of regular expression.
    ///   - flags: The flags pass to the constructor.
    ///   - context: The execution context to use.
    convenience init(newRegularExpressionFromPattern pattern: String, flags: String, in context: JXContext) throws {
        let arguments = [JXValue(string: pattern, in: context), JXValue(string: flags, in: context)]
        let object = try context.trying {
            JSObjectMakeRegExp(context.contextRef, 2, arguments.map { $0.valueRef }, $0)
        }
        self.init(context: context, valueRef: object!)
    }
    
    /// Creates a JavaScript `Error` object, as if by invoking the built-in `Error` constructor.
    ///
    /// - Parameters:
    ///   - message: The error message.
    ///   - context: The execution context to use.
    convenience init(newErrorFromCause cause: Error, in context: JXContext) throws {
        // If the cause itself has a cause, use that as the JS error message so that if this is a JXError
        // caused by a native error, any JS catch block can test for the original native error message,
        // without the added JX context
        let rootCause = (cause as? JXError)?.cause ?? cause
        let messageValue =  context.string("\(rootCause)")
        // Error's second constructor param is an options object with a 'cause' property of any type.
        // Use this to transfer the original cause as a peer
        let causeValue = context.object()
        try causeValue.setProperty("cause", context.object(peer: JXErrorPeer(error: cause)))
        let arguments = [messageValue, causeValue]
        let object = try context.trying {
            JSObjectMakeError(context.contextRef, arguments.count, arguments.map { $0.valueRef }, $0)
        }
        self.init(context: context, valueRef: object!)
    }

    /// Creates a JavaScript `Object`.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    convenience init(newObjectIn context: JXContext) {
        self.init(context: context, valueRef: JSObjectMake(context.contextRef, nil, nil))
    }

    /// Creates a JavaScript `Object` with prototype.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - prototype: The prototype to be used.
    convenience init(newObjectIn context: JXContext, prototype: JXValue) throws {
        let obj = try context.objectPrototype.invokeMethod("create", withArguments: [prototype])
        self.init(context: context, valueRef: obj.valueRef)
    }

    /// Creates a JavaScript `Array` object.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    convenience init(newArrayIn context: JXContext, values: [JXValue]? = nil) throws {
        let array = try context.trying {
            JSObjectMakeArray(context.contextRef, 0, nil, $0)
        }
        self.init(context: context, valueRef: array!)
        if let values = values {
            for (index, element) in values.enumerated() {
                try self.setElement(element, at: index)
            }
        }
    }
}

// We intentionally do not implement Equatable and Hashable to avoid confusion around the semantics of equatability.
//
//extension JXValue: Equatable, Hashable {
//    public static func == (lhs: JXKit.JXValue, rhs: JXKit.JXValue) -> Bool {
//        lhs.value == rhs.value
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        value.hash(into: &hasher)
//    }
//}

extension JXValue: CustomStringConvertible {

    public var description: String {
        switch self.type {
        case .undefined:
            return "undefined"
        case .null:
            return "null"
        case .boolean:
            return "\(self.bool)"
        case .number:
            return ((try? self.double) ?? .nan).description
        case .string:
            return (try? self.string) ?? "<string>"
        case .symbol:
            return (try? self.string) ?? "<symbol>"
        case .array:
            return "<array>"
        case .date:
            return (try? self.string) ?? "<date>"
        case .arrayBuffer:
            return "<arrayBuffer>"
        case .promise:
            return "<promise>"
        case .error:
            return (try? self.string) ?? "<error>"
        case .constructor:
            return "<constructor: \((try? self.string) ?? "?")>"
        case .function:
            return "<function: \((try? self.string) ?? "?")>"
        case .object:
            return (try? self.string) ?? "<object>"
        case .other:
            return "<other>"
        }
    }
}

extension JXValue {
    /// Object’s prototype.
    public var prototype: JXValue {
        get {
            let prototype = JSObjectGetPrototype(context.contextRef, valueRef)
            return prototype.map { JXValue(context: context, valueRef: $0) } ?? JXValue(undefinedIn: context)
        }
        set {
            JSObjectSetPrototype(context.contextRef, valueRef, newValue.valueRef)
        }
    }
}

extension JXValue {

    /// Tests whether a JavaScript value’s type is the undefined type.
    public var isUndefined: Bool {
        JSValueIsUndefined(context.contextRef, valueRef)
    }

    /// Tests whether a JavaScript value’s type is the null type.
    public var isNull: Bool {
        JSValueIsNull(context.contextRef, valueRef)
    }

    /// Returns true if the value is either null or undefined.
    public var isNullOrUndefined: Bool {
        isUndefined || isNull
    }

    /// Tests whether a JavaScript value is Boolean.
    public var isBoolean: Bool {
        JSValueIsBoolean(context.contextRef, valueRef)
    }

    /// Tests whether a JavaScript value’s type is the number type.
    public var isNumber: Bool {
        JSValueIsNumber(context.contextRef, valueRef)
    }

    /// Tests whether a JavaScript value’s type is the string type.
    public var isString: Bool {
        JSValueIsString(context.contextRef, valueRef)
    }

    /// Tests whether a JavaScript value’s type is the object type.
    public var isObject: Bool {
        JSValueIsObject(context.contextRef, valueRef)
    }

    /// Tests whether an object can be called as a constructor.
    public var isConstructor: Bool {
        isObject && JSObjectIsConstructor(context.contextRef, valueRef)
    }

    /// Tests whether an object can be called as a function.
    public var isFunction: Bool {
        isObject && JSObjectIsFunction(context.contextRef, valueRef)
    }

    /// Tests whether an object can be called as a function.
    public var isSymbol: Bool {
        JSValueIsSymbol(context.contextRef, valueRef)
    }

    /// Tests whether a JavaScript value’s type is the date type.
    public var isDate: Bool {
        get throws {
            try isInstance(of: context.datePrototype)
        }
    }

    /// Tests whether a JavaScript value’s type is the `Promise` type by seeing it if is an instance of ``JXContext//promisePrototype``.
    ///
    /// See: [MDN Promise Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)
    public var isPromise: Bool {
        get throws {
            try isInstance(of: context.promisePrototype)
        }
    }

    /// Tests whether a JavaScript value’s type is the array type.
    public var isArray: Bool {
        JSValueIsArray(context.contextRef, valueRef)
    }

    /// Tests whether a JavaScript value’s type is the error type.
    public var isError: Bool {
        get throws {
            try isInstance(of: context.errorPrototype)
        }
    }
}

extension JXValue {

    /// Whether or not the given object is frozen.
    ///
    /// An object is frozen if and only if it is not extensible, all its properties are non-configurable, and all its data properties (that is, properties which are not accessor properties with getter or setter components) are non-writable.
    ///
    /// See: [MDN Object.isFrozen Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/isFrozen)
    public var isFrozen: Bool {
        get throws {
            try context.objectPrototype.invokeMethod("isFrozen", withArguments: [self]).bool
        }
    }

    /// The Object.isExtensible() method determines if an object is extensible (whether it can have new properties added to it).
    ///
    /// Objects are extensible by default: they can have new properties added to them, and their `Prototype` can be re-assigned. An object can be marked as non-extensible using one of ``preventExtensions()`, `seal()`, `freeze()`, or `Reflect.preventExtensions()`.
    ///
    /// See: [MDN Object.isExtensible Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/isExtensible)
    public var isExtensible: Bool {
        get throws {
            try context.objectPrototype.invokeMethod("isExtensible", withArguments: [self]).bool
        }
    }

    /// The Object.isSealed() method determines if an object is sealed.
    ///
    /// Returns true if the object is sealed, otherwise false. An object is sealed if it is not extensible and if all its properties are non-configurable and therefore not removable (but not necessarily non-writable).
    ///
    /// See: [MDN Object.isSealed Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/isSealed)
    public var isSealed: Bool {
        get throws {
            try context.objectPrototype.invokeMethod("isSealed", withArguments: [self]).bool
        }
    }

    /// The Object.freeze() method freezes an object.
    ///
    /// Freezing an object prevents extensions and makes existing properties non-writable and non-configurable. A frozen object can no longer be changed: new properties cannot be added, existing properties cannot be removed, their enumerability, configurability, writability, or value cannot be changed, and the object's prototype cannot be re-assigned. freeze() returns the same object that was passed in.
    ///
    /// Freezing an object is equivalent to preventing extensions and then changing all existing properties' descriptors' configurable to false — and for data properties, writable to false as well. Nothing can be added to or removed from the properties set of a frozen object. Any attempt to do so will fail, either silently or by throwing a TypeError exception (most commonly, but not exclusively, when in strict mode).
    ///
    /// For data properties of a frozen object, their values cannot be changed since the writable and configurable attributes are set to false. Accessor properties (getters and setters) work the same — the property value returned by the getter may still change, and the setter can still be called without throwing errors when setting the property. Note that values that are objects can still be modified, unless they are also frozen. As an object, an array can be frozen; after doing so, its elements cannot be altered and no elements can be added to or removed from the array.
    ///
    /// See: [MDN Object.freeze Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/freeze)
    public func freeze() throws {
        try context.objectPrototype.invokeMethod("freeze", withArguments: [self])
    }

    /// The Object.preventExtensions() method prevents new properties from ever being added to an object (i.e. prevents future extensions to the object). It also prevents the object's prototype from being re-assigned.
    ///
    /// An object is extensible if new properties can be added to it. Object.preventExtensions() marks an object as no longer extensible, so that it will never have properties beyond the ones it had at the time it was marked as non-extensible. Note that the properties of a non-extensible object, in general, may still be deleted. Attempting to add new properties to a non-extensible object will fail, either silently or, in strict mode, throwing a TypeError.
    ///
    /// Unlike Object.seal() and Object.freeze(), Object.preventExtensions() invokes an intrinsic JavaScript behavior and cannot be replaced with a composition of several other operations. It also has its Reflect counterpart (which only exists for intrinsic operations), Reflect.preventExtensions().
    ///
    /// Object.preventExtensions() only prevents addition of own properties. Properties can still be added to the object prototype.
    ///
    /// This method makes the [[Prototype]] of the target immutable; any [[Prototype]] re-assignment will throw a TypeError. This behavior is specific to the internal [[Prototype]] property; other properties of the target object will remain mutable.
    ///
    /// There is no way to make an object extensible again once it has been made non-extensible.
    ///
    /// See: [MDN Object.preventExtensions Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/preventExtensions)
    public func preventExtensions() throws {
        try context.objectPrototype.invokeMethod("preventExtensions", withArguments: [self])
    }

    /// The Object.seal() method seals an object. Sealing an object prevents extensions and makes existing properties non-configurable.
    ///
    ///  A sealed object has a fixed set of properties: new properties cannot be added, existing properties cannot be removed, their enumerability and configurability cannot be changed, and its prototype cannot be re-assigned.
    ///
    ///  Values of existing properties can still be changed as long as they are writable. seal() returns the same object that was passed in.
    ///
    /// See: [MDN Object.seal Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/seal)
    public func seal() throws {
        try context.objectPrototype.invokeMethod("seal", withArguments: [self])
    }
}

extension JXValue {

    /// Converts a JavaScript value to a Boolean and returns the resulting Boolean.
    public var bool: Bool {
        JSValueToBoolean(context.contextRef, valueRef)
    }

    /// Converts a JavaScript value to a number and returns the resulting number.
    public var double: Double {
        get throws {
            try context.trying {
                JSValueToNumber(context.contextRef, valueRef, $0)
            }
        }
    }

    /// Returns the JavaScript number value.
    public var float: Float {
        get throws {
            return try Float(double)
        }
    }

    private var doubleForIntegerConversion: Double {
        get throws {
            let dbl = try double
            guard !dbl.isNaN && !dbl.isSignalingNaN && !dbl.isInfinite else {
                throw JXError.invalidNumericConversion(self, to: dbl)
            }
            return dbl
        }
    }

    /// Returns the JavaScript number value.
    public var int: Int {
        get throws {
            return try Int(doubleForIntegerConversion)
        }
    }

    /// Returns the JavaScript number value.
    public var int32: Int32 {
        get throws {
            return try Int32(doubleForIntegerConversion)
        }
    }

    /// Returns the JavaScript number value.
    public var int64: Int64 {
        get throws {
            return try Int64(doubleForIntegerConversion)
        }
    }

    /// Returns the JavaScript number value.
    public var uint: UInt {
        get throws {
            return try UInt(doubleForIntegerConversion)
        }
    }

    /// Returns the JavaScript number value.
    public var uint32: UInt32 {
        get throws {
            return try UInt32(doubleForIntegerConversion)
        }
    }

    /// Returns the JavaScript number value.
    public var uint64: UInt64 {
        get throws {
            return try UInt64(doubleForIntegerConversion)
        }
    }

    /// Returns the JavaScript string value.
    public var string: String {
        get throws {
            let str = try context.trying {
                JSValueToStringCopy(context.contextRef, valueRef, $0)
            }
            defer { str.map(JSStringRelease) }
            return str.map(String.init) ?? ""
        }
    }

    /// Returns the JavaScript date value.
    public var date: Date {
        get throws {
            //try dateMS
            return try dateISO
        }
    }

    //    /// Returns the JavaScript date value; this works, but loses the time zone
    //    public var dateMS: Date? {
    //        if !isDate {
    //            return nil
    //        }
    //        let result = self.invokeMethod("getTime", withArguments: [])
    //        return result.double.flatMap { Date(timeIntervalSince1970: $0) }
    //    }

    /// Returns the JavaScript date value.
    ///
    /// See: [MDN Date.toISOString Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date/toISOString)
    public var dateISO: Date {
        get throws {
            if !(try isDate) {
                throw JXError.valueNotDate(self)
            }
            let result = try invokeMethod("toISOString", withArguments: [])
            guard let date = try JXValue.rfc3339.date(from: result.string) else {
                throw JXError.valueNotDate(self)
            }
            return date
        }
    }

    /// Returns the JavaScript array.
    public var array: [JXValue] {
        get throws {
            return try (0..<self.count).map { try self[$0] }
        }
    }

    /// Returns the JavaScript object as a dictionary.
    public var dictionary: [String: JXValue] {
        get throws {
            try self.properties.reduce(into: [:]) { result, property in
                result[property] = try self[property]
            }
        }
    }
}

// When conveying to a specified type, we use function overloads to access the desired optional, array, or dictionary element type.
// That allows any service provider to get dibs on converting individual elements before our JXConvertible and Codable fallbacks take over.
extension JXValue {

    /// Attempts to convey this JavaScript value to a specified type.
    public func convey<T>(to type: T.Type = T.self) throws -> T {
        if let convertibleType = type as? JXConvertible.Type {
            return try convertibleType.fromJX(self) as! T
        } else if let rawRepresentableType = type as? any RawRepresentable.Type {
            return try conveyRawRepresentable(to: rawRepresentableType) as! T
        } else if type is ().Type {
            if isUndefined {
                return () as! T
            }
            throw JXError(message: "Cannot convey JavaScript value '\(description)' to Void. Expected 'undefined'")
        } else if let value = try context.spi?.fromJX(self, to: type) {
            return value
        } else if let decodableType = type as? Decodable.Type {
            return try self.toDecodable(ofType: decodableType) as! T
        } else {
            throw JXError.cannotConvey(type, spi: context.spi, format: "Unable to convey JavaScript value '\(description)' to type '%@'")
        }
    }
    
    private func conveyRawRepresentable<T: RawRepresentable>(to type: T.Type) throws -> T {
        let rawValue = try convey(to: T.RawValue.self)
        guard let ret = T(rawValue: rawValue) else {
            throw JXError(message: "Raw value '\(rawValue)' is not valid for RawRepresentable type '\(type)'")
        }
        return ret
    }
}

extension JXValue {
    
    /// Calls an object as a function.
    ///
    /// - Parameters:
    ///   - arguments: The arguments to pass to the function.
    ///   - this: The object to use as `this`, or `nil` to use the global object as `this`.
    /// - Returns: The object that results from calling object as a function
    @discardableResult public func call(withArguments arguments: [JXValue] = [], this: JXValue? = nil) throws -> JXValue {
        if !isFunction {
            // we should have already validated that it is a function
            throw JXError.valueNotFunction(self)
        }
        do {
            let resultRef = try context.trying {
                JSObjectCallAsFunction(context.contextRef, valueRef, this?.valueRef, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.valueRef }, $0)
            }
            return resultRef.map({ JXValue(context: context, valueRef: $0) }) ?? JXValue(undefinedIn: context)
        } catch {
            throw JXError(cause: error, script: (try? self.string))
        }
    }

    /// Calls an object as a function.
    ///
    /// - Parameters:
    ///   - arguments: The arguments to pass to the function. The arguments will be `conveyed` to `JXValues`.
    ///   - this: The object to use as `this`, or `nil` to use the global object as `this`.
    /// - Returns: The object that results from calling object as a function
    @discardableResult public func call(withArguments arguments: [Any], this: JXValue? = nil) throws -> JXValue {
        let jxarguments = try arguments.map { try context.convey($0) }
        return try call(withArguments: jxarguments, this: this)
    }

    /// Calls an object as a constructor.
    ///
    /// - Parameters:
    ///   - arguments: The arguments to pass to the function.
    /// - Returns: The object that results from calling object as a constructor.
    public func construct(withArguments arguments: [JXValue] = []) throws -> JXValue {
        do {
            let resultRef = try context.trying {
                JSObjectCallAsConstructor(context.contextRef, valueRef, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.valueRef }, $0)
            }
            return resultRef.map { JXValue(context: context, valueRef: $0) } ?? JXValue(undefinedIn: context)
        } catch {
            throw JXError(cause: error, script: (try? self.string))
        }
    }

    /// Calls an object as a constructor.
    ///
    /// - Parameters:
    ///   - arguments: The arguments to pass to the function. The arguments will be `conveyed` to `JXValues`.
    /// - Returns: The object that results from calling object as a constructor.
    public func construct(withArguments arguments: [Any]) throws -> JXValue {
        let jxarguments = try arguments.map { try context.convey($0) }
        return try construct(withArguments: jxarguments)
    }

    /// Invoke an object's method.
    ///
    /// - Parameters:
    ///   - name: The name of the method.
    ///   - arguments: The arguments to pass to the function.
    /// - Returns: The object that results from calling the method.
    @discardableResult public func invokeMethod(_ name: String, withArguments arguments: [JXValue] = []) throws -> JXValue {
        try self[name].call(withArguments: arguments, this: self)
    }

    /// Invoke an object's method.
    ///
    /// - Parameters:
    ///   - name: The name of the method.
    ///   - arguments: The arguments to pass to the function. The arguments will be `conveyed` to `JXValues`.
    /// - Returns: The object that results from calling the method.
    @discardableResult public func invokeMethod(_ name: String, withArguments arguments: [Any]) throws -> JXValue {
        let jxarguments = try arguments.map { try context.convey($0) }
        return try invokeMethod(name, withArguments: jxarguments)
    }
}

extension JXValue {

    /// Tests whether two JavaScript values are strict equal, as compared by the JS `===` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    /// - Returns: true if the two values are strict equal; otherwise false.
    public func isEqual(to other: JXValue) -> Bool {
        JSValueIsStrictEqual(context.contextRef, valueRef, other.valueRef)
    }

    /// Tests whether two JavaScript values are equal, as compared by the JS `==` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    /// - Returns: true if the two values are equal; false if they are not equal or an exception is thrown.
    public func isEqualWithTypeCoercion(to other: JXValue) throws -> Bool {
        try context.trying {
            JSValueIsEqual(context.contextRef, valueRef, other.valueRef, $0)
        }
    }

    /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the `isInstance(of:)` operator.
    ///
    /// - Parameters:
    ///   - other: The constructor to test against.
    /// - Returns: true if the value is an object constructed by constructor, as compared by the JS isInstance(of:) operator; otherwise false.
    public func isInstance(of other: JXValue) throws -> Bool {
        try context.trying {
            JSValueIsInstanceOfConstructor(context.contextRef, valueRef, other.valueRef, $0)
        }
    }
}

extension JXValue {

    /// Get the names of an object’s enumerable properties.
    public var properties: [String] {
        if !isObject { return [] }

        let _list = JSObjectCopyPropertyNames(context.contextRef, valueRef)
        defer { JSPropertyNameArrayRelease(_list) }

        let count = JSPropertyNameArrayGetCount(_list)
        let list = (0..<count).map { JSPropertyNameArrayGetNameAtIndex(_list, $0)! }

        return list.map(String.init)
    }

    /// Tests whether an object has a given property.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    /// - Returns: true if the object has `property`, otherwise false.
    public func hasProperty(_ property: String) -> Bool {
        if !isObject { return false }
        let property = property.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(property) }
        return JSObjectHasProperty(context.contextRef, valueRef, property)
    }

    /// Checks if a property exists
    ///
    /// - Parameters:
    ///   - property: The property's key (usually a string or number).
    /// - Returns: true if a property with the given key exists
    @discardableResult
    public func hasProperty(_ property: JXValue) throws -> Bool {
        if !isObject { return false }
        return try context.trying {
            JSObjectHasPropertyForKey(context.contextRef, valueRef, property.valueRef, $0)
        }
    }
    
    /// Deletes a property from an object.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    public func deleteProperty(_ property: String) throws -> Bool {
        guard hasProperty(property) else {
            return false
        }
        let property = property.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(property) }
        return try context.trying {
            JSObjectDeleteProperty(context.contextRef, valueRef, property, $0)
        }
    }

    /// Deletes a property from an object.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    public func deleteProperty(_ property: JXValue) throws -> Bool {
        try context.trying {
            JSObjectDeletePropertyForKey(context.contextRef, valueRef, property.valueRef, $0)
        }
    }

    /// The value of the property.
    public subscript(propertyName: String) -> JXValue {
        get throws {
            if !isObject { return context.undefined() }
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            let resultRef = try context.trying {
                JSObjectGetProperty(context.contextRef, valueRef, property, $0)
            }
            return resultRef.map { JXValue(context: context, valueRef: $0) } ?? JXValue(undefinedIn: context)
        }
    }

    /// The value of the property for the given symbol.
    public subscript(symbol symbol: JXValue) -> JXValue {
        get throws {
            if !isObject {
                throw JXError.valueNotPropertiesObject(self, property: symbol.description)
            }
            if !symbol.isSymbol {
                throw JXError.valueNotSymbol(symbol)
            }
            let resultRef = try context.trying {
                JSObjectGetPropertyForKey(context.contextRef, valueRef, symbol.valueRef, $0)
            }
            return resultRef.map { JXValue(context: context, valueRef: $0) } ?? JXValue(undefinedIn: context)
        }
    }

    /// Sets the property of the object to the given value.
    ///
    /// - Parameters:
    ///   - key: The key name to set.
    ///   - newValue: The value of the property.
    /// - Returns: The value itself.
    @discardableResult public func setProperty(_ key: String, _ newValue: JXValue) throws -> JXValue {
        if !isObject {
            throw JXError.valueNotPropertiesObject(self, property: key)
        }

        let property = JSStringCreateWithUTF8CString(key)
        defer { JSStringRelease(property) }
        try context.trying {
            JSObjectSetProperty(context.contextRef, valueRef, property, newValue.valueRef, 0, $0)
        }
        return newValue
    }

    /// Sets the property of the object to the given value.
    ///
    /// - Parameters:
    ///   - key: The key name to set.
    ///   - newValue: The value of the property. The value will be `conveyed` to a `JXValue`.
    /// - Returns: The value itself.
    @discardableResult public func setProperty(_ key: String, _ newValue: Any) throws -> JXValue {
        return try setProperty(key, context.convey(newValue))
    }

    /// Sets the property specified by the symbol key.
    ///
    /// - Parameters:
    ///   - key: The name of the symbol to use.
    ///   - newValue: The value to set the property.
    /// - Returns: The value itself.
    @discardableResult public func setProperty(symbol: JXValue, _ newValue: JXValue) throws -> JXValue {
        if !isObject {
            throw JXError.valueNotPropertiesObject(self, property: symbol.description)
        }

        try context.trying {
            JSObjectSetPropertyForKey(context.contextRef, valueRef, symbol.valueRef, newValue.valueRef, 0, $0)
        }
        return newValue
    }

    /// Sets the property specified by the symbol key.
    ///
    /// - Parameters:
    ///   - key: The name of the symbol to use.
    ///   - newValue: The value to set the property. The value will be `conveyed` to a `JXValue`.
    /// - Returns: The value itself.
    @discardableResult public func setProperty(symbol: JXValue, _ newValue: Any) throws -> JXValue {
        return try setProperty(symbol: symbol, context.convey(newValue))
    }
    
    /// Import the properties of the given value into this value.
    public func integrate(_ value: JXValue) throws {
        guard value.isObject else {
            return
        }
        for entry in try value.dictionary {
            try setProperty(entry.key, entry.value)
        }
    }
}

extension JXValue {
    /// The length of the object.
    public var count: Int {
        get throws {
            return try self["length"].int
        }
    }

    /// The value in object at index.
    public subscript(index: Int) -> JXValue {
        get throws {
            let resultRef = try context.trying {
                JSObjectGetPropertyAtIndex(context.contextRef, valueRef, UInt32(index), $0)
            }
            return resultRef.map { JXValue(context: context, valueRef: $0) } ?? JXValue(undefinedIn: context)
        }
    }

    /// Set an element of this array, overwriting any previous element.
    public func setElement(_ element: JXValue, at index: Int) throws {
        try context.trying {
            JSObjectSetPropertyAtIndex(context.contextRef, valueRef, UInt32(index), element.valueRef, $0)
        }
    }

    /// Set an element of this array, overwriting any previous element.
    public func setElement(_ element: Any, at index: Int) throws {
        try setElement(context.convey(element), at: index)
    }

    /// Adds the given object as the final element of this array.
    public func addElement(_ object: JXValue) throws {
        try setElement(object, at: count)
    }

    /// Adds the given object as the final element of this array.
    public func addElement(_ object: Any) throws {
        try addElement(context.convey(object))
    }

    /// Inserts the given object into this array, shifting subsequent elements.
    public func insertElement(_ object: JXValue, at index: Int) throws {
        for i in try (max(1, index)...count).reversed() {
            try setElement(self[i-1], at: i) // Shift all the latter elements up by one
        }
        try setElement(object, at: index) // And fill in the index (JS permits assigning a non-existent index)
    }

    /// Inserts the given object into this array, shifting subsequent elements.
    public func insertElement(_ object: Any, at index: Int) throws {
        try insertElement(context.convey(object), at: index)
    }
}

extension JXValue {
    /// Traverse a '.'-separated key path, returning the object hosting the final property as well as the name of that property.
    public func keyPath(_ keyPath: String, createIntermediates: Bool = false) throws -> (parent: JXValue, property: String) {
        let tokens = keyPath.split(separator: ".")
        guard tokens.count > 1 && !isUndefined else {
            return (self, keyPath)
        }
        
        let property = String(tokens.last!)
        var parent = self
        for i in 0..<(tokens.count - 1) {
            let token = String(tokens[i])
            if parent.hasProperty(token) {
                parent = try parent[token]
            } else if createIntermediates {
                parent = try parent.setProperty(token, context.object())
            } else {
                return (context.undefined(), property)
            }
        }
        return (parent, property)
    }
}

extension JXValue {
    /// Returns the JavaScript string with the given indentation. This should be the same as the output of `JSON.stringify`.
    public func toJSON(indent: Int = 0) throws -> String {
        let str = try context.trying {
            JSValueCreateJSONString(context.contextRef, valueRef, UInt32(indent), $0)
        }
        defer { str.map(JSStringRelease) }
        return str.map(String.init) ?? "null"
    }
}

extension JXValue {
    /// Creates a JavaScript `Proxy` object wrapping this object and intercepting all property getters and setters.
    public func proxy(get getter: @escaping JXFunction, set setter: @escaping JXFunction) throws -> JXValue {
        let ctx = self.context
        let handler = ctx.object()
        try handler.setProperty("get", JXValue(newFunctionIn: ctx, callback: getter))
        try handler.setProperty("set", JXValue(newFunctionIn: ctx, callback: setter))
        let proxy = try context.proxyPrototype.construct(withArguments: [self, handler])
        return proxy
    }
}

extension JXValue {

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - length: Length of new `ArrayBuffer` object.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithLength length: Int, in context: JXContext) throws {
        let obj = try context.arrayBufferPrototype.construct(withArguments: [JXValue(double: Double(length), in: context)])
        self.init(context: context, valueRef: obj.valueRef)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to be used as the backing store of the `ArrayBuffer` object.
    ///   - deallocator: The allocator to use to deallocate the external buffer when the `ArrayBuffer` object is deallocated.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithBytesNoCopy bytes: UnsafeMutableRawBufferPointer, deallocator: @escaping (UnsafeMutableRawBufferPointer) -> Void, in context: JXContext) throws {

        typealias Deallocator = () -> Void

        let info: UnsafeMutablePointer<Deallocator> = .allocate(capacity: 1)
        info.initialize(to: { deallocator(bytes) })

        let value = try context.trying {
            JSObjectMakeArrayBufferWithBytesNoCopy(context.contextRef, bytes.baseAddress, bytes.count, { _, info in
                guard let info = info?.assumingMemoryBound(to: Deallocator.self) else { return }
                info.pointee()
                info.deinitialize(count: 1).deallocate()
            }, info, $0)
        }

        guard let value = value else {
            throw JXError.cannotCreateArrayBuffer()
        }

        self.init(context: context, valueRef: value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to copy.
    ///   - context: The execution context to use.
    public convenience init<S: DataProtocol>(newArrayBufferWithBytes bytes: S, in context: JXContext) throws {

        let buffer: UnsafeMutableRawPointer = .allocate(byteCount: bytes.count, alignment: MemoryLayout<UInt8>.alignment)
        bytes.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count))

        guard let bufValue = try context.trying(function: {
            JSObjectMakeArrayBufferWithBytesNoCopy(context.contextRef, buffer, bytes.count, { buffer, _ in buffer?.deallocate() }, nil, $0)
        }) else {
            throw JXError.cannotCreateArrayBuffer()
        }

        self.init(context: context, valueRef: bufValue)
    }
}

extension JXValue {
    /// Tests whether a JavaScript value’s type is the `ArrayBuffer` type by seeing it if is an instance of ``JXContext//arrayBufferPrototype``.
    ///
    /// See: [MDN ArrayBuffer Documentation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer)
    public var isArrayBuffer: Bool {
        get throws {
            try isInstance(of: context.arrayBufferPrototype)
        }
    }

    /// The length (in bytes) of the `ArrayBuffer`.
    public var byteLength: Int {
        get throws {
            let byteLengthValue = try self["byteLength"]
            let num = try byteLengthValue.double
            if let int = Int(exactly: num) {
                return int
            }
            throw JXError.invalidNumericConversion(byteLengthValue, to: num)
        }
    }

    /// Copy the bytes of `ArrayBuffer`.
    public func copyBytes() throws -> Data? {
        guard try self.isArrayBuffer else { return nil }
        let length = try context.trying {
            JSObjectGetArrayBufferByteLength(context.contextRef, valueRef, $0)
        }
        return try context.trying {
            Data(bytes: JSObjectGetArrayBufferBytesPtr(context.contextRef, valueRef, $0), count: length!)
        }
    }
}

extension String {
    /// Creates a `Swift.String` from a `JXStringRef`
    init(_ str: JXStringRef) {
        self.init(utf16CodeUnits: JSStringGetCharactersPtr(str), count: JSStringGetLength(str))
    }
}

/// A function definition, used when defining callbacks.
public typealias JXFunction = (_ ctx: JXContext, _ obj: JXValue?, _ args: [JXValue]) throws -> JXValue

extension JXValue {
    /// Creates a JavaScript value of the function type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - callback: The callback function.
    /// - Note: This object is callable as a function (due to `JSClassDefinition.callAsFunction`), but the JavaScript runtime doesn't treat it exactly like a function. For example, you cannot call "apply" on it. It could be better to use `JSObjectMakeFunctionWithCallback`, which may act more like a "true" JavaScript function.
    public convenience init(newFunctionIn context: JXContext, callback: @escaping JXFunction) {
        let info: UnsafeMutablePointer<JXFunctionInfo> = .allocate(capacity: 1)
        info.initialize(to: JXFunctionInfo(context: context, callback: callback))

        var def = JSClassDefinition()
        def.finalize = JXFunctionFinalize
        def.callAsConstructor = JXFunctionConstructor
        def.callAsFunction = JXFunctionCallback
        def.hasInstance = JXFunctionInstanceOf

        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }

        // JSObjectMakeFunctionWithCallback(context.context, JSStringRef, JSObjectCallAsFunctionCallback)
        self.init(context: context, valueRef: JSObjectMake(context.contextRef, _class, info))
    }

    // Await the return of this value as a JavaScript `Promise`.
    public func awaitPromise(priority: TaskPriority = .medium) async throws -> JXValue {
        guard try isPromise else {
            throw JXError.valueNotPromise(self)
        }
        let then = try self["then"]
        guard then.isFunction else {
            throw JXError(message: "The Promise does not have a 'then' function")
        }

        return try await withCheckedThrowingContinuation { [weak context] c in
            do {
                guard let context = context else {
                    return c.resume(throwing: JXError(message: "The JXContext was deallocated during the 'awaitPromise(...) async' call"))
                }

                let fulfilled = JXValue(newFunctionIn: context) { jxc, this, args in
                    c.resume(returning: args.first ?? JXValue(undefinedIn: jxc))
                    return JXValue(undefinedIn: jxc)
                }

                let rejected = JXValue(newFunctionIn: context) { jxc, this, arg in
                    let error: JXError
                    if let jsError = arg.first {
                        error = JXError(jsError: jsError)
                    } else {
                        error = JXError(message: "The returned Promise was rejected")
                    }
                    c.resume(throwing: error)
                    return JXValue(undefinedIn: jxc)
                }

                let presult = try then.call(withArguments: [fulfilled, rejected], this: self)

                // then() should return a promise as well
                if try !presult.isPromise {
                    // We can't throw here because it could complete the promise multiple times
                    throw JXError.valueNotPromise(presult)
                }
            } catch {
                return c.resume(throwing: error)
            }
        }
    }

    public static func createPromise(in context: JXContext) throws -> JXPromise {
        var resolveRef: JSObjectRef?
        var rejectRef: JSObjectRef?

        // https://github.com/WebKit/WebKit/blob/b46f54e33e5cb968174e4d20392513e14d04839f/Source/JavaScriptCore/API/JSValue.mm#L158
        guard let promise = try context.trying(function: {
            JSObjectMakeDeferredPromise(context.contextRef, &resolveRef, &rejectRef, $0)
        }) else {
            throw JXError.cannotCreatePromise()
        }

        guard let resolve = resolveRef else {
            throw JXError.cannotCreatePromise()
        }
        let resolveFunction = JXValue(context: context, valueRef: resolve)

        guard let reject = rejectRef else {
            throw JXError.cannotCreatePromise()
        }
        let rejectFunction = JXValue(context: context, valueRef: reject)

        return (JXValue(context: context, valueRef: promise), resolveFunction, rejectFunction)
    }

    /// Creates a promise and executes it immediately
    /// - Parameters:
    ///   - context: The context to use for creation.
    ///   - executor: The executor callback.
    public convenience init(newPromiseIn context: JXContext, executor: (JXContext, _ resolve: JXValue, _ reject: JXValue) throws -> ()) throws {
        let (promise, resolve, reject) = try Self.createPromise(in: context)
        try executor(context, resolve, reject)
        self.init(context: context, value: promise)
    }

    public convenience init(newPromiseResolvedWithResult result: JXValue, in context: JXContext) throws {
        try self.init(newPromiseIn: context) { jxc, resolve, reject in
            try resolve.call(withArguments: [result])
        }
    }

    public convenience init(newPromiseRejectedWithResult reason: JXValue, in context: JXContext) throws {
        try self.init(newPromiseIn: context) { jxc, resolve, reject in
            try reject.call(withArguments: [reason])
        }
    }
}

private struct JXFunctionInfo {
    unowned let context: JXContext
    let callback: JXFunction
}

public typealias JXPromise = (promise: JXValue, resolveFunction: JXValue, rejectFunction: JXValue)

private func JXFunctionFinalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

private func JXFunctionConstructor(_ jxc: JXContextRef?, _ object: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSObjectRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let context = info.pointee.context

    do {
        let arguments = (0..<argumentCount).map { JXValue(context: context, valueRef: arguments![$0]!) }
        let result = try info.pointee.callback(context, nil, arguments)

        let prototype = JSObjectGetPrototype(context.contextRef, object)
        JSObjectSetPrototype(context.contextRef, result.valueRef, prototype)

        return result.valueRef
    } catch {
        let error = try? JXValue(newErrorFromCause: error, in: context)
        exception?.pointee = error?.valueRef
        return nil
    }
}

private func JXFunctionCallback(_ jxc: JXContextRef?, _ object: JSObjectRef?, _ this: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let context = info.pointee.context

    do {
        let this = this.map { JXValue(context: context, valueRef: $0) }
        let arguments = (0..<argumentCount).map { JXValue(context: context, valueRef: arguments![$0]!) }
        let result = try info.pointee.callback(context, this, arguments)
        return result.valueRef
    } catch {
        let error = try? JXValue(newErrorFromCause: error, in: context)
        exception?.pointee = error?.valueRef
        return nil
    }
}

private func JXFunctionInstanceOf(_ jxc: JXContextRef?, _ constructor: JSObjectRef?, _ possibleInstance: JSValueRef?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> Bool {
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JXFunctionInfo.self)
    let context = info.pointee.context
    let pt1 = JSObjectGetPrototype(context.contextRef, constructor)
    let pt2 = JSObjectGetPrototype(context.contextRef, possibleInstance)
    return JSValueIsStrictEqual(context.contextRef, pt1, pt2)
}

extension JXValue {
    /// A peer is an instance of `AnyObject` that is created from ``JXContext/object(peer:)`` with a peer argument.
    ///
    /// The peer cannot be changed once an object has been initialized with it.
    public var peer: AnyObject? {
        get {
            guard isObject, !isFunction, let ptr = JSObjectGetPrivate(valueRef) else {
                return nil
            }
            return ptr.assumingMemoryBound(to: AnyObject?.self).pointee
        }
    }
    
    /// The cause passed to ``JXContext/error(_:)``.
    public var cause: Error? {
        get {
            guard let causeValue = try? self["cause"], let errorPeer = causeValue.peer as? JXErrorPeer else {
                return nil
            }
            return errorPeer.error
        }
    }
}

