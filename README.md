Basic port of the [Swift implementation for BlurHash](https://github.com/woltapp/blurhash/tree/master/Swift/BlurHashKit).

## Usage

`BlurHashView` has been provided as an easy way to use a BlurHash in SwiftUI.

```swift
BlurHashView(
    blurHash: "LGF5?xYk^6#M@-5c,1J5@[or[Q6.",
    size: CGSize(width: 4, height: 3),
    pixels: 512,
    punch: 0.8
)
```

## Development
- [ ] macOS support
