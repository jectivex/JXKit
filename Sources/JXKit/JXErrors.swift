/// An error thrown from JavaScript evaluation.
public class JXEvalError: JXValue, Error, @unchecked Sendable {
}

/// JXKit framework errors.
public enum JXErrors: Error {
    /// Unable to create a new promise.
    case cannotCreatePromise
    /// Unable to create a new array buffer.
    case cannotCreateArrayBuffer
    /// An object could not be created from the given JSON.
    case cannotCreateFromJSON
    /// Cannot convey this type to or from JavaScript.
    case cannotConvey(Any.Type)
    /// An async call is expected to return a promise.
    case asyncEvalMustReturnPromise
    /// The promise returned from an async call is not valid.
    case invalidAsyncPromise
    /// A conversion to another numic type or min/max range failed.
    case invalidNumericConversion(Double)
    /// A value could not be used to create a `RawRepresentable`.
    case invalidRawValue(String)
    /// A synbolic key was attempted to be set, but the value was not a symbol.
    case keyNotSymbol
    /// This can occur when the bound instance is not retained anywhere.
    case jumpContextInvalid
    /// Expected a JavaScript array.
    case valueNotArray
    /// Expected a JavaScript date.
    case valueNotDate
    /// Expected a JavaScript function.
    case valueNotFunction
    /// Expected a JavaScript number.
    case valueNotNumber
    /// Expected a JavaScript object.
    case valueNotObject
}

