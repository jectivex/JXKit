//
//  File.swift
//  
//
//  Created by Marc Prud'hommeaux on 5/29/21.
//

import Foundation

/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
@discardableResult @inlinable func wip<T>(_ value: T) -> T { value }

/// A `JXEnv` is an abstraction of a JavaScript execution environment. The associated `ValueType` represents the value encapsulations type.
public protocol JXEnv : AnyObject {
    /// The value type that is associated with this environment
    associatedtype ValType : JXVal

    /// The current exception if it exists; setting it to nil will clear it
    var exception: ValType? { get set }

    /// Creates a new `null` instance for this environment
    func null() -> ValType

    /// Creates a new `undefined` instance for this environment
    func undefined() -> ValType

    /// Creates a string in the environment from the given value
    func string<S: StringProtocol>(_ value: S) -> ValType

    /// Creates a data in the environment from the given value
    func data<D: DataProtocol>(_ value: D) -> ValType

    /// Creates a date in the environment from the given value
    func date(_ value: Date) -> ValType

    /// Creates a number in the environment from the given value
    func number<F: BinaryFloatingPoint>(_ value: F) -> ValType

    /// Creates a number in the environment from the given value
    func number<I: BinaryInteger>(_ value: I) -> ValType

    func eval(this: JXValue?, url: URL?, script: String) throws -> ValType

    /// Accesses the value for the given property
    subscript(_ property: String) -> ValType { get set }
}

/// A `JXEnv` is an abstraction of a JavaScript value.
public protocol JXVal : AnyObject {
    /// The value type that is associated with this environment
    associatedtype EnvType : JXEnv

    /// The context associated with this value
    var env: EnvType { get }

    var properties: [String] { get }
    func hasProperty(_ value: String) -> Bool

    var isUndefined: Bool { get }
    var isString: Bool { get }
    var isNumber: Bool { get }

    var stringValue: String? { get }
}


extension JXValue {
    @available(*, deprecated, renamed: "env")
    var context: JXContext { env }
}

public extension JXEnv {
    /// Evaluates with a `nil` this
    func eval(_ script: String) throws -> ValType {
        try eval(this: nil, url: nil, script: script)
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
                throw JXContext.Errors.evaluationErrorString(string)
            } else if let error = error as? Error & JXValue {
                throw JXContext.Errors.evaluationError(error)
            } else {
                throw JXContext.Errors.evaluationErrorUnknown
            }
        }
    }
}

extension JXValue : JXVal {
}

extension JXContext : JXEnv {
    public func null() -> JXValue {
        JXValue(nullIn: self)
    }

    public func undefined() -> JXValue {
        JXValue(undefinedIn: self)
    }

    public func number<F: BinaryFloatingPoint>(_ value: F) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    public func number<I: BinaryInteger>(_ value: I) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    public func string<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(string: String(value), in: self)
    }

    public func date(_ value: Date) -> JXValue {
        JXValue(date: value, in: self)
    }

    public func data<D: DataProtocol>(_ value: D) -> JXValue {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            return JXValue(newArrayBufferWithBytes: value, in: self)
        } else {
            return undefined()
        }
    }
}

/// A reference type that a wraps `JSGlobalContextRef`.
///
/// - Note: This protocol is implemented by both `JXKit.JXContext` and `JavaScriptCore.JSContext` to enable migration & inter-operability between the frameworks.
public protocol JavaScriptCoreContext : AnyObject {
    /// The JavaScriptCore's underlying context
    var context: JSGlobalContextRef { get }
}

/// `JXContext.context` already exists, so conformance is automatic
extension JXContext : JavaScriptCoreContext { }

/// Shim for supporting `JXKit` functionality in the `JSContext` & `JSValue` classes on Objective-C-suppored platforms
#if canImport(JavaScriptCore)
import JavaScriptCore

extension JSContext : JavaScriptCoreContext {
    /// `JSContext.context` is the `jsGlobalContextRef` value
    public var context: JSGlobalContextRef { jsGlobalContextRef }
}

/// Support for `JXEnv` in `JavaScriptCore`. Useful for porting from `JavaScriptCore` to `JXCore`
extension JSContext : JXEnv {
    ///
    public var exception: JSValue? {
        get { self.exception }
        set { self.exception = newValue }
    }

    public func eval(this: JXValue?, url: URL?, script: String) throws -> JSValue {
        try trying {
            // TODO: set the current `this`
            evaluateScript(script, withSourceURL: url)
        }
    }

    public typealias ValType = JSValue

    public subscript(property: String) -> JSValue {
        get { self[property] }
        set { self[property] = newValue }
    }

    public func null() -> JSValue {
        JSValue(nullIn: self)
    }

    public func undefined() -> JSValue {
        JSValue(undefinedIn: self)
    }

    public func number<F>(_ value: F) -> JSValue where F : BinaryFloatingPoint {
        JSValue(double: Double(value), in: self)
    }

    public func number<I>(_ value: I) -> JSValue where I : BinaryInteger {
        JSValue(double: Double(value), in: self)
    }

    public func string<S>(_ value: S) -> JSValue where S : StringProtocol {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        return JSValue(jsValueRef: JSValueMakeString(jsGlobalContextRef, value), in: self)
    }

    @available(*, deprecated, message: "not yet implemented")
    public func data<D>(_ value: D) -> JSValue where D : DataProtocol {
        wip(undefined()) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public func date(_ value: Date) -> JSValue {
        wip(undefined()) // TODO
    }
}

/// Support for `JXVal` in `JavaScriptCore`. Useful for porting from `JavaScriptCore` to `JXCore`
extension JSValue : JXVal {
    public typealias EnvType = JSContext

    public var env: JSContext {
        self.context // `JSValue.context` has a `JSContext!` type
    }

    @available(*, deprecated, message: "not yet implemented")
    public var stringValue: String? {
        wip(nil) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public var properties: [String] {
        wip([]) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public func hasProperty(_ value: String) -> Bool {
        wip(false) // TODO
    }
}
#endif

