import AppKit
import CoreImage

/// Derives a tint from album art for the audio bars.
enum ArtworkPalette {
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    /// The cover's average color, brightened so it reads on black; nil for
    /// near-gray covers, which should just use white.
    static func accentColor(of image: CGImage) -> NSColor? {
        let input = CIImage(cgImage: image)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input,
            kCIInputExtentKey: CIVector(cgRect: input.extent),
        ]), let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        let average = NSColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                              blue: CGFloat(pixel[2]) / 255, alpha: 1)
        guard average.saturationComponent > 0.15 else { return nil }
        return NSColor(hue: average.hueComponent,
                       saturation: min(average.saturationComponent * 1.2, 0.85),
                       brightness: max(average.brightnessComponent, 0.85),
                       alpha: 1)
    }
}
