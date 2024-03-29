import Foundation

/// Load JavaScript files.
public protocol JXScriptLoader {
    /// Return a non-nil listener collection to indicate that dynamic reloading is supported in this environment.
    var didChange: JXListenerCollection<(Set<URL>) -> Void>? { get }
    
    /// Return the URL for the given script resource.
    func scriptURL(resource: String, relativeTo: URL?, root: URL) throws -> URL
    
    /// Load the script from the given URL.
    func loadScript(from url: URL) throws -> String?
}

extension JXScriptLoader {
    public var didChange: JXListenerCollection<(Set<URL>) -> Void>? {
        return nil
    }
    
    public func scriptURL(resource: String, relativeTo: URL?, root: URL) throws -> URL {
        return try defaultScriptURL(resource: resource, relativeTo: relativeTo, root: root)
    }

    public func loadScript(from url: URL) throws -> String? {
        return try defaultLoadScript(from: url).script
    }
    
    public func defaultScriptURL(resource: String, relativeTo: URL?, root: URL) throws -> URL {
        if resource.hasPrefix("/") {
            return root.appendingPathComponent(String(resource.dropFirst()), isDirectory: false).standardized
        } else if let relativeTo {
            return relativeTo.deletingLastPathComponent().appendingPathComponent(resource, isDirectory: false).standardized
        } else {
            throw JXError.unknownScriptRelativeTo(for: resource)
        }
    }
    
    public func defaultLoadScript(from url: URL) throws -> (url: URL, script: String) {
        do {
            let script = try String(contentsOf: url)
            return (url, script)
        } catch {
            let urlError = error
            if url.pathExtension.isEmpty {
                let jsURL = url.appendingPathExtension("js")
                do {
                    let script = try String(contentsOf: jsURL)
                    return (jsURL, script)
                } catch {
                    throw urlError
                }
            } else {
                throw urlError
            }
        }
    }
}

/// Internal default implementation.
struct DefaultScriptLoader: JXScriptLoader {
}
