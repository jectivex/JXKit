/// A type of JavaScript instance.
public enum JXType: Hashable {
    /// An undefined value.
    case undefined
    /// A null value.
    case null
    /// A boolean type.
    case boolean
    /// A number type.
    case number
    /// A string type.
    case string
    /// An symbol type.
    case symbol
    /// An array type.
    case array
    /// A date type.
    case date
    /// An array buffer type.
    case arrayBuffer
    /// A Promise type.
    case promise
    /// An Error type.
    case error
    /// A constructor type.
    case constructor
    /// A function type.
    case function
    /// An object type.
    case object
    /// A type not enumerated here.
    case other
}

extension JXValue {
    /// The JavaScript type of this value.
    public var type: JXType {
        if isUndefined { return .undefined }
        if isNull { return .null }
        if isBoolean { return .boolean }
        if isNumber { return .number }
        if isString { return .string }
        if isSymbol { return .symbol }
        if isArray { return .array }
        if (try? isDate) == true { return .date }
        if (try? isArrayBuffer) == true { return .arrayBuffer }
        if (try? isPromise) == true { return .promise }
        if (try? isError) == true { return .error }
        if isConstructor { return .constructor }
        if isFunction { return .function }
        if isObject { return .object }
        return .other
    }
}
