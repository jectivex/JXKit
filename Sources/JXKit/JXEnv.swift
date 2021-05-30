//
//  JXEnv.swift
//
//  A JavaScript execution environment with a single associated value type.
//
//  Created by Marc Prud'hommeaux on 5/29/21.
//
import Foundation

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

    /// Creates a boolean in the environment from the given value
    func boolean(_ value: Bool) -> JXValType

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

    /// Evaluates the given script and returns the return value.
    /// - Parameters:
    ///   - this: the current `this`, or `nil`
    ///   - url: the URL for the script being executed; used merely for debug and error messages
    ///   - script: the script string to execute
    func eval(this: JXValue?, url: URL?, script: String) throws -> JXValType
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
    var isNull: Bool { get }
    var isObject: Bool { get }

    var isNumber: Bool { get }
    var numberValue: Double? { get }

    var isString: Bool { get }
    var stringValue: String? { get }

    var dateValue: Date? { get }

    /// Returns the JavaScript array.
    var array: [EnvType.JXValType]? { get }

    /// Returns the JavaScript object as dictionary.
    var dictionary: [String: EnvType.JXValType]? { get }

    /// Accesses the value for the given property if this is an object type
    subscript(_ property: String) -> EnvType.JXValType { get set }
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

/// Utilities common to all `JXEnv` implementations
extension JXEnv {
    public typealias BaseValType = JXValType.EnvType.JXValType

    /// Returns the global "Object"
    public var globalObject: BaseValType { global["Object"] }

    /// Returns the global "Date"
    public var globalDate: BaseValType { global["Date"] }

    /// Returns the global "Array"
    public var globalArray: BaseValType { global["Array"] }

    /// Returns the global "ArrayBuffer"
    public var globalArrayBuffer: BaseValType { global["ArrayBuffer"] }

    /// Returns the global "Error"
    public var globalError: BaseValType { global["Error"] }
}

