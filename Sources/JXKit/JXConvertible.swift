import Foundation

/// A type that can move back and forth between Swift and JavaScipt, either through direct reference or by serialization.
///
/// In order to export Swift properties to the JS context, the types must conform to ``JXConvertible``.`
public protocol JXConvertible {
    /// Converts a `JXValue` into this type.
    static func fromJX(_ value: JXValue) throws -> Self

    /// Converts this value into a JXContext.
    func toJX(in context: JXContext) throws -> JXValue
}


extension JXValue {
    /// Attempts to convey the given result from the JS environment.
    /// - Parameters:
    ///   - context: The context to use.
    /// - Returns: The conveyed instance.
    public func convey<T: JXConvertible>(to type: T.Type = T.self) throws -> T {
        try T.fromJX(self)
    }
}

/// Default implementation of ``JXConvertible`` will be to encode and decode ``Codable`` instances between Swift & JS.
extension Decodable where Self: JXConvertible {
    public static func fromJXCodable(_ value: JXValue) throws -> Self {
        try value.toDecodable(ofType: Self.self)
    }

    public static func fromJX(_ value: JXValue) throws -> Self {
        try fromJXCodable(value)
    }
}

extension Encodable where Self: JXConvertible {
    public func toJXCodable(in context: JXContext) throws -> JXValue {
        try context.encode(self)
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        try toJXCodable(in: context)
    }
}

// We intentionally do not implement Equatable and Hashable to avoid confusion around the semantics of equatability.
//
//extension JXValue: Equatable, Hashable {
//    public static func == (lhs: JXKit.JXValue, rhs: JXKit.JXValue) -> Bool {
//        lhs.value == rhs.value
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        value.hash(into: &hasher)
//    }
//}

extension JXValue: JXConvertible {
    public static func fromJXConvertible(_ value: JXValue) throws -> Self {
        guard let value = value as? Self else {
            throw JXErrors.jumpContextInvalid
        }
        return value
    }

    /// Converts this value into a JXContext.
    public func toJXConvertible(in context: JXContext) -> JXValue {
        self
    }


    public static func fromJX(_ value: JXValue) throws -> Self {
        try fromJXConvertible(value)
    }

    public func toJX(in context: JXContext) -> JXValue {
        toJXConvertible(in: context)
    }

}

extension Optional: JXConvertible where Wrapped: JXConvertible {
    public static func fromJXOptional(_ value: JXValue) throws -> Self {
        if value.isNull {
            return .none
        } else {
            return try Wrapped.fromJX(value)
        }
    }

    public func toJXOptional(in context: JXContext) throws -> JXValue {
        try self?.toJX(in: context) ?? context.null()
    }

    public static func fromJX(_ value: JXValue) throws -> Self {
        try fromJXOptional(value)
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        try toJXOptional(in: context)
    }
}

extension Array: JXConvertible where Element: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self {
        guard value.isArray else {
            throw JXErrors.valueNotArray
        }

        let arrayValue = try value.array

        return try arrayValue.map({ jx in
            try Element.fromJX(jx)
        })
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        try context.array(self.map({ x in
            try x.toJX(in: context)
        }))
    }
}

extension JXValue {
    /// Sets a `JXConvertible` in this value object.
    /// - Parameters:
    ///   - key: The key to set.
    ///   - object: The `JXConvertible` to convert.
    public func set<T: JXConvertible>(_ key: String, convertible object: T) throws {
        try setProperty(key, object.toJX(in: self.context))
    }
}
