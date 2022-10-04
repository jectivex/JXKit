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

/// A JavaScript object.
///
/// This wraps a `JSObjectRef`, and is the equivalent of `JavaScriptCore.JSValue`
public class JXValue {
    public let ctx: JXContext
    @usableFromInline let value: JXValueRef

    public convenience init(ctx: JXContext, value: JXValue) {
        self.init(ctx: ctx, valueRef: value.value)
    }

    @usableFromInline internal init(ctx: JXContext, valueRef: JXValueRef) {
        JSValueProtect(ctx.context, valueRef)
        self.ctx = ctx
        self.value = valueRef
    }

    deinit {
        JSValueUnprotect(ctx.context, value)
    }
}

/// An error thrown from JavaScript evaluation.
public class JXError : JXValue, Error, @unchecked Sendable {
}

extension JXValue {
    @usableFromInline static let rfc3339: DateFormatter = {
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
    @usableFromInline internal convenience init(undefinedIn ctx: JXContext) {
        self.init(ctx: ctx, valueRef: JSValueMakeUndefined(ctx.context))
    }

    /// Creates a JavaScript value of the `null` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(nullIn ctx: JXContext) {
        self.init(ctx: ctx, valueRef: JSValueMakeNull(ctx.context))
    }

    /// Creates a JavaScript `Boolean` value.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(bool value: Bool, in ctx: JXContext) {
        self.init(ctx: ctx, valueRef: JSValueMakeBoolean(ctx.context, value))
    }

    /// Creates a JavaScript value of the `Number` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(double value: Double, in ctx: JXContext) {
        self.init(ctx: ctx, valueRef: JSValueMakeNumber(ctx.context, value))
    }

    /// Creates a JavaScript value of the `String` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(string value: String, in ctx: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(ctx: ctx, valueRef: JSValueMakeString(ctx.context, value))
    }

    /// Creates a JavaScript value of the `Symbol` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(symbol value: String, in ctx: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(ctx: ctx, valueRef: JSValueMakeSymbol(ctx.context, value))
    }

    /// Creates a JavaScript value of the parsed `JSON`.
    ///
    /// - Parameters:
    ///   - value: The JSON value to parse
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init?(json value: String, in ctx: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        guard let json = JSValueMakeFromJSONString(ctx.context, value) else {
            return nil // we just return nil since there is no error parameter
        }
        self.init(ctx: ctx, valueRef: json)
    }

    /// Creates a JavaScript `Date` object, as if by invoking the built-in `JSObjectMakeDate` constructor.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(date value: Date, in ctx: JXContext) throws {
        let arguments = [JXValue(string: JXValue.rfc3339.string(from: value), in: ctx)]
        let object = try ctx.trying {
            JSObjectMakeDate(ctx.context, 1, arguments.map { $0.value }, $0)
        }
        self.init(ctx: ctx, valueRef: object!)
    }

    /// Creates a JavaScript `RegExp` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - pattern: The pattern of regular expression.
    ///   - flags: The flags pass to the constructor.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(newRegularExpressionFromPattern pattern: String, flags: String, in ctx: JXContext) throws {
        let arguments = [JXValue(string: pattern, in: ctx), JXValue(string: flags, in: ctx)]
        let object = try ctx.trying {
            JSObjectMakeRegExp(ctx.context, 2, arguments.map { $0.value }, $0)
        }
        self.init(ctx: ctx, valueRef: object!)
    }

    /// Creates a JavaScript `Error` object, as if by invoking the built-in `Error` constructor.
    ///
    /// - Parameters:
    ///   - message: The error message.
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(newErrorFromMessage message: String, in ctx: JXContext) throws {
        let arguments = [JXValue(string: message, in: ctx)]
        let object = try ctx.trying {
            JSObjectMakeError(ctx.context, arguments.count, arguments.map { $0.value }, $0)
        }
        self.init(ctx: ctx, valueRef: object!)
    }

    /// Creates a JavaScript `Object`.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(newObjectIn ctx: JXContext) {
        self.init(ctx: ctx, valueRef: JSObjectMake(ctx.context, nil, nil))
    }

    /// Creates a JavaScript `Object` with prototype.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - prototype: The prototype to be used.
    @usableFromInline internal convenience init(newObjectIn ctx: JXContext, prototype: JXValue) throws {
        let obj = try ctx.objectPrototype.invokeMethod("create", withArguments: [prototype])
        self.init(ctx: ctx, valueRef: obj.value)
    }

    /// Creates a JavaScript `Array` object.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @usableFromInline internal convenience init(newArrayIn ctx: JXContext, values: [JXValue]? = nil) throws {
        let array = try ctx.trying {
            JSObjectMakeArray(ctx.context, 0, nil, $0)
        }
        self.init(ctx: ctx, valueRef: array!)
        if let values = values {
            for (index, element) in values.enumerated() {
                try self.setElement(element, at: UInt32(index))
            }
        }
    }
}

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
        if (try? self.isError) == true {
            return (try? self.stringValue) ?? "error"
        }

        // better to not invoke a method from `description`
        //return try! self.invokeMethod("toString", withArguments: []).stringValue!
        
        return "[JXValue]"
    }
}

extension JXValue {
    /// Object’s prototype.
    @inlinable public var prototype: JXValue {
        get {
            let prototype = JSObjectGetPrototype(ctx.context, value)
            return prototype.map { JXValue(ctx: ctx, valueRef: $0) } ?? JXValue(undefinedIn: ctx)
        }
        set {
            JSObjectSetPrototype(ctx.context, value, newValue.value)
        }
    }
}

extension JXValue {

    /// Tests whether a JavaScript value’s type is the undefined type.
    @inlinable public var isUndefined: Bool {
        JSValueIsUndefined(ctx.context, value)
    }

    /// Tests whether a JavaScript value’s type is the null type.
    @inlinable public var isNull: Bool {
        JSValueIsNull(ctx.context, value)
    }

    /// Tests whether a JavaScript value is Boolean.
    @inlinable public var isBoolean: Bool {
        JSValueIsBoolean(ctx.context, value)
    }

    /// Tests whether a JavaScript value’s type is the number type.
    @inlinable public var isNumber: Bool {
        JSValueIsNumber(ctx.context, value)
    }

    /// Tests whether a JavaScript value’s type is the string type.
    @inlinable public var isString: Bool {
        JSValueIsString(ctx.context, value)
    }

    /// Tests whether a JavaScript value’s type is the object type.
    @inlinable public var isObject: Bool {
        JSValueIsObject(ctx.context, value)
    }

    /// Tests whether an object can be called as a constructor.
    @inlinable public var isConstructor: Bool {
        isObject && JSObjectIsConstructor(ctx.context, value)
    }

    /// Tests whether an object can be called as a function.
    @inlinable public var isFunction: Bool {
        isObject && JSObjectIsFunction(ctx.context, value)
    }

    /// Tests whether an object can be called as a function.
    @inlinable public var isSymbol: Bool {
        JSValueIsSymbol(ctx.context, value)
    }

    /// Tests whether a JavaScript value’s type is the date type.
    @inlinable public var isDate: Bool {
        get throws {
            try isInstance(of: ctx.datePrototype)
        }
    }

    @inlinable public var isPromise: Bool {
        get throws {
            try isInstance(of: ctx.promisePrototype)
        }
    }

    /// Tests whether a JavaScript value’s type is the array type.
    @inlinable public var isArray: Bool {
        JSValueIsArray(ctx.context, value)
    }

    /// Tests whether a JavaScript value’s type is the error type.
    @inlinable public var isError: Bool {
        get throws {
            try isInstance(of: ctx.errorPrototype)
        }
    }
}

extension JXValue {

    /// Whether or not the given object is frozen.
    ///
    /// An object is frozen if and only if it is not extensible, all its properties are non-configurable, and all its data properties (that is, properties which are not accessor properties with getter or setter components) are non-writable.
    @inlinable public var isFrozen: Bool {
        get throws {
            try ctx.objectPrototype.invokeMethod("isFrozen", withArguments: [self]).booleanValue
        }
    }

    /// The Object.isExtensible() method determines if an object is extensible (whether it can have new properties added to it).
    ///
    /// Objects are extensible by default: they can have new properties added to them, and their `Prototype` can be re-assigned. An object can be marked as non-extensible using one of ``preventExtensions()`, `seal()`, `freeze()`, or `Reflect.preventExtensions()`.
    @inlinable public var isExtensible: Bool {
        get throws {
            try ctx.objectPrototype.invokeMethod("isExtensible", withArguments: [self]).booleanValue
        }
    }

    /// The Object.isSealed() method determines if an object is sealed.
    ///
    /// Returns true if the object is sealed, otherwise false. An object is sealed if it is not extensible and if all its properties are non-configurable and therefore not removable (but not necessarily non-writable).
    @inlinable public var isSealed: Bool {
        get throws {
            try ctx.objectPrototype.invokeMethod("isSealed", withArguments: [self]).booleanValue
        }
    }

    /// The Object.freeze() method freezes an object. Freezing an object prevents extensions and makes existing properties non-writable and non-configurable. A frozen object can no longer be changed: new properties cannot be added, existing properties cannot be removed, their enumerability, configurability, writability, or value cannot be changed, and the object's prototype cannot be re-assigned. freeze() returns the same object that was passed in.
    ///
    /// Freezing an object is equivalent to preventing extensions and then changing all existing properties' descriptors' configurable to false — and for data properties, writable to false as well. Nothing can be added to or removed from the properties set of a frozen object. Any attempt to do so will fail, either silently or by throwing a TypeError exception (most commonly, but not exclusively, when in strict mode).
    ///
    /// For data properties of a frozen object, their values cannot be changed since the writable and configurable attributes are set to false. Accessor properties (getters and setters) work the same — the property value returned by the getter may still change, and the setter can still be called without throwing errors when setting the property. Note that values that are objects can still be modified, unless they are also frozen. As an object, an array can be frozen; after doing so, its elements cannot be altered and no elements can be added to or removed from the array.
    @inlinable public func freeze() throws {
        try ctx.objectPrototype.invokeMethod("freeze", withArguments: [self])
    }

    /// The Object.preventExtensions() method prevents new properties from ever being added to an object (i.e. prevents future extensions to the object). It also prevents the object's prototype from being re-assigned.
    /// An object is extensible if new properties can be added to it. Object.preventExtensions() marks an object as no longer extensible, so that it will never have properties beyond the ones it had at the time it was marked as non-extensible. Note that the properties of a non-extensible object, in general, may still be deleted. Attempting to add new properties to a non-extensible object will fail, either silently or, in strict mode, throwing a TypeError.
    ///
    /// Unlike Object.seal() and Object.freeze(), Object.preventExtensions() invokes an intrinsic JavaScript behavior and cannot be replaced with a composition of several other operations. It also has its Reflect counterpart (which only exists for intrinsic operations), Reflect.preventExtensions().
    ///
    /// Object.preventExtensions() only prevents addition of own properties. Properties can still be added to the object prototype.
    ///
    /// This method makes the [[Prototype]] of the target immutable; any [[Prototype]] re-assignment will throw a TypeError. This behavior is specific to the internal [[Prototype]] property; other properties of the target object will remain mutable.
    ///
    /// There is no way to make an object extensible again once it has been made non-extensible.
    @inlinable public func preventExtensions() throws {
        try ctx.objectPrototype.invokeMethod("preventExtensions", withArguments: [self])
    }

    /// The Object.seal() method seals an object. Sealing an object prevents extensions and makes existing properties non-configurable. A sealed object has a fixed set of properties: new properties cannot be added, existing properties cannot be removed, their enumerability and configurability cannot be changed, and its prototype cannot be re-assigned. Values of existing properties can still be changed as long as they are writable. seal() returns the same object that was passed in.
    @inlinable public func seal() throws {
        try ctx.objectPrototype.invokeMethod("seal", withArguments: [self])
    }
}

extension JXValue {

    /// Returns the JavaScript boolean value.
    @inlinable public var booleanValue: Bool {
        JSValueToBoolean(ctx.context, value)
    }

    /// Returns the JavaScript number value.
    @inlinable public var numberValue: Double {
        get throws {
            //if !JSValueIsNumber(ctx.context, value) { return nil }
            try ctx.trying {
                JSValueToNumber(ctx.context, value, $0)
            }
        }
    }

    /// Returns the JavaScript string value.
    @inlinable public var stringValue: String {
        get throws {
            let str = try ctx.trying {
                JSValueToStringCopy(ctx.context, value, $0)
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
        let result = try ctx.trying {
            JSObjectCallAsFunction(ctx.context, value, this?.value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, $0)
        }
        return result.map {
            let v = JXValue(ctx: ctx, valueRef: $0)
            return v
        } ?? JXValue(undefinedIn: ctx)
    }

    /// Calls an object as a constructor.
    ///a
    /// - Parameters:
    ///   - arguments: The arguments pass to the function.
    ///
    /// - Returns: The object that results from calling object as a constructor.
    @inlinable public func construct(withArguments arguments: [JXValue]) throws -> JXValue {
        let result = try ctx.trying {
            JSObjectCallAsConstructor(ctx.context, value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, $0)
        }
        return result.map { JXValue(ctx: ctx, valueRef: $0) } ?? JXValue(undefinedIn: ctx)
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

extension JXValue {

    /// Tests whether two JavaScript values are strict equal, as compared by the JS `===` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    ///
    /// - Returns: true if the two values are strict equal; otherwise false.
    @inlinable public func isEqual(to other: JXValue) -> Bool {
        JSValueIsStrictEqual(ctx.context, value, other.value)
    }

    /// Tests whether two JavaScript values are equal, as compared by the JS `==` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    ///
    /// - Returns: true if the two values are equal; false if they are not equal or an exception is thrown.
    @inlinable public func isEqualWithTypeCoercion(to other: JXValue) throws -> Bool {
        try ctx.trying {
            JSValueIsEqual(ctx.context, value, other.value, $0)
        }
    }

    /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the `isInstance(of:)` operator.
    ///
    /// - Parameters:
    ///   - other: The constructor to test against.
    ///
    /// - Returns: true if the value is an object constructed by constructor, as compared by the JS isInstance(of:) operator; otherwise false.
    @inlinable public func isInstance(of other: JXValue) throws -> Bool {
        try ctx.trying {
            JSValueIsInstanceOfConstructor(ctx.context, value, other.value, $0)
        }
    }
}

extension JXValue {

    /// Get the names of an object’s enumerable properties.
    @inlinable public var properties: [String] {
        if !isObject { return [] }

        let _list = JSObjectCopyPropertyNames(ctx.context, value)
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
        return JSObjectHasProperty(ctx.context, value, property)
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
        return try ctx.trying {
            JSObjectDeleteProperty(ctx.context, value, property, $0)
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
        return try ctx.trying {
            JSObjectHasPropertyForKey(ctx.context, value, property.value, $0)
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
        try ctx.trying {
            JSObjectDeletePropertyForKey(ctx.context, value, property.value, $0)
        }
    }

    /// The value of the property.
    @inlinable public subscript(propertyName: String) -> JXValue {
        get throws {
            if !isObject { return ctx.undefined() }
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            let result = try ctx.trying {
                JSObjectGetProperty(ctx.context, value, property, $0)
            }
            return result.map { JXValue(ctx: ctx, valueRef: $0) } ?? JXValue(undefinedIn: ctx)
        }
    }

    /// The value of the property for the given symbol.
    @inlinable public subscript(symbol symbol: JXValue) -> JXValue {
        get throws {
            if !isObject {
                throw JXErrors.propertyAccessNonObject
            }
            if !symbol.isSymbol {
                throw JXErrors.keyNotSymbol
            }
            let result = try ctx.trying {
                JSObjectGetPropertyForKey(ctx.context, value, symbol.value, $0)
            }
            return result.map { JXValue(ctx: ctx, valueRef: $0) } ?? JXValue(undefinedIn: ctx)
        }
    }

    /// Sets the property of the object to the given value
    /// - Parameters:
    ///   - key: the key name to set
    ///   - newValue: the value of the property
    /// - Returns: the value itself
    @discardableResult @inlinable public func setProperty(_ key: String, _ newValue: JXValue) throws -> JXValue {
        if !isObject {
            throw JXErrors.propertyAccessNonObject
        }

        let property = JSStringCreateWithUTF8CString(key)
        defer { JSStringRelease(property) }
        try ctx.trying {
            JSObjectSetProperty(ctx.context, value, property, newValue.value, 0, $0)
        }
        return newValue
    }

    /// Sets the property specified by the symbol key.
    /// - Parameters:
    ///   - key: the name of the symbol to use
    ///   - newValue: the value to set the property
    /// - Returns:
    @discardableResult @inlinable public func setProperty(symbol: JXValue, _ newValue: JXValue) throws -> JXValue {
        if !isObject {
            throw JXErrors.propertyAccessNonObject
        }

        try ctx.trying {
            JSObjectSetPropertyForKey(ctx.context, value, symbol.value, newValue.value, 0, $0)
        }
        return newValue
    }
}

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
            let result = try ctx.trying {
                JSObjectGetPropertyAtIndex(ctx.context, value, index, $0)
            }
            return result.map { JXValue(ctx: ctx, valueRef: $0) } ?? JXValue(undefinedIn: ctx)
        }
    }

    @inlinable public func setElement(_ element: JXValue, at index: UInt32) throws {
        try ctx.trying {
            JSObjectSetPropertyAtIndex(ctx.context, value, index, element.value, $0)
        }
    }
}

extension JXValue {
    /// Returns the JavaScript string with the given indentation. This should be the same as the output of `JSON.stringify`.
    @inlinable public func toJSON(indent: UInt32 = 0) throws -> String {
        let str = try ctx.trying {
            JSValueCreateJSONString(ctx.context, value, indent, $0)
        }
        defer { str.map(JSStringRelease) }
        return str.map(String.init) ?? "null"
    }
}

extension JXValue {

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - length: Length of new `ArrayBuffer` object.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithLength length: Int, in ctx: JXContext) throws {
        let obj = try ctx.arrayBufferPrototype.construct(withArguments: [JXValue(double: Double(length), in: ctx)])
        self.init(ctx: ctx, valueRef: obj.value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to be used as the backing store of the `ArrayBuffer` object.
    ///   - deallocator: The allocator to use to deallocate the external buffer when the `ArrayBuffer` object is deallocated.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithBytesNoCopy bytes: UnsafeMutableRawBufferPointer, deallocator: @escaping (UnsafeMutableRawBufferPointer) -> Void, in ctx: JXContext) throws {

        typealias Deallocator = () -> Void

        let info: UnsafeMutablePointer<Deallocator> = .allocate(capacity: 1)
        info.initialize(to: { deallocator(bytes) })

        let value = try ctx.trying {
            JSObjectMakeArrayBufferWithBytesNoCopy(ctx.context, bytes.baseAddress, bytes.count, { _, info in
                guard let info = info?.assumingMemoryBound(to: Deallocator.self) else { return }
                info.pointee()
                info.deinitialize(count: 1).deallocate()
            }, info, $0)
        }

        guard let value = value else {
            throw JXErrors.cannotCreateArrayBuffer
        }

        self.init(ctx: ctx, valueRef: value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to copy.
    ///   - context: The execution context to use.
    public convenience init<S: DataProtocol>(newArrayBufferWithBytes bytes: S, in ctx: JXContext) throws {

        let buffer: UnsafeMutableRawPointer = .allocate(byteCount: bytes.count, alignment: MemoryLayout<UInt8>.alignment)
        bytes.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count))

        guard let bufValue = try ctx.trying(function: {
            JSObjectMakeArrayBufferWithBytesNoCopy(ctx.context, buffer, bytes.count, { buffer, _ in buffer?.deallocate() }, nil, $0)
        }) else {
            throw JXErrors.cannotCreateArrayBuffer
        }

        self.init(ctx: ctx, valueRef: bufValue)
    }
}

extension JXValue {
    /// Tests whether a JavaScript value’s type is the `ArrayBuffer` type.
    public var isArrayBuffer: Bool {
        get throws {
            try isInstance(of: ctx.arrayBufferPrototype)
        }
    }

    /// The length (in bytes) of the `ArrayBuffer`.
    public var byteLength: Int {
        get throws {
            let num = try self["byteLength"].numberValue
            if let int = Int(exactly: num) {
                return int
            }
            throw JXErrors.invalidNumericConversion(num)
        }
    }

    /// Copy the bytes of `ArrayBuffer`.
    public func copyBytes() throws -> Data? {
        guard try self.isArrayBuffer else { return nil }
        let length = try ctx.trying {
            JSObjectGetArrayBufferByteLength(ctx.context, value, $0)
        }
        return try ctx.trying {
            Data(bytes: JSObjectGetArrayBufferBytesPtr(ctx.context, value, $0), count: length!)
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
public typealias JXFunction = (JXContext, JXValue?, [JXValue]) throws -> JXValue


extension JXValue {
    /// Creates a JavaScript value of the function type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - callback: The callback function.
    ///
    /// - Note: This object is callable as a function (due to `JSClassDefinition.callAsFunction`), but the JavaScript runtime doesn't treat it exactly like a function. For example, you cannot call "apply" on it. It could be better to use `JSObjectMakeFunctionWithCallback`, which may act more like a "true" JavaScript function.
    public convenience init(newFunctionIn ctx: JXContext, callback: @escaping JXFunction) {
        let info: UnsafeMutablePointer<JXFunctionInfo> = .allocate(capacity: 1)
        info.initialize(to: JXFunctionInfo(context: ctx, callback: callback))

        var def = JSClassDefinition()
        def.finalize = JXFunctionFinalize
        def.callAsConstructor = JXFunctionConstructor
        def.callAsFunction = JXFunctionCallback
        def.hasInstance = JXFunctionInstanceOf

        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }

        // JSObjectMakeFunctionWithCallback(ctx.context, JSStringRef, JSObjectCallAsFunctionCallback)
        self.init(ctx: ctx, valueRef: JSObjectMake(ctx.context, _class, info))
    }

    public static func createPromise(in ctx: JXContext) throws -> JXPromise {
        var resolveRef: JSObjectRef?
        var rejectRef: JSObjectRef?

        // https://github.com/WebKit/WebKit/blob/b46f54e33e5cb968174e4d20392513e14d04839f/Source/JavaScriptCore/API/JSValue.mm#L158
        guard let promise = try ctx.trying(function: {
            JSObjectMakeDeferredPromise(ctx.context, &resolveRef, &rejectRef, $0)
        }) else {
            throw JXErrors.cannotCreatePromise
        }

        guard let resolve = resolveRef else {
            throw JXErrors.cannotCreatePromise
        }
        let resolveFunction = JXValue(ctx: ctx, valueRef: resolve)

        guard let reject = rejectRef else {
            throw JXErrors.cannotCreatePromise
        }
        let rejectFunction = JXValue(ctx: ctx, valueRef: reject)

        return (JXValue(ctx: ctx, valueRef: promise), resolveFunction, rejectFunction)
    }

    /// Creates a promise and executes it immediately
    /// - Parameters:
    ///   - ctx: the context to use for creation
    ///   - executor: the executor callback
    public convenience init(newPromiseIn ctx: JXContext, executor: (JXContext, _ resolve: JXValue, _ reject: JXValue) throws -> ()) throws {
        let (promise, resolve, reject) = try Self.createPromise(in: ctx)
        try executor(ctx, resolve, reject)
        self.init(ctx: ctx, value: promise)
    }

    public convenience init(newPromiseResolvedWithResult result: JXValue, in ctx: JXContext) throws {
        try self.init(newPromiseIn: ctx) { jxc, resolve, reject in
            try resolve.call(withArguments: [result])
        }
    }

    public convenience init(newPromiseRejectedWithResult reason: JXValue, in ctx: JXContext) throws {
        try self.init(newPromiseIn: ctx) { jxc, resolve, reject in
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
    let ctx = info.pointee.context

    do {
        let arguments = (0..<argumentCount).map { JXValue(ctx: ctx, valueRef: arguments![$0]!) }
        let result = try info.pointee.callback(ctx, nil, arguments)

        let prototype = JSObjectGetPrototype(ctx.context, object)
        JSObjectSetPrototype(ctx.context, result.value, prototype)

        return result.value
    } catch let error {
        let error = (error as? JXValueError)?.value ?? (try? JXValue(newErrorFromMessage: "\(error)", in: ctx))
        exception?.pointee = error?.value
        return nil
    }
}

private func JXFunctionCallback(_ jxc: JXContextRef?, _ object: JSObjectRef?, _ this: JSObjectRef?, _ argumentCount: Int, _ arguments: UnsafePointer<JSValueRef?>?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JXFunctionInfo.self)
    let ctx = info.pointee.context

    do {
        let this = this.map { JXValue(ctx: ctx, valueRef: $0) }
        let arguments = (0..<argumentCount).map { JXValue(ctx: ctx, valueRef: arguments![$0]!) }
        let result = try info.pointee.callback(ctx, this, arguments)
        return result.value
    } catch let error {
        let error = (error as? JXValueError)?.value ?? (try? JXValue(newErrorFromMessage: "\(error)", in: ctx))
        exception?.pointee = error?.value
        return nil
    }
}

private func JXFunctionInstanceOf(_ jxc: JXContextRef?, _ constructor: JSObjectRef?, _ possibleInstance: JSValueRef?, _ exception: UnsafeMutablePointer<JSValueRef?>?) -> Bool {
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JXFunctionInfo.self)
    let ctx = info.pointee.context
    let pt1 = JSObjectGetPrototype(ctx.context, constructor)
    let pt2 = JSObjectGetPrototype(ctx.context, possibleInstance)
    return JSValueIsStrictEqual(ctx.context, pt1, pt2)
}


extension JXValue {

    /// Defines a property on the JavaScript object value or modifies a property’s definition.
    ///
    /// - Parameters:
    ///   - property: The property's key, which can either be a string or a symbol.
    ///   - descriptor: The descriptor object.
    ///
    /// - Returns: the key for the property that was defined
    @inlinable public func defineProperty(_ property: JXValue, _ descriptor: JXProperty) throws {
        let desc = JXValue(newObjectIn: ctx)

        if let value = descriptor.value {
            try desc.setProperty("value", value)
        }

        if let writable = descriptor.writable {
            try desc.setProperty("writable", JXValue(bool: writable, in: ctx))
        }

        if let getter = descriptor._getter {
            try desc.setProperty("get", getter)
        } else if let getter = descriptor.getter {
            try desc.setProperty("get", JXValue(newFunctionIn: ctx) { _, this, _ in try getter(this!) })
        }

        if let setter = descriptor._setter {
            try desc.setProperty("set", setter)
        } else if let setter = descriptor.setter {
            try desc.setProperty("set", JXValue(newFunctionIn: ctx) { context, this, arguments in
                try setter(this!, arguments[0])
                return JXValue(undefinedIn: context)
            })
        }
        
        if let configurable = descriptor.configurable {
            try desc.setProperty("configurable", JXValue(bool: configurable, in: ctx))
        }

        if let enumerable = descriptor.enumerable {
            try desc.setProperty("enumerable", JXValue(bool: enumerable, in: ctx))
        }

        try ctx.objectPrototype.invokeMethod("defineProperty", withArguments: [self, property, desc])
    }

    public func propertyDescriptor(_ property: JXValue) throws -> JXValue {
        try ctx.objectPrototype.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, property])
    }
}


// MARK: Properties

/// A descriptor for property’s definition
public struct JXProperty {
    public let value: JXValue?
    public let writable: Bool?
    @usableFromInline internal let _getter: JXValue?
    @usableFromInline internal let _setter: JXValue?
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
    /// An symbol type
    case symbol
}

extension JXValue {
    @inlinable public var type: JXType? {
        if isUndefined { return nil }
        if isNull { return nil }
        if isBoolean { return .boolean }
        if isNumber { return .number }
        if isSymbol { return .symbol }
        if (try? isDate) == true { return .date }
        if isString { return .string }
        if isArray { return .array }
        if isObject { return .object }
        return nil
    }
}

/// MARK: Peers

extension JXValue {
    /// A peer is an instance of `AnyObject` that is created from ``JXContext.object`` with a peer argument.
    ///
    /// The peer cannot be changed once an object has been initialized with it.
    public var peer: AnyObject? {
        get {
            guard isObject,
                  !isFunction,
                  let ptr = JSObjectGetPrivate(value) else {
                return nil
            }
            return ptr.assumingMemoryBound(to: AnyObject?.self).pointee
        }
    }
}

