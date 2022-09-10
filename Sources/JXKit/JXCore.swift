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

public protocol JXEnv : AnyObject {
    var context: JSGlobalContextRef { get }
}

// MARK: JXContextGroup / JSVirtualMachine

/// A JavaScript virtual machine that is used by a `JXContextGroup` instance.
///
/// `JXValue` references may be used interchangably with separate `JXContext`  instances that created from the same `JXContextGroup`, but sharing between  different `JXContextGroup`s will result in undefined behavior.
///
/// - Note: This wraps a `JSContextGroupRef`, and is the equivalent of `JavaScriptCore.JSVirtualMachine`
@available(macOS 11, iOS 13, tvOS 13, *)
public final class JXContextGroup {
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
    
    public func env() -> JXContext {
        JXContext(group: self)
    }
}


public typealias JXContextRef = JSContextRef

/// The underlying type that represents a value in the JavaScript environment
public typealias JXValueRef = JSValueRef

/// The underlying type that represents a string in the JavaScript environment
public typealias JXStringRef = JSStringRef


/// Work-in-progress, simply to highlight a line with a deprecation warning
@available(*, deprecated, message: "work-in-progress")
@usableFromInline internal func wip<T>(_ value: T) -> T { value }
