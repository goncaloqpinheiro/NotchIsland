import Foundation

/// Apple's own looping animation of an AirPods or Beats product: the one macOS
/// shows in its connection banner. Each is a 6 s, 60 fps HEVC movie with a
/// transparent background inside BluetoothUIService, named by Bluetooth
/// product ID. Played from there, never copied into the app.
enum ProductAnimation {
    private static let resources = URL(fileURLWithPath: "/System/Library/CoreServices/BluetoothUIService.app/Contents/Resources")

    /// The looping movie for a product ID, or nil if this macOS has none.
    static func url(forProductID productID: Int) -> URL? {
        guard productID > 0 else { return nil }
        let folder = resources.appending(path: "Banner-PID-\(productID)-mov")
        for name in ["Banner-PID-\(productID)-Loop.mov", "Banner-PID-\(productID)-default-Loop.mov"] {
            let url = folder.appending(path: name)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        // Some products only come in color variants; any of them will do.
        let movies = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return movies.filter { $0.pathExtension == "mov" }.min { $0.lastPathComponent < $1.lastPathComponent }
    }
}
