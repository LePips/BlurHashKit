import Foundation

struct DecodedBlurHash {
    let numX: Int
    let numY: Int
    let channels: [Float]

    var componentCount: Int {
        numX * numY
    }

    init?(string: String, punch: Float = 1) {
        if let contiguousDecoded = string.utf8.withContiguousStorageIfAvailable({ buffer -> DecodedBlurHash? in
            guard let bytes = buffer.baseAddress else { return nil }
            return DecodedBlurHash(bytes: bytes, count: buffer.count, punch: punch)
        }) {
            guard let decoded = contiguousDecoded else { return nil }
            self = decoded
            return
        }

        let bytes = Array(string.utf8)
        guard let decoded = bytes.withUnsafeBufferPointer({ buffer -> DecodedBlurHash? in
            guard let bytes = buffer.baseAddress else { return nil }
            return DecodedBlurHash(bytes: bytes, count: buffer.count, punch: punch)
        }) else { return nil }

        self = decoded
    }

    init?(bytes: UnsafePointer<UInt8>, count: Int, punch: Float = 1) {
        guard count >= 6 else { return nil }

        let sizeFlag = decode83OneUnchecked(bytes, offset: 0)
        guard sizeFlag >= 0 else { return nil }
        self.numX = (sizeFlag % 9) + 1
        self.numY = (sizeFlag / 9) + 1
        let componentCount = numX * numY
        guard count == 4 + 2 * componentCount else { return nil }

        let maximumValueFlag = decode83OneUnchecked(bytes, offset: 1)
        guard maximumValueFlag >= 0 else { return nil }
        let maximumValue = Float(maximumValueFlag + 1) / 166
        let greenOffset = componentCount
        let blueOffset = componentCount * 2
        var channels = Array(repeating: Float(0), count: componentCount * 3)

        let dcValue = decode83FourUnchecked(bytes, offset: 2)
        guard dcValue >= 0 else { return nil }
        channels[0] = sRGBToLinear(dcValue >> 16)
        channels[greenOffset] = sRGBToLinear((dcValue >> 8) & 255)
        channels[blueOffset] = sRGBToLinear(dcValue & 255)

        for index in 1 ..< componentCount {
            let acValue = decode83TwoUnchecked(bytes, offset: 4 + index * 2)
            guard acValue >= 0 && acValue < Self.acComponents.count else { return nil }
            let component = Self.acComponents[acValue]
            let scale = maximumValue * punch
            channels[index] = component.0 * scale
            channels[greenOffset + index] = component.1 * scale
            channels[blueOffset + index] = component.2 * scale
        }

        self.channels = channels
    }

    private static let acComponents: [(Float, Float, Float)] = (0 ..< 19 * 19 * 19).map { value in
        let quantR = value / (19 * 19)
        let quantG = (value / 19) % 19
        let quantB = value % 19
        let red = (Float(quantR) - 9) / 9
        let green = (Float(quantG) - 9) / 9
        let blue = (Float(quantB) - 9) / 9

        return (
            copysign(red * red, red),
            copysign(green * green, green),
            copysign(blue * blue, blue)
        )
    }
}
