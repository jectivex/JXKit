

// MARK: JXKit.JXContext : JXEnv

/// A reference type that a wraps `JSGlobalContextRef`.
///
/// - Note: This protocol is implemented by both `JXKit.JXContext` and `JavaScriptCore.JSContext` to enable migration & inter-operability between the frameworks.
public protocol JavaScriptCoreContext : AnyObject {
    /// The JavaScriptCore's underlying context
    var context: JSContextRef { get }
}

/// `JXContext.context` already exists, so conformance is automatic
extension JXContext : JavaScriptCoreContext { }


extension JXContext : JXEnv {
    public func null() -> JXValue {
        JXValue(nullIn: self)
    }

    public func undefined() -> JXValue {
        JXValue(undefinedIn: self)
    }

    public func number<F: BinaryFloatingPoint>(_ value: F) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    public func number<I: BinaryInteger>(_ value: I) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    public func string<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(string: String(value), in: self)
    }

    public func date(_ value: Date) -> JXValue {
        JXValue(date: value, in: self)
    }

    public func data<D: DataProtocol>(_ value: D) -> JXValue {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            return JXValue(newArrayBufferWithBytes: value, in: self)
        } else {
            return undefined()
        }
    }
}

extension JXValue : JXVal {
}



/// Shim for supporting `JXKit` functionality in the `JSContext` & `JSValue` classes on Objective-C-suppored platforms
#if canImport(JavaScriptCore)

// MARK: JavaScriptCore.JSContext : JXEnv

import JavaScriptCore

extension JSContext : JavaScriptCoreContext {
    /// `JSContext.context` is the `jsGlobalContextRef` value
    public var context: JSGlobalContextRef { jsGlobalContextRef }
}

/// Support for `JXEnv` in `JavaScriptCore`. Useful for porting from `JavaScriptCore` to `JXCore`
extension JSContext : JXEnv {
    public typealias ValType = JSValue

    /// The current global object
    public var global: JSValue { globalObject }

    /// For some reason, `JXEnv.exception: JSValue?` doesn't line up with `JSContext.exception: JSValue?`, so we need to pass it through.
    public var currentError: JSValue? {
        get { self.exception }
        set { self.exception = newValue }
    }

    public func eval(this: JXValue?, url: URL?, script: String) throws -> JSValue {
        try trying {
            // TODO: set the current `this`
            evaluateScript(script, withSourceURL: url)
        }
    }

    /// Pass-through for `objectForKeyedSubscript` and `setObject(_:forKeyedSubscript:)`
    public subscript(property: String) -> JSValue {
        get { self.objectForKeyedSubscript(property as NSString) }
        set { self.setObject(newValue, forKeyedSubscript: property as NSString) }
    }

    public func null() -> JSValue {
        JSValue(nullIn: self)
    }

    public func undefined() -> JSValue {
        JSValue(undefinedIn: self)
    }

    public func number<F>(_ value: F) -> JSValue where F : BinaryFloatingPoint {
        JSValue(double: Double(value), in: self)
    }

    public func number<I>(_ value: I) -> JSValue where I : BinaryInteger {
        JSValue(double: Double(value), in: self)
    }

    public func string<S>(_ value: S) -> JSValue where S : StringProtocol {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        return JSValue(jsValueRef: JSValueMakeString(jsGlobalContextRef, value), in: self)
    }

    @available(*, deprecated, message: "not yet implemented")
    public func data<D>(_ value: D) -> JSValue where D : DataProtocol {
        wip(undefined()) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public func date(_ value: Date) -> JSValue {
        wip(undefined()) // TODO
    }
}

/// Support for `JXVal` in `JavaScriptCore`. Useful for porting from `JavaScriptCore` to `JXCore`
extension JSValue : JXVal {
    public typealias EnvType = JSContext

    public var env: JSContext {
        self.context // `JSValue.context` has a `JSContext!` type
    }


    @available(*, deprecated, message: "not yet implemented")
    public subscript(property: String) -> JSValue {
        get {
            wip(env.undefined())
        }

        set {
        }
    }

    @available(*, deprecated, message: "not yet implemented")
    public var stringValue: String? {
        wip(nil) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public var properties: [String] {
        wip([]) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public func hasProperty(_ value: String) -> Bool {
        wip(false) // TODO
    }
}
#endif

