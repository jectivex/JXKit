import Foundation

/// A type that can move back and forth between Swift and JavaScipt, either through direct reference or by serialization.
///
/// In order to export Swift properties to the JS context, the types must conform to ``JXConvertible``.`
public protocol JXConvertible {
    /// Converts this value into a JXContext
    static func makeJX(from value: JXValue) throws -> Self

    /// Converts this value into a JXContext
    func getJX(from context: JXContext) throws -> JXValue
}


extension JXValue {
    /// Attempts to convey the given result from the JS environment.
    /// - Parameter context: the context to use
    /// - Returns: the conveyed instance
    public func convey<T : JXConvertible>(to type: T.Type = T.self) throws -> T {
        try T.makeJX(from: self)
    }
}

/// Default implementation of ``JXConvertible`` will be to encode and decode ``Codable`` instances between Swift & JS
extension Decodable where Self : JXConvertible {
    public static func makeJXCodable(from value: JXValue) throws -> Self {
        try value.toDecodable(ofType: Self.self)
    }

    public static func makeJX(from value: JXValue) throws -> Self {
        try makeJXCodable(from: value)
    }
}

extension Encodable where Self : JXConvertible {
    public func getJXCodable(from context: JXContext) throws -> JXValue {
        try context.encode(self)
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        try getJXCodable(from: context)
    }
}

// we intentionally do not implement Equatable and Hashable to avoid confusion around the semantics of equatability
//
//extension JXValue : Equatable, Hashable {
//    public static func == (lhs: JXKit.JXValue, rhs: JXKit.JXValue) -> Bool {
//        lhs.value == rhs.value
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        value.hash(into: &hasher)
//    }
//}

extension JXValue : JXConvertible {
    public static func makeJXConvertible(from value: JXValue) throws -> Self {
        guard let value = value as? Self else {
            throw JXErrors.jumpContextInvalid
        }
        return value
    }

    /// Converts this value into a JXContext
    public func getJXConvertible(from context: JXContext) -> JXValue {
        self
    }


    public static func makeJX(from value: JXValue) throws -> Self {
        try makeJXConvertible(from: value)
    }

    public func getJX(from context: JXContext) -> JXValue {
        getJXConvertible(from: context)
    }

}

extension Optional : JXConvertible where Wrapped : JXConvertible {
    public static func makeJXOptional(from value: JXValue) throws -> Self {
        if value.isNull {
            return .none
        } else {
            return try Wrapped.makeJX(from: value)
        }
    }

    public func getJXOptional(from context: JXContext) throws -> JXValue {
        try self?.getJX(from: context) ?? context.null()
    }

    public static func makeJX(from value: JXValue) throws -> Self {
        try makeJXOptional(from: value)
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        try getJXOptional(from: context)
    }
}

extension Array : JXConvertible where Element : JXConvertible {
    public static func makeJX(from value: JXValue) throws -> Self {
        guard try value.isArray else {
            throw JXErrors.valueNotArray
        }

        let arrayValue = try value.array

        return try arrayValue.map({ jx in
            try Element.makeJX(from: jx)
        })
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        try context.array(self.map({ x in
            try x.getJX(from: context)
        }))
    }
}

extension JXValue {
    /// Sets a `JXConvertible` in this value object.
    /// - Parameters:
    ///   - key: the key to set
    ///   - object: the `JXConvertible` to convert
    public func set<T : JXConvertible>(_ key: String, convertible object: T) throws {
        try setProperty(key, object.getJX(from: self.ctx))
    }
}
