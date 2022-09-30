import class Foundation.Bundle
import class Foundation.NSDictionary

// This class supports extracting the version information of the runtime.

// MARK: JXKit Module Metadata

/// The bundle for the `JXKit` module.
public let JXKitBundle = Foundation.Bundle.module

/// The information plist for the `JXKit` module, which is stored in `Resources/JXKit.plist` (until SPM supports `Info.plist`).
private let JXKitPlist = JXKitBundle.url(forResource: "JXKit", withExtension: "plist")!

/// The info dictionary for the `JXKit` module.
public let JXKitInfo = NSDictionary(contentsOf: JXKitPlist)

/// The bundle identifier of the `JXKit` module as specified by the `CFBundleIdentifier` of the `JXKitInfo`.
public let JXKitBundleIdentifier: String! = JXKitInfo?["CFBundleIdentifier"] as? String

/// The version of the `JXKit` module as specified by the `CFBundleShortVersionString` of the `JXKitInfo`.
public let JXKitVersion: String! = JXKitInfo?["CFBundleShortVersionString"] as? String

/// The version components of the `CFBundleShortVersionString` of the `JXKitInfo`, such as `[0, 0, 1]` for "0.0.1" ` or `[1, 2]` for "1.2"
private let JXKitV = { JXKitVersion.components(separatedBy: .decimalDigits.inverted).compactMap({ Int($0) }).dropFirst($0).first }

/// The major, minor, and patch version components of the `JXKit` module's `CFBundleShortVersionString`
public let (JXKitVersionMajor, JXKitVersionMinor, JXKitVersionPatch) = (JXKitV(0), JXKitV(1), JXKitV(2))

/// A comparable representation of ``JXKitVersion``, which can be used for comparing known versions and sorting via semver semantics.
///
/// The form of the number is `(major*1M)+(minor*1K)+patch`, so version "1.2.3" becomes `001_002_003`.
/// Caveat: any minor or patch version components over `999` will break the comparison expectation.
public let JXKitVersionNumber = ((JXKitVersionMajor ?? 0) * 1_000_000) + ((JXKitVersionMinor ?? 0) * 1_000) + (JXKitVersionPatch ?? 0)
