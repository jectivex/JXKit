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

extension Dictionary: JXConvertible where Key == String, Value: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Dictionary<Key, Value> {
        guard value.isObject else {
            throw JXErrors.valueNotObject
        }
        let jxDictionary = try value.dictionary
        return try jxDictionary.reduce(into: [:]) { result, entry in
            result[entry.key] = try Value.fromJX(entry.value)
        }
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        let jxDictionary = try self.reduce(into: [:]) { result, entry in
            result[entry.key] = try entry.value.toJX(in: context)
        }
        return try context.object(fromDictionary: jxDictionary)
    }
}

extension RawRepresentable where RawValue: JXConvertible {
    public static func fromJXRaw(_ value: JXValue) throws -> Self {
        guard let newSelf = Self(rawValue: try .fromJX(value)) else {
            throw JXErrors.invalidRawValue(try value.string)
        }
        return newSelf
    }

    public func toJXRaw(in context: JXContext) throws -> JXValue {
        try self.rawValue.toJX(in: context)
    }

    public static func fromJX(_ value: JXValue) throws -> Self {
        try fromJXRaw(value)
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        try toJXRaw(in: context)
    }
}

extension Bool: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { return value.bool }
    public func toJX(in context: JXContext) -> JXValue { context.boolean(self) }
}

extension String: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.string }
    public func toJX(in context: JXContext) -> JXValue { context.string(self) }
}

extension Int: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.int }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension Int32: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.int32 }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension Int64: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.int64 }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension UInt: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.uint }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension UInt32: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.uint32 }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension UInt64: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.uint64 }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension Double: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.double }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

extension Float: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.float }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}

#if canImport(CoreGraphics)
import typealias CoreGraphics.CGFloat

extension CGFloat: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.double }
    public func toJX(in context: JXContext) -> JXValue { context.number(self) }
}
#endif

#if canImport(Foundation)
import struct Foundation.Date

extension Date: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self { try value.date }
    public func toJX(in context: JXContext) throws -> JXValue { try context.date(self) }
}
#endif

#if canImport(Foundation)
import struct Foundation.Data

extension Data: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self {
//        if value.isArrayBuffer { // fast track
//            #warning("TODO: array buffer")
//            fatalError("array buffer") // TODO
//        } else
        if value.isArray { // slow track
            // copy the array manually
            let length = try value["length"]

            let count = try length.double
            guard length.isNumber, let max = UInt32(exactly: count) else {
                throw JXErrors.valueNotArray
            }

            let data: [UInt8] = try (0..<max).map { index in
                let element = try value[.init(index)]
                guard element.isNumber else {
                    throw JXErrors.valueNotNumber
                }
                let num = try element.double
                guard num <= .init(UInt8.max), num >= .init(UInt8.min), let byte = UInt8(exactly: num) else {
                    throw JXErrors.invalidNumericConversion(num)
                }

                return byte
            }

            return Data(data)
        } else {
            throw JXErrors.valueNotArray
        }
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        var d = self
        return try d.withUnsafeMutableBytes { bytes in
            try JXValue(newArrayBufferWithBytesNoCopy: bytes,
                deallocator: { _ in
                    //print("buffer deallocated")
                },
                in: context)
        }
    }
}
#endif
