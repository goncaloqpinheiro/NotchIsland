import CoreGraphics
import Foundation

/// A small animated GIF encoder for the README's demo. Each frame stores only
/// the pixels that changed, and a frame that repeats is held longer instead of
/// stored again, so an animation over a still background stays small.
final class GIFWriter {
    private let width: Int
    private let height: Int
    /// Hundredths of a second per frame.
    private let delay: Int
    private let palette: GIFPalette
    private var data = Data()
    private var previous: [UInt8]?
    private var pending: (frame: Frame, delay: Int)?

    /// A pixel rectangle; max is one past the last pixel.
    private struct Box {
        let minX: Int, minY: Int, maxX: Int, maxY: Int
        var width: Int { maxX - minX }
        var height: Int { maxY - minY }
    }

    private struct Frame {
        let x: Int, y: Int, width: Int, height: Int
        let indices: [UInt8]
        /// Unchanged pixels are see-through, showing the frame before.
        let isPartial: Bool
    }

    init(width: Int, height: Int, delay: Int, palette: GIFPalette) {
        self.width = width
        self.height = height
        self.delay = delay
        self.palette = palette
        data.append(contentsOf: Array("GIF89a".utf8))
        append16(width)
        append16(height)
        data.append(contentsOf: [0xF7, 0, 0])  // a 256 color table follows
        data.append(contentsOf: palette.table)
        // Loop forever.
        data.append(contentsOf: [0x21, 0xFF, 0x0B] + Array("NETSCAPE2.0".utf8) + [0x03, 0x01, 0x00, 0x00, 0x00])
    }

    func add(_ image: CGImage) {
        let current = palette.indices(of: image, width: width, height: height)
        guard let previous else {
            pending = (Frame(x: 0, y: 0, width: width, height: height, indices: current, isPartial: false), delay)
            self.previous = current
            return
        }
        guard let box = changedBox(from: previous, to: current) else {
            pending?.delay += delay
            return
        }
        flush()
        var indices: [UInt8] = []
        indices.reserveCapacity(box.width * box.height)
        for y in box.minY..<box.maxY {
            for x in box.minX..<box.maxX {
                let index = y * width + x
                indices.append(current[index] == previous[index] ? GIFPalette.transparent : current[index])
            }
        }
        pending = (Frame(x: box.minX, y: box.minY, width: box.width, height: box.height, indices: indices, isPartial: true), delay)
        self.previous = current
    }

    func write(to url: URL) throws {
        flush()
        data.append(0x3B)
        try data.write(to: url)
    }

    private func flush() {
        guard let (frame, delay) = pending else { return }
        pending = nil
        // Keep the frame before underneath; unchanged pixels are see-through.
        data.append(contentsOf: [0x21, 0xF9, 0x04, frame.isPartial ? 0x05 : 0x04])
        append16(delay)
        data.append(contentsOf: [GIFPalette.transparent, 0])
        data.append(0x2C)
        append16(frame.x)
        append16(frame.y)
        append16(frame.width)
        append16(frame.height)
        data.append(0)
        data.append(8)  // LZW minimum code size for 256 colors
        let compressed = LZW.encode(frame.indices)
        var offset = 0
        while offset < compressed.count {
            let count = min(255, compressed.count - offset)
            data.append(UInt8(count))
            data.append(contentsOf: compressed[offset..<offset + count])
            offset += count
        }
        data.append(0)
    }

    private func changedBox(from old: [UInt8], to new: [UInt8]) -> Box? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        old.withUnsafeBufferPointer { old in
            new.withUnsafeBufferPointer { new in
                for y in 0..<height {
                    let row = y * width
                    var x = 0
                    while x < width, old[row + x] == new[row + x] { x += 1 }
                    guard x < width else { continue }
                    var last = width - 1
                    while old[row + last] == new[row + last] { last -= 1 }
                    minX = min(minX, x)
                    maxX = max(maxX, last)
                    minY = min(minY, y)
                    maxY = y
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return Box(minX: minX, minY: minY, maxX: maxX + 1, maxY: maxY + 1)
    }

    private func append16(_ value: Int) {
        data.append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8 & 0xFF)])
    }
}

/// GIF's variable-length LZW compression.
enum LZW {
    static func encode(_ indices: [UInt8], minCodeSize: Int = 8) -> [UInt8] {
        let clearCode = 1 << minCodeSize
        let endCode = clearCode + 1
        var codeSize = minCodeSize + 1
        var nextCode = endCode + 1
        var table: [Int: Int] = [:]
        var output: [UInt8] = []
        var bits = 0
        var bitCount = 0

        func emit(_ code: Int) {
            bits |= code << bitCount
            bitCount += codeSize
            while bitCount >= 8 {
                output.append(UInt8(bits & 0xFF))
                bits >>= 8
                bitCount -= 8
            }
        }

        emit(clearCode)
        if var prefix = indices.first.map(Int.init) {
            for byte in indices.dropFirst() {
                let key = prefix << 8 | Int(byte)
                if let code = table[key] {
                    prefix = code
                    continue
                }
                emit(prefix)
                if nextCode == 4096 {
                    // The table is full: start over.
                    emit(clearCode)
                    table.removeAll(keepingCapacity: true)
                    codeSize = minCodeSize + 1
                    nextCode = endCode + 1
                } else {
                    // The decoder widens its codes as it adds this entry, so widen now.
                    if nextCode >= 1 << codeSize { codeSize += 1 }
                    table[key] = nextCode
                    nextCode += 1
                }
                prefix = Int(byte)
            }
            emit(prefix)
        }
        emit(endCode)
        if bitCount > 0 { output.append(UInt8(bits & 0xFF)) }
        return output
    }
}
