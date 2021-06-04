
/// A function definition, used when defining callbacks.
public typealias JXFunction = (JXContext, JXValue?, [JXValue]) throws -> JXValue


extension JXValue {
    /// Creates a JavaScript value of the function type.
    ///
    /// - Parameters:
    ///   - context: The execution context to use.
    ///   - callback: The callback function.
    ///
    /// - Note: This object is callable as a function (due to `JSClassDefinition.callAsFunction`), but the JavaScript runtime doesn't treat is exactly like a function. For example, you cannot call "apply" on it. It could be better to use `JSObjectMakeFunctionWithCallback`, which may act more like a "true" JavaScript function.
    public convenience init(newFunctionIn env: JXContext, callback: @escaping JXFunction) {

        let info: UnsafeMutablePointer<JSObjectCallbackInfo> = .allocate(capacity: 1)
        info.initialize(to: JSObjectCallbackInfo(context: env, callback: callback))

        var def = JSClassDefinition()
        def.finalize = function_finalize
        def.callAsConstructor = function_constructor
        def.callAsFunction = function_callback
        def.hasInstance = function_instanceof

        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }

        self.init(env: env, value: JSObjectMake(env.context, _class, info))
    }
}
private struct JSObjectCallbackInfo {
    unowned let context: JXContext

    let callback: JXFunction
}

private func function_finalize(_ object: JSObjectRef?) -> Void {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSObjectCallbackInfo.self)

    info.deinitialize(count: 1)
    info.deallocate()
}

private func function_constructor(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSObjectRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSObjectCallbackInfo.self)
    let env = info.pointee.context

    do {
        let arguments = (0..<argumentCount).map { JXValue(env: env, value: arguments![$0]!) }
        let result = try info.pointee.callback(env, nil, arguments)

        let prototype = JSObjectGetPrototype(env.context, object)
        JSObjectSetPrototype(env.context, result.value, prototype)

        return result.value
    } catch let error {
        let error = error as? JXValue ?? JXValue(newErrorFromMessage: "\(error)", in: env)
        exception?.pointee = error.value
        return nil
    }
}

private func function_callback(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ this: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSObjectCallbackInfo.self)
    let env = info.pointee.context

    do {

        let this = this.map { JXValue(env: env, value: $0) }
        let arguments = (0..<argumentCount).map { JXValue(env: env, value: arguments![$0]!) }
        let result = try info.pointee.callback(env, this, arguments)

        return result.value

    } catch let error {

        let error = error as? JXValue ?? JXValue(newErrorFromMessage: "\(error)", in: env)
        exception?.pointee = error.value

        return nil
    }
}

private func function_instanceof(
    _ ctx: JSContextRef?,
    _ constructor: JSObjectRef?,
    _ possibleInstance: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {

    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JSObjectCallbackInfo.self)

    let env = info.pointee.context

    let prototype_0 = JSObjectGetPrototype(env.context, constructor)
    let prototype_1 = JSObjectGetPrototype(env.context, possibleInstance)

    return JSValueIsStrictEqual(env.context, prototype_0, prototype_1)
}


