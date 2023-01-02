/// An ordered collection of event listeners.
///
/// - Warning: Listeners are **strongly** held. This class should **not** be accessed concurrently.
public final class JXListenerCollection<T> {
    // Note: it would have been nice to use publishers for these events, but we want to minimize
    // dependency on Combine and we want to synchronously throw any listener errors
    private var listeners: [Int: T] = [:]
    private var keyGenerator = 0
    
    public init() {
    }
    
    /// Add a listener to receive events.
    ///
    /// - Returns: A ``JXCancellable`` you can use to stop receiving events, and which you must retain to continue to receive them.
    public func add(_ listener: T) -> JXCancellable {
        let key = keyGenerator
        keyGenerator += 1
        listeners[key] = listener
        return JXCancellable { [weak self] in self?.listeners[key] = nil }
    }
    
    /// Perform an operation on each listener.
    public func forEach(perform: (T) throws -> Void) rethrows {
        try listeners
            .sorted { $0.key < $1.key }
            .forEach { try perform($0.value) }
    }

    /// Whether there are no listeners.
    public var isEmpty: Bool {
        return listeners.isEmpty
    }
}
