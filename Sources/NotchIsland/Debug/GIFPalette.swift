import CoreGraphics
import Foundation

/// 255 colors picked for a whole animation, by median cut over a histogram of
/// sample frames, plus a see-through entry for pixels that didn't change. A
/// light ordered dither smooths gradients and, unlike error diffusion, gives
/// an unchanged pixel the same color in every frame.
struct GIFPalette {
    static let transparent: UInt8 = 255

    /// Pixel counts per color, 5 bits a channel.
    struct Histogram {
        fileprivate var counts = [Int](repeating: 0, count: 1 << 15)

        mutating func add(_ image: CGImage, step: Int = 4) {
            let (pixels, width, height) = GIFPalette.pixels(of: image, width: image.width, height: image.height)
            for y in stride(from: 0, to: height, by: step) {
                for x in stride(from: 0, to: width, by: step) {
                    let i = (y * width + x) * 4
                    counts[GIFPalette.key(Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))] += 1
                }
            }
        }
    }

    private let colors: [(r: Int, g: Int, b: Int)]
    /// The nearest color for every 5 bits a channel value.
    private let nearest: [UInt8]

    init(_ histogram: Histogram) {
        struct Entry { let key: Int; let count: Int }
        var boxes: [[Entry]] = [histogram.counts.enumerated().compactMap { $1 > 0 ? Entry(key: $0, count: $1) : nil }]
        func channel(_ key: Int, _ c: Int) -> Int { key >> (10 - 5 * c) & 31 }
        func widest(_ box: [Entry]) -> (channel: Int, range: Int) {
            (0..<3).map { c in
                let values = box.map { channel($0.key, c) }
                return (c, (values.max() ?? 0) - (values.min() ?? 0))
            }.max { $0.1 < $1.1 }!
        }
        // Pure black and white are kept exact: the island and its text.
        while boxes.count < 253 {
            let scored = boxes.indices.map { index -> (index: Int, channel: Int, score: Double) in
                let (c, range) = widest(boxes[index])
                let count = boxes[index].reduce(0) { $0 + $1.count }
                return (index, c, Double(range) * Double(count).squareRoot())
            }
            guard let pick = scored.max(by: { $0.score < $1.score }), pick.score > 0 else { break }
            let sorted = boxes[pick.index].sorted { channel($0.key, pick.channel) < channel($1.key, pick.channel) }
            let half = sorted.reduce(0) { $0 + $1.count } / 2
            var running = 0
            var split = 1
            for (offset, entry) in sorted.enumerated() {
                running += entry.count
                if running >= half { split = max(1, min(sorted.count - 1, offset + 1)); break }
            }
            boxes[pick.index] = Array(sorted[..<split])
            boxes.append(Array(sorted[split...]))
        }
        let averages = boxes.map { box -> (r: Int, g: Int, b: Int) in
            let total = Double(box.reduce(0) { $0 + $1.count })
            func mean(_ c: Int) -> Int {
                Int((box.reduce(0.0) { $0 + Double(Self.expand(channel($1.key, c)) * $1.count) } / total).rounded())
            }
            return (mean(0), mean(1), mean(2))
        }
        let colors = [(r: 0, g: 0, b: 0), (r: 255, g: 255, b: 255)] + averages
        self.colors = colors
        nearest = (0..<(1 << 15)).map { key in
            let (r, g, b) = (Self.expand(key >> 10 & 31), Self.expand(key >> 5 & 31), Self.expand(key & 31))
            var best = 0
            var bestDistance = Int.max
            for (index, color) in colors.enumerated() {
                let (dr, dg, db) = (color.r - r, color.g - g, color.b - b)
                let distance = 2 * dr * dr + 4 * dg * dg + 3 * db * db
                if distance < bestDistance { best = index; bestDistance = distance }
            }
            return UInt8(best)
        }
    }

    /// The color table, 256 entries of red, green and blue.
    var table: [UInt8] {
        let entries = colors.flatMap { [UInt8($0.r), UInt8($0.g), UInt8($0.b)] }
        return entries + [UInt8](repeating: 0, count: 768 - entries.count)
    }

    /// Palette indices of an image drawn at the given size.
    func indices(of image: CGImage, width: Int, height: Int) -> [UInt8] {
        let (pixels, _, _) = Self.pixels(of: image, width: width, height: height)
        var indices = [UInt8](repeating: 0, count: width * height)
        pixels.withUnsafeBufferPointer { pixels in
            indices.withUnsafeMutableBufferPointer { indices in
                for y in 0..<height {
                    for x in 0..<width {
                        let i = y * width + x
                        let offset = Self.dither[(y & 3) << 2 | (x & 3)]
                        indices[i] = nearest[Self.key(Int(pixels[i * 4]) + offset, Int(pixels[i * 4 + 1]) + offset,
                                                      Int(pixels[i * 4 + 2]) + offset)]
                    }
                }
            }
        }
        return indices
    }

    /// A 4 by 4 Bayer matrix, as offsets of about half a 5-bit step.
    private static let dither: [Int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { ($0 * 2 - 15) * 5 / 16 }

    fileprivate static func key(_ r: Int, _ g: Int, _ b: Int) -> Int {
        func bits(_ value: Int) -> Int { min(max(value, 0), 255) >> 3 }
        return bits(r) << 10 | bits(g) << 5 | bits(b)
    }

    private static func expand(_ five: Int) -> Int { five << 3 | five >> 2 }

    /// RGBA bytes of an image drawn at a size, in sRGB.
    fileprivate static func pixels(of image: CGImage, width: Int, height: Int) -> ([UInt8], Int, Int) {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            context?.interpolationQuality = .high
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (pixels, width, height)
    }
}
