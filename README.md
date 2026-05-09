# BlurHashKit

Initially a port of the [BlurHash's Swift](https://github.com/woltapp/blurhash/tree/master/Swift/BlurHashKit) but rewritten with some optimizations. ~10% faster `String -> [UI|NS]Image` decoding.

Supports iOS, tvOS, watchOS, and macOS.

<details>
<summary>On Optimizations</summary>

This package tries to cache repeatedly used values as much as possible. Due to this, there may be an additional memory footprint. However, it's assumed your app has heavy use of BlurHashes, so this should be negligible.

This package makes optimizations for `(4, 3)` component shape. Using another shape may lose these optimizations, but you probably don't need to use anything else anyways.

Optimization implementations were validated with pixel comparison against the initial port.
</details>

## Usage

Decode a blurhash string directly into an image or encode an image into a BlurHash string:

```swift

// AppKit/UIKit

let image = UIImage(blurHash: "LGF5?xYk^6#M@-5c,1J5@[or[Q6.")
let image = NSImage(blurHash: "LGF5?xYk^6#M@-5c,1J5@[or[Q6.")

let blurHashString = image?.cgImage?.blurHash()

// SwiftUI

let image = Image(blurHash: "LGF5?xYk^6#M@-5c,1J5@[or[Q6.")
```

See `Examples/BlurHashExample` to see how to use BlurHash.
