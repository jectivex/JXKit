#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

#if canImport(MachO)
// TODO: how to implement this on Linux?
import func MachO.NSVersionOfRunTimeLibrary
/// The runtime version of JavaScript core (e.g., `40239623`).
public let JavaScriptCoreVersion = NSVersionOfRunTimeLibrary("JavaScriptCore")
#endif

/// The underlying type that represents a value in the JavaScript environment.
public typealias JXValueRef = JSValueRef

typealias JXContextRef = JSContextRef

/// The underlying type that represents a string in the JavaScript environment.
typealias JXStringRef = JSStringRef
