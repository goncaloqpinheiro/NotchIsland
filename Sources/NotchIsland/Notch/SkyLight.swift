import Foundation

/// Loads functions from the private SkyLight framework (the window server's
/// client library). Every lookup is optional, so a macOS update that removes a
/// function turns the feature off instead of crashing.
enum SkyLight {
    private static let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)

    static func function<T>(_ name: String, as type: T.Type) -> T? {
        dlsym(handle, name).map { unsafeBitCast($0, to: type) }
    }

    static let mainConnectionID = function("SLSMainConnectionID", as: (@convention(c) () -> Int32).self)
}
