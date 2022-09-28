import Foundation

public extension BlurHash {

    static var cosCache: Cache = Cache()

    class Cache {

        private var _cache: [String: [[Float]]] = [:]

        init() {}

        public func get(length: Int, numComponents: Int) -> [[Float]] {
            let key = "\(length)-\(numComponents)"
            if let cached = _cache[key] {
                return cached
            } else {
                let newCos = (0 ..< length).map { y in
                    (0 ..< numComponents).map { j in
                        cos(Float.pi * Float(y) * Float(j) / Float(length))
                    }
                }

                _cache[key] = newCos

                return newCos
            }
        }

        public func reset() {
            _cache = [:]
        }
    }
}
