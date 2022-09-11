//
//  JavaScript execution context & value types.
//
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

// MARK: Virtual Machine

/// A JavaScript virtual machine that is used by a `JXContextGroup` instance.
///
/// `JXValue` references may be used interchangably with separate `JXContext`  instances that created from the same `JXContextGroup`, but sharing between  different `JXContextGroup`s will result in undefined behavior.
///
/// - Note: This wraps a `JSContextGroupRef`, and is the equivalent of `JavaScriptCore.JSVirtualMachine`
@available(macOS 11, iOS 13, tvOS 13, *)
public final class JXVM {
    @usableFromInline let group: JSContextGroupRef

    public init() {
        self.group = JSContextGroupCreate()
    }

    public init(group: JSContextGroupRef) {
        self.group = group
        JSContextGroupRetain(group)
    }

    deinit {
        JSContextGroupRelease(group)
    }
}

@available(macOS 11, iOS 13, tvOS 13, *)
extension JXVM {
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

/// The underlying type that represents a value in the JavaScript environment
@usableFromInline internal typealias JXValueRef = JSValueRef

@usableFromInline internal typealias JXContextRef = JSContextRef

/// The underlying type that represents a string in the JavaScript environment
@usableFromInline internal typealias JXStringRef = JSStringRef

/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
@usableFromInline internal func wip<T>(_ value: T) -> T { value }

