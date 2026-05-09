import CoreGraphics
import Foundation
import SwiftUI

#if canImport(AppKit)
public typealias _PlatformImage = NSImage
#elseif canImport(UIKit)
public typealias _PlatformImage = UIImage
#endif

private let blurHashDeviceRGBColorSpace = CGColorSpaceCreateDeviceRGB()

// MARK: - CGImage

/// Create a `CGImage` from a BlurHash string.
public func cgImage(
    blurHash: String,
    size: CGSize,
    punch: Float = 1
) -> CGImage? {
    BlurHashRenderer.cgImage(
        blurHash: blurHash,
        size: size,
        punch: punch
    )
}

/// Create a `CGImage` from a BlurHash string.
public func cgImage(
    blurHash: String,
    pixels: Int = 1024,
    size: CGSize,
    punch: Float = 1
) -> CGImage? {
    let size = BlurHashRenderer.decodedSize(
        pixels: pixels,
        size: size
    )

    return BlurHashKit.cgImage(
        blurHash: blurHash,
        size: size,
        punch: punch
    )
}

// MARK: - PlatformImage

@objc
public extension _PlatformImage {

    /// Create an image from a BlurHash string.
    convenience init?(
        blurHash: String,
        size: CGSize,
        punch: Float = 1
    ) {
        guard let cgImage = BlurHashKit.cgImage(
            blurHash: blurHash,
            size: size,
            punch: punch
        ) else { return nil }

        #if canImport(AppKit)
        self.init(cgImage: cgImage, size: size)
        #elseif canImport(UIKit)
        self.init(cgImage: cgImage)
        #endif
    }

    /// Create an image from a BlurHash string.
    convenience init?(
        blurHash: String,
        pixels: Int = 1024,
        size: CGSize,
        punch: Float = 1
    ) {
        let size = BlurHashRenderer.decodedSize(
            pixels: pixels,
            size: size
        )

        self.init(
            blurHash: blurHash,
            size: size,
            punch: punch
        )
    }
}

// MARK: - Image

public extension Image {

    init?(
        blurHash: String,
        size: CGSize,
        punch: Float = 1
    ) {
        guard let image = _PlatformImage(
            blurHash: blurHash,
            size: size,
            punch: punch
        ) else { return nil }

        #if canImport(AppKit)
        self.init(nsImage: image)
        #elseif canImport(UIKit)
        self.init(uiImage: image)
        #endif
    }

    init?(
        blurHash: String,
        pixels: Int = 1024,
        size: CGSize,
        punch: Float = 1
    ) {
        let size = BlurHashRenderer.decodedSize(
            pixels: pixels,
            size: size
        )

        self.init(
            blurHash: blurHash,
            size: size,
            punch: punch
        )
    }
}

// MARK: - BlurHashRenderer

private enum BlurHashRenderer {
    static func cgImage(
        blurHash string: String,
        size: CGSize,
        punch: Float
    ) -> CGImage? {
        guard let decoded = DecodedBlurHash(
            string: string,
            punch: punch
        ) else { return nil }

        return cgImage(size: size, decoded: decoded)
    }

    static func decodedSize(
        pixels: Int,
        size: CGSize
    ) -> CGSize {
        let width: CGFloat
        let height: CGFloat

        if size.width > size.height {
            width = floor(sqrt(CGFloat(pixels) * size.width / size.height) + 0.5)
            height = floor(CGFloat(pixels) / width + 0.5)
        } else {
            height = floor(sqrt(CGFloat(pixels) * size.height / size.width) + 0.5)
            width = floor(CGFloat(pixels) / height + 0.5)
        }

        return CGSize(width: width, height: height)
    }

    private static func cgImage(
        size: CGSize,
        decoded: DecodedBlurHash
    ) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 3
        let byteCount = bytesPerRow * height

        guard width > 0 && height > 0 else { return nil }

        let rawPixels = UnsafeMutableRawPointer.allocate(
            byteCount: byteCount,
            alignment: MemoryLayout<UInt8>.alignment
        )
        let pixels = rawPixels.bindMemory(to: UInt8.self, capacity: byteCount)

        let componentCount = decoded.componentCount

        decoded.channels.withUnsafeBufferPointer { channels in
            let red = channels.baseAddress!
            let green = red.advanced(by: componentCount)
            let blue = green.advanced(by: componentCount)

            if decoded.numX == 1 && decoded.numY == 1 {
                renderSingleColor(
                    pixels: pixels,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    red: red[0],
                    green: green[0],
                    blue: blue[0]
                )
            } else {
                let cosX = cosineTable(count: width, components: decoded.numX)
                let cosY = cosineTable(count: height, components: decoded.numY)

                cosX.withUnsafeBufferPointer { cosX in
                    cosY.withUnsafeBufferPointer { cosY in
                        renderPixels(
                            pixels: pixels,
                            width: width,
                            height: height,
                            bytesPerRow: bytesPerRow,
                            decoded: decoded,
                            red: red,
                            green: green,
                            blue: blue,
                            cosX: cosX.baseAddress!,
                            cosY: cosY.baseAddress!
                        )
                    }
                }
            }
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let provider = CGDataProvider(
            dataInfo: nil,
            data: rawPixels,
            size: byteCount,
            releaseData: { _, data, _ in UnsafeMutableRawPointer(mutating: data).deallocate() }
        ) else {
            rawPixels.deallocate()
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bytesPerRow,
            space: blurHashDeviceRGBColorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func cosineTable(
        count: Int,
        components: Int
    ) -> [Float] {
        [Float](unsafeUninitializedCapacity: count * components) { buffer, initializedCount in
            for position in 0 ..< count {
                for component in 0 ..< components {
                    buffer[position * components + component] = cos(
                        Float.pi * Float(position) * Float(component) / Float(count)
                    )
                }
            }
            initializedCount = count * components
        }
    }

    private static func renderPixels(
        pixels: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        decoded: DecodedBlurHash,
        red: UnsafePointer<Float>,
        green: UnsafePointer<Float>,
        blue: UnsafePointer<Float>,
        cosX: UnsafePointer<Float>,
        cosY: UnsafePointer<Float>
    ) {
        if decoded.numX == 4 && decoded.numY == 3 {
            renderFourByThree(
                pixels: pixels,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                red: red,
                green: green,
                blue: blue,
                cosX: cosX,
                cosY: cosY
            )
        } else {
            renderGeneral(
                pixels: pixels,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                decoded: decoded,
                red: red,
                green: green,
                blue: blue,
                cosX: cosX,
                cosY: cosY
            )
        }
    }

    private static func renderSingleColor(
        pixels: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        red: Float,
        green: Float,
        blue: Float
    ) {
        let intR = UInt8(linearTosRGB(red))
        let intG = UInt8(linearTosRGB(green))
        let intB = UInt8(linearTosRGB(blue))

        for y in 0 ..< height {
            var offset = y * bytesPerRow
            for _ in 0 ..< width {
                writePixel(pixels, offset: offset, red: intR, green: intG, blue: intB)
                offset += 3
            }
        }
    }

    // MARK: - FourByThree

    private static func renderFourByThree(
        pixels: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        red: UnsafePointer<Float>,
        green: UnsafePointer<Float>,
        blue: UnsafePointer<Float>,
        cosX: UnsafePointer<Float>,
        cosY: UnsafePointer<Float>
    ) {
        for y in 0 ..< height {
            var offset = y * bytesPerRow
            let yBasis1 = cosY[y * 3 + 1]
            let yBasis2 = cosY[y * 3 + 2]

            for x in 0 ..< width {
                let cosXOffset = x * 4
                let xBasis1 = cosX[cosXOffset + 1]
                let xBasis2 = cosX[cosXOffset + 2]
                let xBasis3 = cosX[cosXOffset + 3]

                var r = red[0]
                var g = green[0]
                var b = blue[0]

                r += red[1] * xBasis1
                g += green[1] * xBasis1
                b += blue[1] * xBasis1
                r += red[2] * xBasis2
                g += green[2] * xBasis2
                b += blue[2] * xBasis2
                r += red[3] * xBasis3
                g += green[3] * xBasis3
                b += blue[3] * xBasis3
                r += red[4] * yBasis1
                g += green[4] * yBasis1
                b += blue[4] * yBasis1
                let basis5 = xBasis1 * yBasis1
                r += red[5] * basis5
                g += green[5] * basis5
                b += blue[5] * basis5
                let basis6 = xBasis2 * yBasis1
                r += red[6] * basis6
                g += green[6] * basis6
                b += blue[6] * basis6
                let basis7 = xBasis3 * yBasis1
                r += red[7] * basis7
                g += green[7] * basis7
                b += blue[7] * basis7
                r += red[8] * yBasis2
                g += green[8] * yBasis2
                b += blue[8] * yBasis2
                let basis9 = xBasis1 * yBasis2
                r += red[9] * basis9
                g += green[9] * basis9
                b += blue[9] * basis9
                let basis10 = xBasis2 * yBasis2
                r += red[10] * basis10
                g += green[10] * basis10
                b += blue[10] * basis10
                let basis11 = xBasis3 * yBasis2
                r += red[11] * basis11
                g += green[11] * basis11
                b += blue[11] * basis11

                writePixel(
                    pixels,
                    offset: offset,
                    red: UInt8(linearTosRGB(r)),
                    green: UInt8(linearTosRGB(g)),
                    blue: UInt8(linearTosRGB(b))
                )
                offset += 3
            }
        }
    }

    // MARK: - General

    private static func renderGeneral(
        pixels: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        decoded: DecodedBlurHash,
        red: UnsafePointer<Float>,
        green: UnsafePointer<Float>,
        blue: UnsafePointer<Float>,
        cosX: UnsafePointer<Float>,
        cosY: UnsafePointer<Float>
    ) {
        for y in 0 ..< height {
            var offset = y * bytesPerRow
            let cosYOffset = y * decoded.numY

            for x in 0 ..< width {
                let cosXOffset = x * decoded.numX
                var r = red[0]
                var g = green[0]
                var b = blue[0]

                for i in 1 ..< decoded.numX {
                    accumulate(&r, &g, &b, red, green, blue, index: i, basis: cosX[cosXOffset + i])
                }

                for j in 1 ..< decoded.numY {
                    let yBasis = cosY[cosYOffset + j]
                    let componentOffset = j * decoded.numX
                    for i in 0 ..< decoded.numX {
                        let index = componentOffset + i
                        accumulate(&r, &g, &b, red, green, blue, index: index, basis: cosX[cosXOffset + i] * yBasis)
                    }
                }

                writePixel(
                    pixels,
                    offset: offset,
                    red: UInt8(linearTosRGB(r)),
                    green: UInt8(linearTosRGB(g)),
                    blue: UInt8(linearTosRGB(b))
                )
                offset += 3
            }
        }
    }

    @inline(__always)
    private static func accumulate(
        _ outputRed: inout Float,
        _ outputGreen: inout Float,
        _ outputBlue: inout Float,
        _ red: UnsafePointer<Float>,
        _ green: UnsafePointer<Float>,
        _ blue: UnsafePointer<Float>,
        index: Int,
        basis: Float
    ) {
        outputRed += red[index] * basis
        outputGreen += green[index] * basis
        outputBlue += blue[index] * basis
    }

    @inline(__always)
    private static func writePixel(
        _ pixels: UnsafeMutablePointer<UInt8>,
        offset: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8
    ) {
        pixels[offset + 0] = red
        pixels[offset + 1] = green
        pixels[offset + 2] = blue
    }
}
