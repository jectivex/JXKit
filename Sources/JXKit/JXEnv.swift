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
    associatedtype JXValType : JXVal

    /// The global object
    var global: JXValType { get }

    /// The current exception if it exists; setting it to nil will clear it
    var currentError: JXValType? { get set }

    /// Creates a new `null` instance for this environment
    func null() -> JXValType

    /// Creates a new `undefined` instance for this environment
    func undefined() -> JXValType

    /// Creates a string in the environment from the given value
    func string<S: StringProtocol>(_ value: S) -> JXValType

    /// Creates a data in the environment from the given value
    func data<D: DataProtocol>(_ value: D) -> JXValType

    /// Creates a date in the environment from the given value
    func date(_ value: Date) -> JXValType

    /// Creates a number in the environment from the given value
    func number<F: BinaryFloatingPoint>(_ value: F) -> JXValType

    /// Creates a number in the environment from the given value
    func number<I: BinaryInteger>(_ value: I) -> JXValType

    func eval(this: JXValue?, url: URL?, script: String) throws -> JXValType

    /// Accesses the value for the given property
    subscript(_ property: String) -> JXValType { get set }
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

    /// Accesses the value for the given property if this is an object type
    subscript(_ property: String) -> EnvType.JXValType { get set }
}


extension JXValue {
    @available(*, deprecated, renamed: "env")
    var context: JXContext { env }
}

public extension JXEnv {
    /// Evaluates with a `nil` this
    func eval(_ script: String) throws -> JXValType {
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
        if let error = self.currentError {
            defer { self.currentError = nil }
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
