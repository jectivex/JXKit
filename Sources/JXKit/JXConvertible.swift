import Foundation

/// A type that can move back and forth between Swift and JavaScipt, either through direct reference or by serialization.
///
/// In order to export Swift properties to the JS context, the types must conform to ``JXConvertible``.`
public protocol JXConvertible {
    /// Converts this value into a JXContext
    static func makeJX(from value: JXValue, in context: JXContext) throws -> Self

    /// Converts this value into a JXContext
    func getJX(from context: JXContext) throws -> JXValue
}


extension JXValue {
    /// Attempts to convey the given result from the JS environment.
    /// - Parameter context: the context to use
    /// - Returns: the conveyed instance
    public func convey<T : JXConvertible>(in context: JXContext) throws -> T {
        try T.makeJX(from: self, in: context)
    }
}

/// Default implementation of ``JXConvertible`` will be to encode and decode ``Codable`` instances between Swift & JS
extension JXConvertible where Self : Codable {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        try value.toDecodable(ofType: Self.self)
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        try context.encode(self)
    }
}

extension JXValue : JXConvertible {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard let value = value as? Self else {
            throw JXErrors.jumpContextInvalid
        }
        return value
    }

    /// Converts this value into a JXContext
    public func getJX(from context: JXContext) -> JXValue {
        self
    }
}

extension Optional : JXConvertible where Wrapped : JXConvertible {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        if value.isNull {
            return .none
        } else {
            return try Wrapped.makeJX(from: value, in: context)
        }
    }

    public func getJX(from context: JXContext) throws -> JXValue {
        try self?.getJX(from: context) ?? context.null()
    }
}

extension Array : JXConvertible where Element : JXConvertible {
    public static func makeJX(from value: JXValue, in context: JXContext) throws -> Self {
        guard try value.isArray else {
            throw JXErrors.valueNotArray
        }

        let arrayValue = try value.array

        return try arrayValue.map({ jx in
            try Element.makeJX(from: jx, in: context)
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
    public func set<T : JXConvertible>(_ key: String, object: T) throws {
        try setProperty(key, object.getJX(from: self.env))
    }
}
