import UIKit

public extension BlurHash {
    func cgImage(size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 3

        guard let data = CFDataCreateMutable(kCFAllocatorDefault, bytesPerRow * height) else { return nil }
        CFDataSetLength(data, bytesPerRow * height)

        guard let pixels = CFDataGetMutableBytePtr(data) else { return nil }
        guard let sizeValue = string.first else { return nil }

        let sizeFlag = String(sizeValue).decode83()
        let numY = (sizeFlag / 9) + 1
        let numX = (sizeFlag % 9) + 1

        let cosxi = Self.cosCache.get(length: width, numComponents: numX)
        let cosyj = Self.cosCache.get(length: height, numComponents: numY)

        for y in 0 ..< height {
            let cosj = cosyj[y]
            for x in 0 ..< width {
                let cosi = cosxi[x]
                var c: (Float, Float, Float) = (0, 0, 0)

                for j in 0 ..< numberOfVerticalComponents {
                    for i in 0 ..< numberOfHorizontalComponents {
                        let basis = cosi[i] * cosj[j]
                        let component = components[j][i]
                        c += component * basis
                    }
                }

                let intR = UInt8(linearTosRGB(c.0))
                let intG = UInt8(linearTosRGB(c.1))
                let intB = UInt8(linearTosRGB(c.2))

                pixels[3 * x + 0 + y * bytesPerRow] = intR
                pixels[3 * x + 1 + y * bytesPerRow] = intG
                pixels[3 * x + 2 + y * bytesPerRow] = intB
            }
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)

        guard let provider = CGDataProvider(data: data) else { return nil }
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 24,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return cgImage
    }

    func cgImage(numberOfPixels: Int = 1024, originalSize size: CGSize) -> CGImage? {
        let width: CGFloat
        let height: CGFloat
        if size.width > size.height {
            width = floor(sqrt(CGFloat(numberOfPixels) * size.width / size.height) + 0.5)
            height = floor(CGFloat(numberOfPixels) / width + 0.5)
        } else {
            height = floor(sqrt(CGFloat(numberOfPixels) * size.height / size.width) + 0.5)
            width = floor(CGFloat(numberOfPixels) / height + 0.5)
        }
        return cgImage(size: CGSize(width: width, height: height))
    }

    func image(size: CGSize) -> UIImage? {
        guard let cgImage = cgImage(size: size) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func image(numberOfPixels: Int = 1024, originalSize size: CGSize) -> UIImage? {
        guard let cgImage = cgImage(numberOfPixels: numberOfPixels, originalSize: size) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

@objc
public extension UIImage {
    convenience init?(blurHash string: String, size: CGSize, punch: Float = 1) {
        guard let blurHash = BlurHash(string: string),
              let cgImage = blurHash.punch(punch).cgImage(size: size) else { return nil }
        self.init(cgImage: cgImage)
    }

    convenience init?(blurHash string: String, numberOfPixels: Int = 1024, originalSize size: CGSize, punch: Float = 1) {
        guard let blurHash = BlurHash(string: string),
              let cgImage = blurHash.punch(punch).cgImage(numberOfPixels: numberOfPixels, originalSize: size) else { return nil }
        self.init(cgImage: cgImage)
    }
}
