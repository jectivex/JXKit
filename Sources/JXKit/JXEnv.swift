//
//  JXEnv.swift
//
//  A JavaScript execution environment with a single associated value type.
//
//  Created by Marc Prud'hommeaux on 5/29/21.
//
import Foundation

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

/// A `JXVM` is an abstraction of a JavaScript vitual machine. The associated `EnvType` represents the environment encapsulations type.
public protocol JXVM : AnyObject {
    /// The value type that is associated with this environment
    associatedtype EnvType : JXEnv

    /// Create a new environment from this VM
    func env() -> EnvType
}

/// A `JXEnv` is an abstraction of a JavaScript execution environment. The associated `ValueType` represents the value encapsulationd type.
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

    /// Creates a new array in the environment
    func array(_ values: [JXValType]) -> JXValType

    /// Creates a new object in the environment
    func object() -> JXValType

    /// Creates a data in the environment from the given value.
    ///
    /// On platform where array buffers are unsupported, this will return `undefined()`
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

    /// Returns true is this is a JavaScript object.
    var isObject: Bool { get }

    var numberValue: Double? { get }
    var isNumber: Bool { get }

    var stringValue: String? { get }
    var isString: Bool { get }

    /// Returns `true` if this is a JavaScript array. Note that `isObject` will also return `true`.
    var isArray: Bool { get }

    /// Returns this value as a boolean. Note that this will use JavaScript's rules for treating other value types as booleans
    var booleanValue: Bool { get }
    var isBoolean: Bool { get }

    var isFunction: Bool { get }
    /// Invokes this function with the specified arguments
    func call(withArguments arguments: [EnvType.JXValType], this: EnvType.JXValType?) -> EnvType.JXValType

    /// If this is a date type, returns the Date value. Note that `isObject` will also return true fir t
    var isDate: Bool { get }
    var dateValue: Date? { get }

    /// Returns the JavaScript array.
    var array: [EnvType.JXValType]? { get }

    /// Returns the JavaScript object as dictionary.
    var dictionary: [String: EnvType.JXValType]? { get }

    /// Accesses the value for the given property if this is an object type
    subscript(_ property: String) -> EnvType.JXValType { get set }
}

extension JXVal {
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

extension JXEnv {
    /// Evaluates with a `nil` this
    public func eval(_ script: String) throws -> JXValType {
        try eval(this: nil, url: nil, script: script)
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
    public var objectPrototype: BaseValType { global["Object"] }

    /// Returns the global "Date"
    public var datePrototype: BaseValType { global["Date"] }

    /// Returns the global "Array"
    public var arrayPrototype: BaseValType { global["Array"] }

    /// Returns the global "ArrayBuffer"
    public var arrayBufferPrototype: BaseValType { global["ArrayBuffer"] }

    /// Returns the global "Error"
    public var errorPrototype: BaseValType { global["Error"] }
}

