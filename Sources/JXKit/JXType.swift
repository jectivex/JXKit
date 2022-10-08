/// A type of JavaScript instance.
public enum JXType: Hashable {
    /// A null value.
    case null
    /// An undefined value.
    case undefined
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
    /// An object type.
    case object
    /// An symbol type.
    case symbol
    /// A type not enumerated here.
    case other
}

extension JXValue {
    /// The JavaScript type of this value.
    @inlinable public var type: JXType {
        if isUndefined { return .undefined }
        if isNull { return .null }
        if isBoolean { return .boolean }
        if isNumber { return .number }
        if isSymbol { return .symbol }
        if (try? isDate) == true { return .date }
        if isString { return .string }
        if isArray { return .array }
        if isObject { return .object }
        return .other
    }
}
