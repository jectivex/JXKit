/// A descriptor for property’s definition.
public struct JXProperty {
    public let value: JXValue?
    public let writable: Bool?
    let _getter: JXValue?
    let _setter: JXValue?
    public let getter: ((JXValue) throws -> JXValue)?
    public let setter: ((JXValue, JXValue) throws -> Void)?
    public var configurable: Bool? = nil
    public var enumerable: Bool? = nil

    /// Generic descriptor.
    ///
    /// Contains one or both of the keys enumerable or configurable. Use a genetic descriptor to modify the attributes of an existing
    /// data or accessor property, or to create a new data property.
    public init() {
        self.value = nil
        self.writable = nil
        self._getter = nil
        self._setter = nil
        self.getter = nil
        self.setter = nil
    }

    /// Data descriptor.
    ///
    /// Contains one or both of the keys value and writable, and optionally also contains the keys enumerable or configurable. Use a
    /// data descriptor to create or modify the attributes of a data property on an object (replacing any existing accessor property).
    public init(value: JXValue? = nil, writable: Bool? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) {
        self.value = value
        self.writable = writable
        self._getter = nil
        self._setter = nil
        self.getter = nil
        self.setter = nil
        self.configurable = configurable
        self.enumerable = enumerable
    }

    /// Accessor descriptor.
    ///
    /// Contains one or both of the keys get or set, and optionally also contains the keys enumerable or configurable. Use an accessor
    /// descriptor to create or modify the attributes of an accessor property on an object (replacing any existing data property).
    ///
    /// ```
    /// let desc = JXProperty(
    ///     getter: { this in this["private_val"] },
    ///     setter: { this, newValue in this["private_val"] = newValue }
    /// )
    /// ```
    public init(getter: ((JXValue) throws -> JXValue)? = nil, setter: ((JXValue, JXValue) throws -> Void)? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) {
        self.value = nil
        self.writable = nil
        self._getter = nil
        self._setter = nil
        self.getter = getter
        self.setter = setter
        self.configurable = configurable
        self.enumerable = enumerable
    }

    /// Accessor descriptor.
    ///
    /// Contains one or both of the keys get or set, and optionally also contains the keys enumerable or configurable. Use an accessor
    /// descriptor to create or modify the attributes of an accessor property on an object (replacing any existing data property).
    public init(getter: JXValue? = nil, setter: JXValue? = nil, configurable: Bool? = nil, enumerable: Bool? = nil) throws {
        precondition(getter?.isFunction != false, "Invalid getter type")
        precondition(setter?.isFunction != false, "Invalid setter type")
        self.value = nil
        self.writable = nil
        self._getter = getter
        self._setter = setter
        self.getter = getter.map { getter in { this in try getter.call(withArguments: [], this: this) } }
        self.setter = setter.map { setter in { this, newValue in try setter.call(withArguments: [newValue], this: this) } }
        self.configurable = configurable
        self.enumerable = enumerable
    }
}

extension JXValue {

    /// Defines a property on the JavaScript object value or modifies a property’s definition.
    ///
    /// - Parameters:
    ///   - property: The property's key, which can either be a string or a symbol.
    ///   - descriptor: The descriptor object.
    /// - Returns: the key for the property that was defined
    public func defineProperty(_ property: JXValue, _ descriptor: JXProperty) throws {
        let desc = JXValue(newObjectIn: context)

        if let value = descriptor.value {
            try desc.setProperty("value", value)
        }

        if let writable = descriptor.writable {
            try desc.setProperty("writable", JXValue(bool: writable, in: context))
        }

        if let getter = descriptor._getter {
            try desc.setProperty("get", getter)
        } else if let getter = descriptor.getter {
            try desc.setProperty("get", JXValue(newFunctionIn: context) { _, this, _ in try getter(this!) })
        }

        if let setter = descriptor._setter {
            try desc.setProperty("set", setter)
        } else if let setter = descriptor.setter {
            try desc.setProperty("set", JXValue(newFunctionIn: context) { context, this, arguments in
                try setter(this!, arguments[0])
                return JXValue(undefinedIn: context)
            })
        }

        if let configurable = descriptor.configurable {
            try desc.setProperty("configurable", JXValue(bool: configurable, in: context))
        }

        if let enumerable = descriptor.enumerable {
            try desc.setProperty("enumerable", JXValue(bool: enumerable, in: context))
        }

        try context.objectPrototype.invokeMethod("defineProperty", withArguments: [self, property, desc])
    }

    public func propertyDescriptor(_ property: JXValue) throws -> JXValue {
        try context.objectPrototype.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, property])
    }
}
