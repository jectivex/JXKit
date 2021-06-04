
/// A descriptor for property’s definition
public struct JXProp {
    public let value: JXValue?
    public let writable: Bool?
    fileprivate let _getter: JXValue?
    fileprivate let _setter: JXValue?
    public let getter: ((JXValue) throws -> JXValue)?
    public let setter: ((JXValue, JXValue) throws -> Void)?
    public var configurable: Bool? = nil
    public var enumerable: Bool? = nil

    /// Generic Descriptor
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

    /// Data Descriptor
    ///
    /// Contains one or both of the keys value and writable, and optionally also contains the keys enumerable or configurable. Use a
    /// data descriptor to create or modify the attributes of a data property on an object (replacing any existing accessor property).
    public init(
        value: JXValue? = nil,
        writable: Bool? = nil,
        configurable: Bool? = nil,
        enumerable: Bool? = nil
    ) {
        self.value = value
        self.writable = writable
        self._getter = nil
        self._setter = nil
        self.getter = nil
        self.setter = nil
        self.configurable = configurable
        self.enumerable = enumerable
    }

    /// Accessor Descriptor
    ///
    /// Contains one or both of the keys get or set, and optionally also contains the keys enumerable or configurable. Use an accessor
    /// descriptor to create or modify the attributes of an accessor property on an object (replacing any existing data property).
    ///
    /// ```
    /// let desc = JXProp(
    ///     getter: { this in this["private_val"] },
    ///     setter: { this, newValue in this["private_val"] = newValue }
    /// )
    /// ```
    public init(
        getter: ((JXValue) -> JXValue)? = nil,
        setter: ((JXValue, JXValue) -> Void)? = nil,
        configurable: Bool? = nil,
        enumerable: Bool? = nil
    ) {
        self.value = nil
        self.writable = nil
        self._getter = nil
        self._setter = nil
        self.getter = getter
        self.setter = setter
        self.configurable = configurable
        self.enumerable = enumerable
    }

    /// Accessor Descriptor
    ///
    /// Contains one or both of the keys get or set, and optionally also contains the keys enumerable or configurable. Use an accessor
    /// descriptor to create or modify the attributes of an accessor property on an object (replacing any existing data property).
    public init(
        getter: JXValue? = nil,
        setter: JXValue? = nil,
        configurable: Bool? = nil,
        enumerable: Bool? = nil
    ) {
        precondition(getter?.isFunction != false, "Invalid getter type")
        precondition(setter?.isFunction != false, "Invalid setter type")
        self.value = nil
        self.writable = nil
        self._getter = getter
        self._setter = setter
        self.getter = getter.map { getter in { this in getter.call(withArguments: [], this: this) } }
        self.setter = setter.map { setter in { this, newValue in setter.call(withArguments: [newValue], this: this) } }
        self.configurable = configurable
        self.enumerable = enumerable
    }
}

extension JXValue {

    /// Defines a property on the JavaScript object value or modifies a property’s definition.
    ///
    /// - Parameters:
    ///   - property: The property's name.
    ///   - descriptor: The descriptor object.
    ///
    /// - Returns: true if the operation succeeds, otherwise false.
    @discardableResult
    public func defineProperty(_ property: String, _ descriptor: JXProp) -> Bool {

        let desc = JXValue(newObjectIn: env)

        if let value = descriptor.value { desc["value"] = value }
        if let writable = descriptor.writable { desc["writable"] = JXValue(bool: writable, in: env) }
        if let getter = descriptor._getter {
            desc["get"] = getter
        } else if let getter = descriptor.getter {
            desc["get"] = JXValue(newFunctionIn: env) { _, this, _ in try getter(this!) }
        }
        if let setter = descriptor._setter {
            desc["set"] = setter
        } else if let setter = descriptor.setter {
            desc["set"] = JXValue(newFunctionIn: env) { context, this, arguments in
                try setter(this!, arguments[0])
                return JXValue(undefinedIn: context)
            }
        }
        if let configurable = descriptor.configurable { desc["configurable"] = JXValue(bool: configurable, in: env) }
        if let enumerable = descriptor.enumerable { desc["enumerable"] = JXValue(bool: enumerable, in: env) }

        env.objectPrototype.invokeMethod("defineProperty", withArguments: [self, JXValue(string: property, in: env), desc])

        return env.currentError == nil
    }

    public func propertyDescriptor(_ property: String) -> JXValue {
        return env.objectPrototype.invokeMethod("getOwnPropertyDescriptor", withArguments: [self, JXValue(string: property, in: env)])
    }
}
