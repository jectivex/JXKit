/// Type similar to `Combine.Cancellable` that is used to cancel subscriptions to events.
public class JXCancellable {
    let cancelHandler: () -> Void
    
    init(cancel: @escaping () -> Void) {
        self.cancelHandler = cancel
    }
    
    deinit {
        cancel()
    }
    
    /// Cancel the associated event subscription.
    public func cancel() {
        cancelHandler()
    }
}
