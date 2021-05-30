//
//  JavaScript execution context & value types.
//
//  Adapted from https://github.com/SusanDoggie/SwiftJS :
//  Copyright (c) 2015 - 2021 Susan Cheng. All rights reserved.
//

import Foundation

// The following aliases can be helpful when migrating from JavaScriptCore to JXKit:
//
// import JXKit
// @available(*, deprecated, renamed: "JXContext")
// public typealias JSContext = JXContext
// @available(*, deprecated, renamed: "JXValue")
// public typealias JSValue = JXValue

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

// MARK: JXVirtualMachine

/// A JavaScript virtual machine.
///
/// This wraps a `JSContextGroupRef`, and is the equivalent of `JavaScriptCore.JSVirtualMachine`
open class JXVirtualMachine {
    @usableFromInline let group: JSContextGroupRef

    @inlinable public init() {
        self.group = JSContextGroupCreate()
    }

    @inlinable deinit {
        JSContextGroupRelease(group)
    }
}

// MARK: JXContext

/// A JavaScript execution context.
///
/// This wraps a `JSGlobalContextRef`, and is the equivalent of `JavaScriptCore.JSContext`
open class JXContext {
    public let virtualMachine: JXVirtualMachine
    public let context: JSGlobalContextRef
    open var currentError: JXValue?
    open var exceptionHandler: ((JXContext?, JXValue?) -> Void)?

    @inlinable public init() {
        self.virtualMachine = JXVirtualMachine()
        self.context = JSGlobalContextCreateInGroup(virtualMachine.group, nil)
    }
    
    @inlinable public init(virtualMachine: JXVirtualMachine) {
        self.virtualMachine = virtualMachine
        self.context = JSGlobalContextCreateInGroup(virtualMachine.group, nil)
    }

    @inlinable deinit {
        JSGlobalContextRelease(context)
    }

}

// MARK: JXValue

/// A JavaScript object.
///
/// This wraps a `JSObjectRef`, and is the equivalent of `JavaScriptCore.JSValue`
open class JXValue {
    public let env: JXContext
    public let value: JSValueRef

    @inlinable public init(env: JXContext, value: JSValueRef) {
        JSValueProtect(env.context, value)
        self.env = env
        self.value = value
    }

    @inlinable deinit {
        JSValueUnprotect(env.context, value)
    }
}

extension JXContext {
    
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
}

extension JXContext {
    /// Performs a JavaScript garbage collection.
    ///
    /// During JavaScript execution, you are not required to call this function; the JavaScript engine will garbage collect as needed.
    /// JavaScript values created within a context group are automatically destroyed when the last reference to the context group is released.
    open func garbageCollect() { JSGarbageCollect(context) }

    /// Returns the global context reference for this context
    public var jsGlobalContextRef: JSGlobalContextRef { context }
}

extension JXContext {
    /// The global object.
    open var global: JXValue {
        return JXValue(env: self, value: JSContextGetGlobalObject(context))
    }

    /// Tests whether global has a given property.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///   
    /// - Returns: true if the object has `property`, otherwise false.
    @inlinable open func hasProperty(_ property: String) -> Bool {
        return global.hasProperty(property)
    }
    
    /// Deletes a property from global.
    /// 
    /// - Parameters:
    ///   - property: The property's name.
    ///   
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @discardableResult
    @inlinable open func removeProperty(_ property: String) -> Bool {
        return global.removeProperty(property)
    }

    /// Returns the global property at the given subscript
    @inlinable open subscript(property: String) -> JXValue {
        get { global[property] }
        set { global[property] = newValue }
    }

    /// Get the names of global’s enumerable properties
    @inlinable open var properties: [String] {
        return global.properties
    }
}

extension JXContext {
    
    /// Checks for syntax errors in a string of JavaScript.
    ///
    /// - Parameters:
    ///   - script: The script to check for syntax errors.
    ///   - sourceURL: A URL for the script's source file. This is only used when reporting exceptions. Pass `nil` to omit source file information in exceptions.
    ///   - startingLineNumber: An integer value specifying the script's starting line number in the file located at sourceURL. This is only used when reporting exceptions.
    ///   
    /// - Returns: true if the script is syntactically correct; otherwise false.
    @inlinable open func checkScriptSyntax(_ script: String, sourceURL: URL? = nil, startingLineNumber: Int = 0) -> Bool {
        
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
    @discardableResult @inlinable open func evaluateScript(_ script: String, this: JXValue? = nil, withSourceURL sourceURL: URL? = nil, startingLineNumber: Int = 0) -> JXValue {
        
        let script = script.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(script) }
        
        let sourceURL = sourceURL?.absoluteString.withCString(JSStringCreateWithUTF8CString)
        defer { sourceURL.map(JSStringRelease) }
        
        let result = JSEvaluateScript(context, script, this?.value, sourceURL, Int32(startingLineNumber), &_currentError)
        
        return result.map { JXValue(env: self, value: $0) } ?? JXValue(undefinedIn: self)
    }
}


public extension JXContext {
    enum Errors : Error {
        /// An evaluation error occurred
        case evaluationErrorString(String)
        /// An evaluation error occurred
        case evaluationError(JXValue)
        /// An evaluation error occurred
        case evaluationErrorUnknown
        /// The API call requires a higher system version (e.g., for JS typed array support)
        case minimumSystemVersion
    }
}


public extension JXContext {
    /// Runs the script at the given URL.
    /// - Parameter url: the URL from which to run the script
    /// - Throws: an error if one occurs
    @discardableResult func eval(url: URL) throws -> JXValue {
        try eval(url: url, script: String(contentsOf: url, encoding: .utf8))
    }

    @discardableResult func eval(this: JXValue? = nil, url: URL? = nil, script: String) throws -> JXValue {
        try trying {
            evaluateScript(script, this: this, withSourceURL: url, startingLineNumber: 0)
        }
    }
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
            return nil
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
        let obj = env.globalObject.invokeMethod("create", withArguments: [prototype])
        self.init(env: env, value: obj.value)
    }

    /// Creates a JavaScript `Array` object.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newArrayIn env: JXContext) {
        self.init(env: env, value: JSObjectMakeArray(env.context, 0, nil, &env._currentError))
    }
}

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

extension JXValue: Error {

}

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

extension JXValue {

    /// Tests whether a JavaScript value’s type is the undefined type.
    @inlinable public var isUndefined: Bool {
        return JSValueIsUndefined(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the null type.
    @inlinable public var isNull: Bool {
        return JSValueIsNull(env.context, value)
    }

    /// Tests whether a JavaScript value is Boolean.
    @inlinable public var isBoolean: Bool {
        return JSValueIsBoolean(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the number type.
    @inlinable public var isNumber: Bool {
        return JSValueIsNumber(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the string type.
    @inlinable public var isString: Bool {
        return JSValueIsString(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the object type.
    @inlinable public var isObject: Bool {
        return JSValueIsObject(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the date type.
    @inlinable public var isDate: Bool {
        return self.isInstance(of: env.globalDate)
    }

    /// Tests whether a JavaScript value’s type is the array type.
    @inlinable public var isArray: Bool {
        let result = env.globalArray.invokeMethod("isArray", withArguments: [self])
        return JSValueToBoolean(env.context, result.value)
    }

    /// Tests whether an object can be called as a constructor.
    @inlinable public var isConstructor: Bool {
        return isObject && JSObjectIsConstructor(env.context, value)
    }

    /// Tests whether an object can be called as a function.
    @inlinable public var isFunction: Bool {
        return isObject && JSObjectIsFunction(env.context, value)
    }

    /// Tests whether a JavaScript value’s type is the error type.
    @inlinable public var isError: Bool {
        return self.isInstance(of: env.globalError)
    }
}

extension JXValue {

    @inlinable public var isFrozen: Bool {
        return env.globalObject.invokeMethod("isFrozen", withArguments: [self]).booleanValue
    }

    @inlinable public var isExtensible: Bool {
        return env.globalObject.invokeMethod("isExtensible", withArguments: [self]).booleanValue
    }

    @inlinable public var isSealed: Bool {
        return env.globalObject.invokeMethod("isSealed", withArguments: [self]).booleanValue
    }

    @inlinable public func freeze() {
        env.globalObject.invokeMethod("freeze", withArguments: [self])
    }

    @inlinable public func preventExtensions() {
        env.globalObject.invokeMethod("preventExtensions", withArguments: [self])
    }

    @inlinable public func seal() {
        env.globalObject.invokeMethod("seal", withArguments: [self])
    }
}

extension JXValue {

    /// Returns the JavaScript boolean value.
    @inlinable public var booleanValue: Bool {
        return JSValueToBoolean(env.context, value)
    }

    /// Returns the JavaScript number value.
    @inlinable public var numberValue: Double? {
        var exception: JSObjectRef?
        let result = JSValueToNumber(env.context, value, &exception)
        return exception == nil ? result : nil
    }

    /// Returns the JavaScript string value.
    @inlinable public var stringValue: String? {
        let str = JSValueToStringCopy(env.context, value, nil)
        defer { str.map(JSStringRelease) }
        return str.map(String.init)
    }

    /// Returns the JavaScript date value.
    @inlinable public var dateValue: Date? {
        let result = self.invokeMethod("toISOString", withArguments: [])
        return result.stringValue.flatMap { JXValue.rfc3339.date(from: $0) }
    }

    /// Returns the JavaScript array.
    @inlinable public var array: [JXValue]? {
        guard self.isArray else { return nil }
        return (0..<self.count).map { self[$0] }
    }

    /// Returns the JavaScript object as dictionary.
    @inlinable public var dictionary: [String: JXValue]? {
        !isObject ? nil : self.properties.reduce(into: [:]) { $0[$1] = self[$1] }
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
    @discardableResult @inlinable public func call(withArguments arguments: [JXValue], this: JXValue? = nil) -> JXValue {
        let result = JSObjectCallAsFunction(env.context, value, this?.value, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.value }, &env._currentError)
        return result.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
    }

    /// Calls an object as a constructor.
    ///
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
        return self[name].call(withArguments: arguments, this: self)
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
        return JSValueIsStrictEqual(env.context, value, other.value)
    }

    /// Tests whether two JavaScript values are equal, as compared by the JS `==` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    ///
    /// - Returns: true if the two values are equal; false if they are not equal or an exception is thrown.
    @inlinable public func isEqualWithTypeCoercion(to other: JXValue) -> Bool {
        return JSValueIsEqual(env.context, value, other.value, &env._currentError)
    }

    /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the `isInstance(of:)` operator.
    ///
    /// - Parameters:
    ///   - other: The constructor to test against.
    ///
    /// - Returns: true if the value is an object constructed by constructor, as compared by the JS isInstance(of:) operator; otherwise false.
    @inlinable public func isInstance(of other: JXValue) -> Bool {
        return JSValueIsInstanceOfConstructor(env.context, value, other.value, &env._currentError)
    }
}

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
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    @discardableResult
    @inlinable public func hasProperty(_ property: JXValue) -> Bool {
        JSValueIsObject(env.context, value) && JSObjectHasPropertyForKey(env.context, value, property.value, &env._currentError)
    }

    /// Deletes a property from an object or array.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///
    /// - Returns: true if the delete operation succeeds, otherwise false.
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    @discardableResult
    @inlinable public func deleteProperty(_ property: JXValue) -> Bool {
        return JSObjectDeletePropertyForKey(env.context, value, property.value, &env._currentError)
    }

    /// The value of the property.
    @inlinable public subscript(propertyName: String) -> JXValue {
        get {
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            let result = JSObjectGetProperty(env.context, value, property, &env._currentError)
            return result.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
        }

        set {
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer { JSStringRelease(property) }
            JSObjectSetProperty(env.context, value, property, newValue.value, 0, &env._currentError)
        }
    }
}

extension JXValue {
    /// The length of the object.
    @inlinable public var count: Int {
        let dbl = self["length"].numberValue ?? 0
        return dbl.isNaN || dbl.isSignalingNaN || dbl.isInfinite == true ? 0 : Int(dbl)
    }

    /// The value in object at index.
    @inlinable public subscript(index: Int) -> JXValue {
        get {
            let result = JSObjectGetPropertyAtIndex(env.context, value, UInt32(index), &env._currentError)
            return result.map { JXValue(env: env, value: $0) } ?? JXValue(undefinedIn: env)
        }

        set {
            JSObjectSetPropertyAtIndex(env.context, value, UInt32(index), newValue.value, &env._currentError)
        }
    }
}

extension JXValue {
    /// Returns the JavaScript string with the given indentation. This should be the same as the output of `JSON.stringify`.
    @inlinable public func toJSON(indent: UInt32 = 0) throws -> String {
        var ex: JSValueRef?
        let str = JSValueCreateJSONString(env.context, value, indent, &ex)
        if let ex = ex { throw JXValue(env: env, value: ex) }
        defer { str.map(JSStringRelease) }
        return str.map(String.init) ?? "{}"
    }
}

extension JXValue {

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - length: Length of new `ArrayBuffer` object.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithLength length: Int, in env: JXContext) {
        let obj = env.globalArrayBuffer.construct(withArguments: [JXValue(double: Double(length), in: env)])
        self.init(env: env, value: obj.value)
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to be used as the backing store of the `ArrayBuffer` object.
    ///   - deallocator: The allocator to use to deallocate the external buffer when the `ArrayBuffer` object is deallocated.
    ///   - context: The execution context to use.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    public convenience init(
        newArrayBufferWithBytesNoCopy bytes: UnsafeMutableRawBufferPointer,
        deallocator: @escaping (UnsafeMutableRawBufferPointer) -> Void,
        in env: JXContext
    ) {

        typealias Deallocator = () -> Void

        let info: UnsafeMutablePointer<Deallocator> = .allocate(capacity: 1)
        info.initialize(to: { deallocator(bytes) })

        self.init(
            env: env,
            value: JSObjectMakeArrayBufferWithBytesNoCopy(
                env.context,
                bytes.baseAddress,
                bytes.count,
                { _, info in
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
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    public convenience init<S: DataProtocol>(newArrayBufferWithBytes bytes: S, in env: JXContext) {

        let buffer: UnsafeMutableRawPointer = .allocate(byteCount: bytes.count, alignment: MemoryLayout<UInt8>.alignment)
        bytes.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count))

        self.init(env: env, value: JSObjectMakeArrayBufferWithBytesNoCopy(env.context, buffer, bytes.count, { buffer, _ in buffer?.deallocate() }, nil, &env._currentError))
    }
}

extension JXValue {

    /// Tests whether a JavaScript value’s type is the `ArrayBuffer` type.
    public var isArrayBuffer: Bool {
        return self.isInstance(of: env.globalArrayBuffer)
    }

    /// The length (in bytes) of the `ArrayBuffer`.
    public var byteLength: Int {
        return Int(self["byteLength"].numberValue ?? 0)
    }

    /// Copy the bytes of `ArrayBuffer`.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    public func copyBytes() -> Data? {
        guard self.isArrayBuffer else { return nil }
        let length = JSObjectGetArrayBufferByteLength(env.context, value, &env._currentError)
        return Data(bytes: JSObjectGetArrayBufferBytesPtr(env.context, value, &env._currentError), count: length)
    }
}

public typealias JXObjectCallAsFunctionCallback = (JXContext, JXValue?, [JXValue]) throws -> JXValue

private struct JSObjectCallbackInfo {
    unowned let context: JXContext

    let callback: JXObjectCallAsFunctionCallback
}

private func function_finalize(_ object: JSObjectRef?) -> Void {
    
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSObjectCallbackInfo.self)
    
    info.deinitialize(count: 1)
    info.deallocate()
}

private func function_constructor(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSObjectRef? {
    
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSObjectCallbackInfo.self)
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

private func function_callback(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ this: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
    
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSObjectCallbackInfo.self)
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

private func function_instanceof(
    _ ctx: JSContextRef?,
    _ constructor: JSObjectRef?,
    _ possibleInstance: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
    
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JSObjectCallbackInfo.self)
    
    let env = info.pointee.context
    
    let prototype_0 = JSObjectGetPrototype(env.context, constructor)
    let prototype_1 = JSObjectGetPrototype(env.context, possibleInstance)
    
    return JSValueIsStrictEqual(env.context, prototype_0, prototype_1)
}

extension JXValue {
    
    /// Creates a JavaScript value of the function type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - callback: The callback function.
    public convenience init(newFunctionIn env: JXContext, callback: @escaping JXObjectCallAsFunctionCallback) {
        
        let info: UnsafeMutablePointer<JSObjectCallbackInfo> = .allocate(capacity: 1)
        info.initialize(to: JSObjectCallbackInfo(context: env, callback: callback))
        
        var def = JSClassDefinition()
        def.finalize = function_finalize
        def.callAsConstructor = function_constructor
        def.callAsFunction = function_callback
        def.hasInstance = function_instanceof
        
        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }
        
        self.init(env: env, value: JSObjectMake(env.context, _class, info))
    }
}


/// A descriptor for property’s definition
public struct JSPropertyDescriptor {
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
    public init(
        value: JXValue? = nil,
        writable: Bool? = nil,
        configurable: Bool? = nil,
        enumerable: Bool? = nil
    ) {
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
    /// let desc = JSPropertyDescriptor(
    ///     getter: { this in this["private_val"] },
    ///     setter: { this, newValue in this["private_val"] = newValue }
    /// )
    /// ```
    public init(
        getter: ((JXValue) -> JXValue)? = nil,
        setter: ((JXValue, JXValue) -> Void)? = nil,
        configurable: Bool? = nil,
        enumerable: Bool? = nil
    ) {
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
    public init(
        getter: JXValue? = nil,
        setter: JXValue? = nil,
        configurable: Bool? = nil,
        enumerable: Bool? = nil
    ) {
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

extension JXValue {
    
    /// Defines a property on the JavaScript object value or modifies a property’s definition.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///   - descriptor: The descriptor object.
    ///   
    /// - Returns: true if the operation succeeds, otherwise false.
    @discardableResult
    public func defineProperty(_ property: String, _ descriptor: JSPropertyDescriptor) -> Bool {
        
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
        if let configurable = descriptor.configurable { desc["configurable"] = JXValue(bool: configurable, in: env) }
        if let enumerable = descriptor.enumerable { desc["enumerable"] = JXValue(bool: enumerable, in: env) }
        
        env.globalObject.invokeMethod("defineProperty", withArguments: [self, JXValue(string: property, in: env), desc])
        
        return env.currentError == nil
    }
    
    public func propertyDescriptor(_ property: String) -> JXValue {
        return env.globalObject.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, JXValue(string: property, in: env)])
    }
}

public extension String {
    /// Creates a `Swift.String` from a `JSStringRef`
    @inlinable init(_ str: JSStringRef) {
        self.init(utf16CodeUnits: JSStringGetCharactersPtr(str), count: JSStringGetLength(str))
    }
}
