import Foundation

private let sRGBToLinearTable: [Float] = (0 ... 255).map { value in
    let v = Float(value) / 255
    if v <= 0.04045 { return v / 12.92 }
    else { return pow((v + 0.055) / 1.055, 2.4) }
}

@inline(__always)
func signPow(_ value: Float, _ exp: Float) -> Float {
    copysign(pow(abs(value), exp), value)
}

@inline(__always)
func linearTosRGB(_ value: Float) -> Int {
    let v = max(0, min(1, value))
    if v <= 0.0031308 { return Int(v * 12.92 * 255 + 0.5) }
    else { return Int((1.055 * pow(v, 1 / 2.4) - 0.055) * 255 + 0.5) }
}

@inline(__always)
func sRGBToLinear(_ value: some BinaryInteger) -> Float {
    let intValue = Int64(value)
    if intValue >= 0 && intValue <= 255 {
        return sRGBToLinearTable[Int(intValue)]
    }

    let v = Float(intValue) / 255
    if v <= 0.04045 { return v / 12.92 }
    else { return pow((v + 0.055) / 1.055, 2.4) }
}
