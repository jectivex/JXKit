#if canImport(Foundation)
import Foundation
#endif
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

/// A JavaScript virtual machine that is used by a `JXContextGroup` instance.
///
/// `JXValue` references may be used interchangably with separate `JXContext`  instances that created from the same `JXContextGroup`, but sharing between  different `JXContextGroup`s will result in undefined behavior.
///
/// - Note: This wraps a `JSContextGroupRef`, and is the equivalent of `JavaScriptCore.JSVirtualMachine`
public final class JXVM {
    @usableFromInline let groupRef: JSContextGroupRef

    public init() {
        self.groupRef = JSContextGroupCreate()
    }

    public init(groupRef: JSContextGroupRef) {
        self.groupRef = groupRef
        JSContextGroupRetain(groupRef)
    }

    deinit {
        JSContextGroupRelease(groupRef)
    }
}

#if canImport(Foundation)
extension JXVM {
    /// Whether the `JavaScriptCore` implementation on the current platform phohibits writable and executable memory (`mmap(MAP_JIT)`), thereby disabling the fast-path of the JavaScriptCore framework.
    ///
    /// Without the Allow Execution of JIT-compiled Code Entitlement, frameworks that rely on just-in-time (JIT) compilation will fall back to an interpreter.
    ///
    /// To add the entitlement to your app, first enable the Hardened Runtime capability in Xcode, and then under Runtime Exceptions, select Allow Execution of JIT-compiled Code.
    ///
    /// See: [Allow Execution of JIT-compiled Code Entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_cs_allow-jit)
    public static let isHobbled: Bool = {
        // We could check for the hardened runtime's "com.apple.security.cs.allow-jit" property, but it is easier to just attempt to mmap PROT_WRITE|PROT_EXEC and see if it was successful

        let ptr = mmap(nil, Int(getpagesize()), PROT_WRITE|PROT_EXEC, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
        if ptr == MAP_FAILED {
            return true // JIT forbidden
        } else {
            munmap(ptr, Int(getpagesize()))
            return false
        }
    }()
}
#endif
