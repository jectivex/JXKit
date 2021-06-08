
import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif


// MARK: JXKit.JXContext : JXEnv

/// A reference type that a wraps `JSGlobalContextRef`.
///
/// - Note: This protocol is implemented by both `JXKit.JXContext` and `JavaScriptCore.JSContext` to enable migration & inter-operability between the frameworks.
public protocol JSCEnv : JXEnv {
    /// The JavaScriptCore's underlying context
    var context: JSContextRef { get }
}

/// `JXContext.context` already exists, so conformance is automatic
extension JXContext : JSCEnv {
    /// Whether the `JavaScriptCore` implementation on the current platform phohibits writable and executable memory (`mmap(MAP_JIT)`), thereby disabling the fast-path of the JavaScriptCore framework.
    ///
    /// Without the Allow Execution of JIT-compiled Code Entitlement, frameworks that rely on just-in-time (JIT) compilation will fall back to an interpreter.
    ///
    /// To add the entitlement to your app, first enable the Hardened Runtime capability in Xcode, and then under Runtime Exceptions, select Allow Execution of JIT-compiled Code.
    ///
    /// See: [Allow Execution of JIT-compiled Code Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_cs_allow-jit)
    public static let isHobbled: Bool = {
        // we could check for the hardened runtime's "com.apple.security.cs.allow-jit" property, but it is easier to just attempt to mmap PROT_WRITE|PROT_EXEC and see if it was successful

        let ptr = mmap(nil, Int(getpagesize()), PROT_WRITE|PROT_EXEC, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        if ptr == MAP_FAILED {
            return true // JIT forbidden
        } else {
            munmap(ptr, Int(getpagesize()))
            return false
        }
    }()

}


extension JXContextGroup : JXVM {
    public func env() -> JXContext {
        JXContext(group: self)
    }
}


extension JXValue : JXVal {
}

extension JXContext : JXEnv {
    @inlinable public func null() -> JXValue {
        JXValue(nullIn: self)
    }

    @inlinable public func undefined() -> JXValue {
        JXValue(undefinedIn: self)
    }

    @inlinable public func boolean(_ value: Bool) -> JXValue {
        JXValue(bool: value, in: self)
    }

    @inlinable public func number<F: BinaryFloatingPoint>(_ value: F) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    @inlinable public func number<I: BinaryInteger>(_ value: I) -> JXValue {
        JXValue(double: Double(value), in: self)
    }

    @inlinable public func string<S: StringProtocol>(_ value: S) -> JXValue {
        JXValue(string: String(value), in: self)
    }

    @inlinable public func object() -> JXValue {
        JXValue(newObjectIn: self)
    }

    /// Creates a new array in the environment
    @inlinable public func array(_ values: [JXValue]) -> JXValue {
        let array = JXValue(newArrayIn: self)
        for (index, value) in values.enumerated() {
            array[index] = value
        }
        return array
    }


    @inlinable public func date(_ value: Date) -> JXValue {
        JXValue(date: value, in: self)
    }

    @inlinable public func data<D: DataProtocol>(_ value: D) -> JXValue {
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
            return JXValue(newArrayBufferWithBytes: value, in: self)
        } else {
            return undefined()
        }
    }
}


/// Shim for supporting `JXKit` functionality in the `JSContext` & `JSValue` classes on Objective-C-suppored platforms
#if canImport(JavaScriptCore)

// MARK: JavaScriptCore.JSContext : JXEnv

import JavaScriptCore


extension JSVirtualMachine : JXVM {
    public func env() -> JSContext {
        JSContext(virtualMachine: self)
    }
}

extension JSContext : JSCEnv {
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

    public func boolean(_ value: Bool) -> JSValue {
        JSValue(bool: value, in: self)
    }

    public func number<F : BinaryFloatingPoint>(_ value: F) -> JSValue {
        JSValue(double: Double(value), in: self)
    }

    public func number<I : BinaryInteger>(_ value: I) -> JSValue {
        JSValue(double: Double(value), in: self)
    }

    public func string<S : StringProtocol>(_ value: S) -> JSValue {
        let value = value.withCString(JSStringCreateWithUTF8CString)
        defer { JSStringRelease(value) }
        return JSValue(jsValueRef: JSValueMakeString(jsGlobalContextRef, value), in: self)
    }

    @inlinable public func object() -> JSValue {
        return JSValue(newObjectIn: self)
    }

    @inlinable public func array(_ values: [JSValue]) -> JSValue {
        guard let array = JSValue(newArrayIn: self) else { return undefined() }
        for (index, value) in values.enumerated() {
            array.setObject(value, atIndexedSubscript: index)
        }
        return array
    }

    @available(*, deprecated, message: "not yet implemented")
    public func data<D: DataProtocol>(_ value: D) -> JSValue {
        wip(undefined()) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public func date(_ value: Date) -> JSValue {
        wip(undefined()) // TODO
    }
}

extension JXContext {
    /// Converts between `JXKit.JXContext` and `JavaScriptCore.JSContext`
    var asJSContext: JSContext {
        JSContext(jsGlobalContextRef: self.context)
    }
}

extension JXValue {
    /// Converts between `JXKit.JXValue` and `JavaScriptCore.JSValue`
    var asJSValue: JSValue {
        JSValue(jsValueRef: self.value, in: self.env.asJSContext)
    }
}

extension JSContext {
    /// Converts between `JXKit.JXContext` and `JavaScriptCore.JSContext`
    var asJXContext: JXContext {
        JXContext(context: self.context)
    }
}

extension JSValue {
    /// Converts between `JXKit.JXValue` and `JavaScriptCore.JSValue`
    var asJXValue: JXValue {
        JXValue(env: env.asJXContext, value: jsValueRef)
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

    /// Returns the JavaScript boolean value.
    @inlinable public var booleanValue: Bool {
        return JSValueToBoolean(env.context, jsValueRef)
    }

    @inlinable public var isArray: Bool {
        let result = env.arrayPrototype.invokeMethod("isArray", withArguments: [self])
        return JSValueToBoolean(env.context, result?.jsValueRef)
    }

    /// Returns the JavaScript number value.
    @inlinable public var numberValue: Double? {
        var exception: JSObjectRef?
        let result = JSValueToNumber(env.context, jsValueRef, &exception)
        return exception == nil ? result : nil
    }

    /// Returns the JavaScript string value.
    @inlinable public var stringValue: String? {
        let str = JSValueToStringCopy(env.context, jsValueRef, nil)
        defer { str.map(JSStringRelease) }
        return str.map(String.init)
    }

    /// Returns the JavaScript date value.
    @inlinable public var dateValue: Date? {
        let result = self.invokeMethod("toISOString", withArguments: [])
        return result?.stringValue.flatMap { JXValue.rfc3339.date(from: $0) }
    }

    @available(*, deprecated, message: "not yet implemented")
    public var properties: [String] {
        wip([]) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public func hasProperty(_ value: String) -> Bool {
        wip(false) // TODO
    }

    public var isDate: Bool {
        return self.isInstance(of: env.datePrototype)
    }

    @available(*, deprecated, message: "not yet implemented")
    public var array: [JSValue]? {
        wip(nil) // TODO
    }

    @available(*, deprecated, message: "not yet implemented")
    public var dictionary: [String : JSValue]? {
        wip(nil) // TODO
    }

    public var isBoolean: Bool {
        JSValueIsBoolean(env.context, jsValueRef)
    }

    public var isFunction: Bool {
        return isObject && JSObjectIsFunction(env.context, jsValueRef)
    }

    @available(*, deprecated, message: "not yet implemented")
    public func call(withArguments arguments: [JSValue], this: JSValue?) -> JSValue {
        wip(env.undefined()) // TODO
    }

}
#endif


/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
fileprivate func wip<T>(_ value: T) -> T { value }
