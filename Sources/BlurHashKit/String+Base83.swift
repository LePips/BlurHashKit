import Foundation

private let encodeCharacterBytes: [UInt8] = Array(
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~".utf8
)

private let decodeCharacterBytes: [Int] = {
    var values = Array(repeating: -1, count: 256)
    for (index, character) in encodeCharacterBytes.enumerated() {
        values[Int(character)] = index
    }
    return values
}()

private let base83Powers = [1, 83, 6889, 571_787, 47_458_321]

extension BinaryInteger {
    func encode83(length: Int) -> String {
        var result: [UInt8] = []
        result.reserveCapacity(length)

        for i in 1 ... length {
            let digit = (Int(self) / base83Powers[length - i]) % 83
            result.append(encodeCharacterBytes[Int(digit)])
        }

        return String(decoding: result, as: UTF8.self)
    }
}

@inline(__always)
func decode83OneUnchecked(_ bytes: UnsafePointer<UInt8>, offset: Int) -> Int {
    decodeCharacterBytes[Int(bytes[offset])]
}

@inline(__always)
func decode83TwoUnchecked(_ bytes: UnsafePointer<UInt8>, offset: Int) -> Int {
    decodeCharacterBytes[Int(bytes[offset])] * 83
        + decodeCharacterBytes[Int(bytes[offset + 1])]
}

@inline(__always)
func decode83FourUnchecked(_ bytes: UnsafePointer<UInt8>, offset: Int) -> Int {
    ((decodeCharacterBytes[Int(bytes[offset])] * 83
            + decodeCharacterBytes[Int(bytes[offset + 1])]) * 83
        + decodeCharacterBytes[Int(bytes[offset + 2])]) * 83
        + decodeCharacterBytes[Int(bytes[offset + 3])]
}
