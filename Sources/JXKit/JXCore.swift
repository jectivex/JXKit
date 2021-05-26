//
//  Follows is the original SwiftJS license header, on which much of this code was based:
//
//  The MIT License
//  Copyright (c) 2015 - 2021 Susan Cheng. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

// In order to migrate from JavaScriptCore to JXKit, you can use place these aliases in your code to get started:
//
//import JXKit
//@available(*, deprecated, renamed: "JXVirtualMachine")
//public typealias JSVirtualMachine = JXVirtualMachine
//@available(*, deprecated, renamed: "JXContext")
//public typealias JSContext = JXContext
//@available(*, deprecated, renamed: "JXValue")
//public typealias JSValue = JXValue

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
    open var exception: JXValue?
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
public class JXValue {
    public let context: JXContext
    public let object: JSObjectRef

    @inlinable public init(context: JXContext, object: JSObjectRef) {
        JSValueProtect(context.context, object)
        self.context = context
        self.object = object
    }

    @inlinable deinit {
        JSValueUnprotect(context.context, object)
    }
}



extension JXContext {
    
    @usableFromInline var _exception: JSObjectRef? {
        get {
            exception = nil
            return nil
        }
        set {
            
            guard let newValue = newValue else { return }
            
            if let callback = exceptionHandler {
                callback(self, JXValue(context: self, object: newValue))
            } else {
                exception = JXValue(context: self, object: newValue)
            }
        }
    }
}

extension JXContext {

    /// Performs a JavaScript garbage collection.
    ///
    /// During JavaScript execution, you are not required to call this function; the JavaScript engine will garbage collect as needed.
    /// JavaScript values created within a context group are automatically destroyed when the last reference to the context group is released.
    open func garbageCollect() {
        JSGarbageCollect(context)
    }

    /// Returns the global context reference for this context
    public var jsGlobalContextRef: JSGlobalContextRef {
        context
    }
}

extension JXContext {
    /// The global object.
    open var global: JXValue {
        return JXValue(context: self, object: JSContextGetGlobalObject(context))
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
    
    @inlinable open subscript(property: String) -> JXValue {
        get {
            return global[property]
        }
        set {
            global[property] = newValue
        }
    }

    /// Returns the global "Object"
    open var globalObject: JXValue { global["Object"] }

    /// Returns the global "Date"
    open var globalDate: JXValue { global["Date"] }

    /// Returns the global "Array"
    open var globalArray: JXValue { global["Array"] }

    /// Returns the global "ArrayBuffer"
    open var globalArrayBuffer: JXValue { global["ArrayBuffer"] }

    /// Returns the global "Error"
    open var globalError: JXValue { global["Error"] }

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
        
        return JSCheckScriptSyntax(context, script, sourceURL, Int32(startingLineNumber), &_exception)
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
        
        let result = JSEvaluateScript(context, script, this?.object, sourceURL, Int32(startingLineNumber), &_exception)
        
        return result.map { JXValue(context: self, object: $0) } ?? JXValue(undefinedIn: self)
    }
}


public extension JXContext {
    enum Errors : Error {
        /// An evaluation error occurred
        case evaluationErrorString(String)
        /// An evaluation error occurred
        case evaluationError(JXValue)
        /// The API call requires a higher system version (e.g., for JS typed array support)
        case minimumSystemVersion
    }
}


public extension JXContext {
    /// Runs the script at the given URL.
    /// - Parameter url: the URL from which to run the script
    /// - Throws: an error if one occurs
    @discardableResult func eval(url: URL) throws -> JXValue {
        try eval(script: String(contentsOf: url, encoding: .utf8), url: url)
    }

    @discardableResult func eval(script: String, url: URL? = nil) throws -> JXValue {
        try trying {
            evaluateScript(script, this: nil, withSourceURL: url, startingLineNumber: 0)
        }
    }

    /// Tries to execute the given operation, and throws any exceptions that may exists
    func trying<T>(operation: () throws -> T) throws -> T {
        let result = try operation()
        try throwException()
        return result
    }

    /// If an exception occurred, throw it and clear the current exception
    func throwException() throws {
        if let error = self.exception {
            defer { self.exception = nil }
            // TODO: extract standard error properties into a structured Error instance
            if let string = error.stringValue {
                throw Errors.evaluationErrorString(string)
            } else {
                throw Errors.evaluationError(error)
            }
        }
    }
}


extension JXValue {
    open var jsValueRef: JSObjectRef {
        object
    }

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
    @inlinable public convenience init(undefinedIn context: JXContext) {
        self.init(context: context, object: JSValueMakeUndefined(context.context))
    }

    /// Creates a JavaScript value of the `null` type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(nullIn context: JXContext) {
        self.init(context: context, object: JSValueMakeNull(context.context))
    }

    /// Creates a JavaScript `Boolean` value.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(bool value: Bool, in context: JXContext) {
        self.init(context: context, object: JSValueMakeBoolean(context.context, value))
    }

    /// Creates a JavaScript value of the `Number` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(double value: Double, in context: JXContext) {
        self.init(context: context, object: JSValueMakeNumber(context.context, value))
    }

    /// Creates a JavaScript value of the `String` type.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(string value: String, in context: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        self.init(context: context, object: JSValueMakeString(context.context, value))
    }

    /// Creates a JavaScript value of the parsed `JSON`.
    ///
    /// - Parameters:
    ///   - value: The JSON value to parse
    ///   - context: The execution context to use.
    @inlinable public convenience init?(json value: String, in context: JXContext) {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        guard let json = JSValueMakeFromJSONString(context.context, value) else {
            return nil
        }
        self.init(context: context, object: json)
    }

    /// Creates a JavaScript `Date` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - value: The value to assign to the object.
    ///   - context: The execution context to use.
    @inlinable public convenience init(date value: Date, in context: JXContext) {
        let arguments = [JXValue(string: JXValue.rfc3339.string(from: value), in: context)]
        let object = JSObjectMakeDate(context.context, 1, arguments.map { $0.object }, &context._exception)
        self.init(context: context, object: object!)
    }

    /// Creates a JavaScript `RegExp` object, as if by invoking the built-in `RegExp` constructor.
    ///
    /// - Parameters:
    ///   - pattern: The pattern of regular expression.
    ///   - flags: The flags pass to the constructor.
    ///   - context: The execution context to use.
    @inlinable public convenience init(newRegularExpressionFromPattern pattern: String, flags: String, in context: JXContext) {
        let arguments = [JXValue(string: pattern, in: context), JXValue(string: flags, in: context)]
        let object = JSObjectMakeRegExp(context.context, 2, arguments.map { $0.object }, &context._exception)
        self.init(context: context, object: object!)
    }

    /// Creates a JavaScript `Error` object, as if by invoking the built-in `Error` constructor.
    ///
    /// - Parameters:
    ///   - message: The error message.
    ///   - context: The execution context to use.
    @inlinable public convenience init(newErrorFromMessage message: String, in context: JXContext) {
        let arguments = [JXValue(string: message, in: context)]
        self.init(context: context, object: JSObjectMakeError(context.context, 1, arguments.map { $0.object }, &context._exception))
    }

    /// Creates a JavaScript `Object`.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newObjectIn context: JXContext) {
        self.init(context: context, object: JSObjectMake(context.context, nil, nil))
    }

    /// Creates a JavaScript `Object` with prototype.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - prototype: The prototype to be used.
    @inlinable public convenience init(newObjectIn context: JXContext, prototype: JXValue) {
        let obj = context.globalObject.invokeMethod("create", withArguments: [prototype])
        self.init(context: context, object: obj.object)
    }

    /// Creates a JavaScript `Array` object.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    @inlinable public convenience init(newArrayIn context: JXContext) {
        self.init(context: context, object: JSObjectMakeArray(context.context, 0, nil, &context._exception))
    }
}

extension JXValue: CustomStringConvertible {

    @inlinable public var description: String {
        if self.isUndefined { return "undefined" }
        if self.isNull { return "null" }
        if self.isBoolean { return "\(self.boolValue)" }
        if self.isNumber { return "\(self.doubleValue!)" }
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
            let prototype = JSObjectGetPrototype(context.context, object)
            return prototype.map { JXValue(context: context, object: $0) } ?? JXValue(undefinedIn: context)
        }
        set {
            JSObjectSetPrototype(context.context, object, newValue.object)
        }
    }
}

extension JXValue {

    /// Tests whether a JavaScript value’s type is the undefined type.
    @inlinable public var isUndefined: Bool {
        return JSValueIsUndefined(context.context, object)
    }

    /// Tests whether a JavaScript value’s type is the null type.
    @inlinable public var isNull: Bool {
        return JSValueIsNull(context.context, object)
    }

    /// Tests whether a JavaScript value is Boolean.
    @inlinable public var isBoolean: Bool {
        return JSValueIsBoolean(context.context, object)
    }

    /// Tests whether a JavaScript value’s type is the number type.
    @inlinable public var isNumber: Bool {
        return JSValueIsNumber(context.context, object)
    }

    /// Tests whether a JavaScript value’s type is the string type.
    @inlinable public var isString: Bool {
        return JSValueIsString(context.context, object)
    }

    /// Tests whether a JavaScript value’s type is the object type.
    @inlinable public var isObject: Bool {
        return JSValueIsObject(context.context, object)
    }

    /// Tests whether a JavaScript value’s type is the date type.
    @inlinable public var isDate: Bool {
        return self.isInstance(of: context.globalDate)
    }

    /// Tests whether a JavaScript value’s type is the array type.
    @inlinable public var isArray: Bool {
        let result = context.globalArray.invokeMethod("isArray", withArguments: [self])
        return JSValueToBoolean(context.context, result.object)
    }

    /// Tests whether an object can be called as a constructor.
    @inlinable public var isConstructor: Bool {
        return isObject && JSObjectIsConstructor(context.context, object)
    }

    /// Tests whether an object can be called as a function.
    @inlinable public var isFunction: Bool {
        return isObject && JSObjectIsFunction(context.context, object)
    }

    /// Tests whether a JavaScript value’s type is the error type.
    @inlinable public var isError: Bool {
        return self.isInstance(of: context.globalError)
    }
}

extension JXValue {

    @inlinable public var isFrozen: Bool {
        return context.globalObject.invokeMethod("isFrozen", withArguments: [self]).boolValue
    }

    @inlinable public var isExtensible: Bool {
        return context.globalObject.invokeMethod("isExtensible", withArguments: [self]).boolValue
    }

    @inlinable public var isSealed: Bool {
        return context.globalObject.invokeMethod("isSealed", withArguments: [self]).boolValue
    }

    @inlinable public func freeze() {
        context.globalObject.invokeMethod("freeze", withArguments: [self])
    }

    @inlinable public func preventExtensions() {
        context.globalObject.invokeMethod("preventExtensions", withArguments: [self])
    }

    @inlinable public func seal() {
        context.globalObject.invokeMethod("seal", withArguments: [self])
    }
}

extension JXValue {

    /// Returns the JavaScript boolean value.
    @inlinable public var boolValue: Bool {
        return JSValueToBoolean(context.context, object)
    }

    /// Returns the JavaScript number value.
    @inlinable public var doubleValue: Double? {
        var exception: JSObjectRef?
        let result = JSValueToNumber(context.context, object, &exception)
        return exception == nil ? result : nil
    }

    /// Returns the JavaScript string value.
    @inlinable public var stringValue: String? {
        let str = JSValueToStringCopy(context.context, object, nil)
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
         let result = JSObjectCallAsFunction(context.context, object, this?.object, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.object }, &context._exception)
        return result.map { JXValue(context: context, object: $0) } ?? JXValue(undefinedIn: context)
    }

    /// Calls an object as a constructor.
    ///
    /// - Parameters:
    ///   - arguments: The arguments pass to the function.
    ///
    /// - Returns: The object that results from calling object as a constructor.
    @inlinable public func construct(withArguments arguments: [JXValue]) -> JXValue {
        let result = JSObjectCallAsConstructor(context.context, object, arguments.count, arguments.isEmpty ? nil : arguments.map { $0.object }, &context._exception)
        return result.map { JXValue(context: context, object: $0) } ?? JXValue(undefinedIn: context)
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
        return JSValueIsStrictEqual(context.context, object, other.object)
    }

    /// Tests whether two JavaScript values are equal, as compared by the JS `==` operator.
    ///
    /// - Parameters:
    ///   - other: The other value to be compare.
    ///
    /// - Returns: true if the two values are equal; false if they are not equal or an exception is thrown.
    @inlinable public func isEqualWithTypeCoercion(to other: JXValue) -> Bool {
        return JSValueIsEqual(context.context, object, other.object, &context._exception)
    }

    /// Tests whether a JavaScript value is an object constructed by a given constructor, as compared by the `isInstance(of:)` operator.
    ///
    /// - Parameters:
    ///   - other: The constructor to test against.
    ///
    /// - Returns: true if the value is an object constructed by constructor, as compared by the JS isInstance(of:) operator; otherwise false.
    @inlinable public func isInstance(of other: JXValue) -> Bool {
        return JSValueIsInstanceOfConstructor(context.context, object, other.object, &context._exception)
    }
}

extension JXValue {

    /// Get the names of an object’s enumerable properties.
    @inlinable public var properties: [String] {

        let _list = JSObjectCopyPropertyNames(context.context, object)
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
        return JSObjectHasProperty(context.context, object, property)
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
        return JSObjectDeleteProperty(context.context, object, property, &context._exception)
    }

    /// The value of the property.
    @inlinable public subscript(propertyName: String) -> JXValue {
        get {
            let property = JSStringCreateWithUTF8CString(propertyName)

            defer {
                JSStringRelease(property)
            }

            let result = JSObjectGetProperty(context.context, object, property, &context._exception)

            return result.map { JXValue(context: context, object: $0) } ?? JXValue(undefinedIn: context)
        }

        set {
            let property = JSStringCreateWithUTF8CString(propertyName)
            defer {
                JSStringRelease(property)
            }
            JSObjectSetProperty(context.context, object, property, newValue.object, 0, &context._exception)
        }
    }
}

extension JXValue {

    /// The length of the object.
    @inlinable public var count: Int {
        let dbl = self["length"].doubleValue ?? 0
        return dbl.isNaN || dbl.isSignalingNaN || dbl.isInfinite == true ? 0 : Int(dbl)
    }

    /// The value in object at index.
    @inlinable public subscript(index: Int) -> JXValue {
        get {
            let result = JSObjectGetPropertyAtIndex(context.context, object, UInt32(index), &context._exception)
            return result.map { JXValue(context: context, object: $0) } ?? JXValue(undefinedIn: context)
        }
        set {
            JSObjectSetPropertyAtIndex(context.context, object, UInt32(index), newValue.object, &context._exception)
        }
    }
}

extension JXValue {
    /// Returns the JavaScript string value.
    @inlinable public func toJSON(indent: UInt32 = 0) -> String? {
        var ex: JSValueRef?
        let str = JSValueCreateJSONString(context.context, object, indent, &ex)
        defer { str.map(JSStringRelease) }
        return str.map(String.init)
    }
}

extension JXValue {

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - length: Length of new `ArrayBuffer` object.
    ///   - context: The execution context to use.
    public convenience init(newArrayBufferWithLength length: Int, in context: JXContext) {
        let obj = context.globalArrayBuffer.construct(withArguments: [JXValue(double: Double(length), in: context)])
        self.init(context: context, object: obj.object)
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
        in context: JXContext
    ) {

        typealias Deallocator = () -> Void

        let info: UnsafeMutablePointer<Deallocator> = .allocate(capacity: 1)
        info.initialize(to: { deallocator(bytes) })

        self.init(
            context: context,
            object: JSObjectMakeArrayBufferWithBytesNoCopy(
                context.context,
                bytes.baseAddress,
                bytes.count,
                { _, info in
                    guard let info = info?.assumingMemoryBound(to: Deallocator.self) else { return }
                    info.pointee()
                    info.deinitialize(count: 1).deallocate()
                },
                info,
                &context._exception
            )
        )
    }

    /// Creates a JavaScript `ArrayBuffer` object.
    ///
    /// - Parameters:
    ///   - bytes: A buffer to copy.
    ///   - context: The execution context to use.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    public convenience init<S: DataProtocol>(newArrayBufferWithBytes bytes: S, in context: JXContext) {

        let buffer: UnsafeMutableRawPointer = .allocate(byteCount: bytes.count, alignment: MemoryLayout<UInt8>.alignment)
        bytes.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: bytes.count))

        self.init(context: context, object: JSObjectMakeArrayBufferWithBytesNoCopy(context.context, buffer, bytes.count, { buffer, _ in buffer?.deallocate() }, nil, &context._exception))
    }
}

extension JXValue {

    /// Tests whether a JavaScript value’s type is the `ArrayBuffer` type.
    public var isArrayBuffer: Bool {
        return self.isInstance(of: context.globalArrayBuffer)
    }

    /// The length (in bytes) of the `ArrayBuffer`.
    public var byteLength: Int {
        return Int(self["byteLength"].doubleValue ?? 0)
    }

    /// Copy the bytes of `ArrayBuffer`.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, *)
    public func copyBytes() -> Data? {
        guard self.isArrayBuffer else { return nil }
        let length = JSObjectGetArrayBufferByteLength(context.context, object, &context._exception)
        return Data(bytes: JSObjectGetArrayBufferBytesPtr(context.context, object, &context._exception), count: length)
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
    let context = info.pointee.context
    
    do {
        
        let arguments = (0..<argumentCount).map { JXValue(context: context, object: arguments![$0]!) }
        let result = try info.pointee.callback(context, nil, arguments)
        
        let prototype = JSObjectGetPrototype(context.context, object)
        JSObjectSetPrototype(context.context, result.object, prototype)
        
        return result.object
        
    } catch let error {
        
        let error = error as? JXValue ?? JXValue(newErrorFromMessage: "\(error)", in: context)
        exception?.pointee = error.object
        
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
    let context = info.pointee.context
    
    do {
        
        let this = this.map { JXValue(context: context, object: $0) }
        let arguments = (0..<argumentCount).map { JXValue(context: context, object: arguments![$0]!) }
        let result = try info.pointee.callback(context, this, arguments)
        
        return result.object
        
    } catch let error {
        
        let error = error as? JXValue ?? JXValue(newErrorFromMessage: "\(error)", in: context)
        exception?.pointee = error.object
        
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
    
    let context = info.pointee.context
    
    let prototype_0 = JSObjectGetPrototype(context.context, constructor)
    let prototype_1 = JSObjectGetPrototype(context.context, possibleInstance)
    
    return JSValueIsStrictEqual(context.context, prototype_0, prototype_1)
}

extension JXValue {
    
    /// Creates a JavaScript value of the function type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - callback: The callback function.
    public convenience init(newFunctionIn context: JXContext, callback: @escaping JXObjectCallAsFunctionCallback) {
        
        let info: UnsafeMutablePointer<JSObjectCallbackInfo> = .allocate(capacity: 1)
        info.initialize(to: JSObjectCallbackInfo(context: context, callback: callback))
        
        var def = JSClassDefinition()
        def.finalize = function_finalize
        def.callAsConstructor = function_constructor
        def.callAsFunction = function_callback
        def.hasInstance = function_instanceof
        
        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }
        
        self.init(context: context, object: JSObjectMake(context.context, _class, info))
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
        
        let desc = JXValue(newObjectIn: context)
        
        if let value = descriptor.value { desc["value"] = value }
        if let writable = descriptor.writable { desc["writable"] = JXValue(bool: writable, in: context) }
        if let getter = descriptor._getter {
            desc["get"] = getter
        } else if let getter = descriptor.getter {
            desc["get"] = JXValue(newFunctionIn: context) { _, this, _ in try getter(this!) }
        }
        if let setter = descriptor._setter {
            desc["set"] = setter
        } else if let setter = descriptor.setter {
            desc["set"] = JXValue(newFunctionIn: context) { context, this, arguments in
                try setter(this!, arguments[0])
                return JXValue(undefinedIn: context)
            }
        }
        if let configurable = descriptor.configurable { desc["configurable"] = JXValue(bool: configurable, in: context) }
        if let enumerable = descriptor.enumerable { desc["enumerable"] = JXValue(bool: enumerable, in: context) }
        
        context.globalObject.invokeMethod("defineProperty", withArguments: [self, JXValue(string: property, in: context), desc])
        
        return context.exception == nil
    }
    
    public func propertyDescriptor(_ property: String) -> JXValue {
        return context.globalObject.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, JXValue(string: property, in: context)])
    }
}

public extension String {
    /// Creates a `Swift.String` from a `JSStringRef`
    @inlinable init(_ str: JSStringRef) {
        self.init(utf16CodeUnits: JSStringGetCharactersPtr(str), count: JSStringGetLength(str))
    }
}
