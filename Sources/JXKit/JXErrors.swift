/// An error thrown from JavaScript evaluation.
public class JXEvalError: JXValue, Error, @unchecked Sendable {
}

/// JXKit framework errors.
public enum JXErrors: Error {
    /// Unable to create a new promise.
    case cannotCreatePromise
    /// Unable to create a new array buffer.
    case cannotCreateArrayBuffer
    /// An async call is expected to return a promise.
    case asyncEvalMustReturnPromise
    /// The promise returned from an async call is not value.
    case invalidAsyncPromise
    /// Attempt to invoke a non-function object.
    case callOnNonFunction
    /// Attempt to access a property on an instance that is not an object.
    case propertyAccessNonObject
    /// Attempt to add to something that is not an array.
    case addToNonArray
    /// This can occur when the bound instance is not retained anywhere.
    case jumpContextInvalid
    /// Expected an array for conversion.
    case valueNotArray
    /// Expected a date for conversion.
    case valueNotDate
    /// A synbolic key was attempted to be set, but the value was not a symbol.
    case keyNotSymbol
    /// An object could not be created from the given JSON.
    case cannotCreateFromJSON
    /// A conversion to another numic type failed.
    case invalidNumericConversion(Double)
}

