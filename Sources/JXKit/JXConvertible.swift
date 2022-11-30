import Foundation

/// A type that can move back and forth between Swift and JavaScipt, either through direct reference or by serialization.
public protocol JXConvertible {
    /// Converts a `JXValue` into this type.
    static func fromJX(_ value: JXValue) throws -> Self

    /// Converts this value into a JXContext.
    func toJX(in context: JXContext) throws -> JXValue
}

extension Decodable where Self: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self {
        try value.toDecodable(ofType: Self.self)
    }
}

extension Encodable where Self: JXConvertible {
    public func toJX(in context: JXContext) throws -> JXValue {
        try context.encode(self)
    }
}

extension JXValue: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self {
        guard let value = value as? Self else {
            throw JXErrors.jumpContextInvalid
        }
        return value
    }

    public func toJX(in context: JXContext) -> JXValue {
        self
    }
}

extension Optional: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self {
        guard !value.isNull else {
            return .none
        }
        return .some(try value.convey(to: Wrapped.self))
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        switch self {
        case .none:
            return context.null()
        case .some(let value):
            return try context.convey(value)
        }
    }
}

extension Array: JXConvertible {
    public static func fromJX(_ value: JXValue) throws -> Self {
        guard value.isArray else {
            throw JXErrors.valueNotArray
        }
        let arrayValue = try value.array
        return try arrayValue.map({ jx in
            try jx.convey(to: Element.self)
        })
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        try context.array(self.map({ x in
            try context.convey(x)
        }))
    }
}

extension Dictionary: JXConvertible where Key == String {
    public static func fromJX(_ value: JXValue) throws -> Dictionary<Key, Value> {
        guard value.isObject else {
            throw JXErrors.valueNotObject
        }
        let jxDictionary = try value.dictionary
        return try jxDictionary.reduce(into: [:]) { result, entry in
            result[entry.key] = try entry.value.convey(to: Value.self)
        }
    }

    public func toJX(in context: JXContext) throws -> JXValue {
        let jxDictionary = try self.reduce(into: [:]) { result, entry in
            result[entry.key] = try context.convey(entry.value)
        }
        return try context.object(fromDictionary: jxDictionary)
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
