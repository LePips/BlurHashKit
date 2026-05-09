import CoreGraphics
import Foundation

public extension CGImage {

    /// Create a BlurHash string from the current image.
    func blurHash(components: (Int, Int) = (4, 3)) -> String? {
        guard components.0 >= 1, components.0 <= 9,
              components.1 >= 1, components.1 <= 9
        else {
            assertionFailure("Number of components must be between 1 and 9 inclusive on each axis")
            return nil
        }

        guard let cgImage = Self.normalizedCGImage(from: self),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let pixels = CFDataGetBytePtr(data)
        else {
            assertionFailure("Unexpected error")
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = cgImage.bytesPerRow

        let componentGrid = (0 ..< components.1).map { j -> [(Float, Float, Float)] in
            (0 ..< components.0).map { i -> (Float, Float, Float) in
                let normalisation: Float = (i == 0 && j == 0) ? 1 : 2

                return Self.multiplyBasisFunction(
                    pixels: pixels,
                    width: width,
                    height: height,
                    bytesPerRow: bytesPerRow,
                    bytesPerPixel: cgImage.bitsPerPixel / 8
                ) { x, y in
                    normalisation * cos(Float.pi * Float(i) * x / Float(width)) as Float *
                        cos(Float.pi * Float(j) * y / Float(height)) as Float
                }
            }
        }

        return blurHashString(from: componentGrid)
    }

    private static func normalizedCGImage(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        guard let context else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    private static func multiplyBasisFunction(
        pixels: UnsafePointer<UInt8>,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        bytesPerPixel: Int,
        basisFunction: (Float, Float) -> Float
    ) -> (Float, Float, Float) {
        var c: (Float, Float, Float) = (0, 0, 0)

        let buffer = UnsafeBufferPointer(start: pixels, count: height * bytesPerRow)

        for x in 0 ..< width {
            for y in 0 ..< height {
                c += basisFunction(Float(x), Float(y)) * (
                    sRGBToLinear(buffer[bytesPerPixel * x + 0 + y * bytesPerRow]),
                    sRGBToLinear(buffer[bytesPerPixel * x + 1 + y * bytesPerRow]),
                    sRGBToLinear(buffer[bytesPerPixel * x + 2 + y * bytesPerRow])
                )
            }
        }

        return c / Float(width * height)
    }
}

private func blurHashString(from components: [[(Float, Float, Float)]]) -> String {
    let flatComponents = components.reduce([]) { $0 + $1 }
    let dc = flatComponents.first!
    let ac = flatComponents.dropFirst()

    var hash = ""

    let sizeFlag = (components[0].count - 1) + (components.count - 1) * 9
    hash += sizeFlag.encode83(length: 1)

    let maximumValue: Float

    if !ac.isEmpty {
        let actualMaximumValue = ac.map { max(abs($0.0), abs($0.1), abs($0.2)) }.max()!
        let quantisedMaximumValue = Int(max(0, min(82, floor(actualMaximumValue * 166 - 0.5))))
        maximumValue = Float(quantisedMaximumValue + 1) / 166
        hash += quantisedMaximumValue.encode83(length: 1)
    } else {
        maximumValue = 1
        hash += 0.encode83(length: 1)
    }

    hash += encodeDC(dc).encode83(length: 4)

    for factor in ac {
        hash += encodeAC(factor, maximumValue: maximumValue).encode83(length: 2)
    }

    return hash
}

private func encodeDC(_ value: (Float, Float, Float)) -> Int {
    let roundedR = linearTosRGB(value.0)
    let roundedG = linearTosRGB(value.1)
    let roundedB = linearTosRGB(value.2)
    return (roundedR << 16) + (roundedG << 8) + roundedB
}

private func encodeAC(_ value: (Float, Float, Float), maximumValue: Float) -> Int {
    let quantR = Int(max(0, min(18, floor(signPow(value.0 / maximumValue, 0.5) * 9 + 9.5))))
    let quantG = Int(max(0, min(18, floor(signPow(value.1 / maximumValue, 0.5) * 9 + 9.5))))
    let quantB = Int(max(0, min(18, floor(signPow(value.2 / maximumValue, 0.5) * 9 + 9.5))))

    return quantR * 19 * 19 + quantG * 19 + quantB
}
