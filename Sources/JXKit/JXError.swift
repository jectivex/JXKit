/// An error thrown from JXKit.
public struct JXError: Error, CustomStringConvertible, @unchecked Sendable {
    public var message: String
    public var cause: Error?
    public var jsErrorString: String?
    public var script: String?
    
    public init(message: String, script: String? = nil) {
        self.message = message
        self.script = script
    }
    
    public init(jsError: JXValue, script: String? = nil) {
        if let cause = jsError.cause {
            self.init(cause: cause, script: script)
        } else {
            self.init(message: jsError.description, script: script)
        }
    }
    
    public init(cause: Error, script: String? = nil) {
        if let jxerror = cause as? JXError {
            self = jxerror
            if let script {
                self.script = script
            }
        } else {
            self.init(message: String(describing: cause), script: script)
            self.cause = cause
        }
    }
    
    public var localizedDescription: String {
        return description
    }
    
    public var description: String {
        return message + scriptDescription
    }
    
    private var scriptDescription: String {
        let prefixLength = 256
        guard let script = self.script, !script.isEmpty else {
            return ""
        }
        return script.count > prefixLength ? " <<script: \(script.prefix(prefixLength))... >>" : " <<script: \(script) >>"
    }
    
    @inlinable public static func internalError(_ message: String) -> JXError {
        return JXError(message: "Internal error: \(message)")
    }
    
    @inlinable public static func valueNotArray(_ value: JXValue) -> JXError {
        return JXError(message: "Expected a JavaScript array but received '\(value)'")
    }
    
    @inlinable public static func valueNotObject(_ value: JXValue) -> JXError {
        return JXError(message: "Expected a JavaScript object but received '\(value)'")
    }
    
    @inlinable public static func valueNotPropertiesObject(_ value: JXValue, property: String) -> JXError {
        return JXError(message: "Attempt to accesss property '\(property)' on JavaScript value '\(value)'. This value is not an object")
    }
    
    @inlinable public static func valueNotDate(_ value: JXValue) -> JXError {
        return JXError(message: "Expected a JavaScript date but received '\(value)'")
    }
    
    @inlinable public static func valueNotFunction(_ value: JXValue) -> JXError {
        return JXError(message: "Expected a JavaScript function but received '\(value)'")
    }
    
    @inlinable public static func valueNotSymbol(_ value: JXValue) -> JXError {
        return JXError(message: "Expected a JavaScript symbol but received '\(value)'")
    }
    
    @inlinable static func asyncEvalMustReturnPromise(_ value: JXValue) -> JXError {
        return JXError(message: "The JavaScript supplied to 'JXContext.eval(...) async' must return a Promise. Returned '\(value)")
    }
    
    @inlinable static func invalidNumericConversion(_ value: JXValue, to number: Double) -> JXError {
        return JXError(message: "JavaScript value '\(value)' converted to invalid number '\(number)'")
    }
    
    @inlinable static func cannotConvey(_ type: Any.Type, spi: JXContextSPI?, format: String) -> JXError {
        let typeString = String(describing: type)
        var message = String(format: format, typeString)
        if let detail = spi?.errorDetail(conveying: type) {
            message = "\(message). \(detail)"
        }
        return JXError(message: message)
    }
    
    @inlinable static func cannotCreatePromise() -> JXError {
        return JXError(message: "Unable to create JavaScript Promise")
    }
    
    @inlinable static func cannotCreateArrayBuffer() -> JXError {
        return JXError(message: "Unable to create JavaScript array buffer")
    }
}

/// Used internally to piggyback a native error as the peer of its wrapping JXValue error object.
class JXErrorPeer {
    let error: Error
    
    init(error: Error) {
        self.error = error
    }
}
