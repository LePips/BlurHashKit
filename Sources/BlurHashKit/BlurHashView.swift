import SwiftUI

public struct BlurHashView: UIViewRepresentable {

    private let blurHash: String
    private let size: CGSize
    private let pixels: Int
    private let punch: Float

    public init(
        blurHash: String,
        size: CGSize = .Circle(radius: 12),
        pixels: Int = 1024,
        punch: Float = 1
    ) {
        self.blurHash = blurHash
        self.size = size
        self.pixels = pixels
        self.punch = punch
    }

    public func makeUIView(context: Context) -> UIBlurHashImageView {
        UIBlurHashImageView(
            blurHash: blurHash,
            size: size,
            pixels: pixels,
            punch: punch
        )
    }

    public func updateUIView(_ uiView: UIBlurHashImageView, context: Context) {}
}

public class UIBlurHashImageView: UIImageView {

    public init(blurHash: String, size: CGSize, pixels: Int, punch: Float) {
        super.init(frame: .zero)

        computeBlurHashImageAsync(blurHash: blurHash, size: size, pixels: pixels, punch: punch) { [weak self] blurImage in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.image = blurImage
                self.setNeedsDisplay()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func computeBlurHashImageAsync(
        blurHash: String,
        size: CGSize,
        pixels: Int,
        punch: Float,
        _ completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            let image = UIImage(
                blurHash: blurHash,
                numberOfPixels: pixels,
                originalSize: size,
                punch: punch
            )
            completion(image)
        }
    }
}

public extension CGSize {
    static func Circle(radius: CGFloat) -> CGSize {
        .init(width: radius, height: radius)
    }
}
