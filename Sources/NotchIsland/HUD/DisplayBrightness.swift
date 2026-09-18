import CoreGraphics
import Foundation

/// Brightness of a built-in display, through the private DisplayServices
/// framework (what the brightness keys themselves use). Unavailable → nil/false,
/// and the key goes to macOS instead.
enum DisplayBrightness {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getBrightness = dlsym(framework, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: GetBrightness.self) }
    private static let setBrightness = dlsym(framework, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetBrightness.self) }

    static func level(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        guard let getBrightness, getBrightness(display, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    static func setLevel(_ level: Float, of display: CGDirectDisplayID) -> Bool {
        guard let setBrightness else { return false }
        return setBrightness(display, min(max(level, 0), 1)) == 0
    }
}
