import class Foundation.Bundle
import class Foundation.FileManager
import struct Foundation.URL

extension JXEnv {

    /// Runs a script in the standard bundle module location `"Resources/JavaScript"`.
    ///
    /// - Parameters:
    ///   - name: the name of the script to run (not including the ".js" extension)
    ///   - bundle: the bundle from which the load the script (typically `Bundle.module` for a Swift package)
    /// - Throws: an error if the script could not be located or if an error occured when running
    ///
    /// Example:
    ///
    /// ```swift
    /// /// Installs the `esprima` module used by `JavaScriptParser`.
    /// /// This will execute the bundle's `Resources/esprima.js` resource.
    /// public func installJavaScriptParser() throws {
    ///     try installModule(named: "esprima", in: .module)
    /// }
    /// ```
    public func installModule(named name: String, in bundle: @autoclosure () -> Bundle, file sourceFilePathRelativeToResources: String = #file) throws -> JXValType {
        guard let url = Bundle.moduleResource(named: name, withExtension: "js", in: bundle(), file: sourceFilePathRelativeToResources) else {
            throw JXContext.Errors.missingResource(name)
        }

        return try eval(url: url)
    }
}

extension Bundle {
    /// Returns the resource bundle associated with the current Swift module.
    ///
    /// Works around the [SR-12912](https://bugs.swift.org/browse/SR-12912) crash when loading an embedded SPM bundle.
    ///
    /// ## Example Usage
    ///
    /// ```
    /// Bundle.moduleResource(named: "myscript", withExtension: "js", in: .module)
    /// ```
    ///
    /// ## Implementation Details
    ///
    /// This works around a crash that happens in the generated `Bundle.module` code in Swift 5.3-5.5 when the bundle is not embedded in the executable's path. It will attempt to load the resource relative to the underlying source file, and fall back to accessing the `Bundle.module` code if it is not found.
    ///
    /// - https://bugs.swift.org/browse/SR-12912
    /// - https://forums.swift.org/t/swift-5-3-spm-resources-in-tests-uses-wrong-bundle-path/37051/2
    ///
    /// - TODO: @available(*, deprecated, renamed: "module")
    public static func moduleResource(named path: String, withExtension ext: String, subdirectory subpath: String? = nil, in bundle: @autoclosure () -> Bundle, file sourceFilePathRelativeToResources: String = #file) -> URL? {
        var dir = URL(fileURLWithPath: sourceFilePathRelativeToResources) // "Resources/" is usually a peer of the "Sources/" folder
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)

        if let subpath = subpath {
            dir = dir.appendingPathComponent(subpath)
        }
        let resourceURL = dir
            .appendingPathComponent(path)
            .appendingPathExtension(ext)

        if FileManager.default.isReadableFile(atPath: resourceURL.path) {
            return resourceURL
        }

        // no source files available; fall back to checking the bundle module
        // note that this will crash when afflicted by SR-12912, which is why it is an autoclosure
        return bundle().url(forResource: path, withExtension: ext)
    }
}
