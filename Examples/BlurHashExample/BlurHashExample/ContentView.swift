import BlurHashKit
import CoreGraphics
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

@main
struct BlurHashSampleApp: App {
    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            BlurHashSampleView()
                .frame(width: 400, height: 640)
        }
        .windowResizability(.contentSize)
        #else
        WindowGroup {
            BlurHashSampleView()
        }
        #endif
    }
}

struct BlurHashSampleView: View {

    @State
    private var blurHash = ""
    @State
    private var blurHashImage: CGImage?
    @State
    private var encodingTask: Task<Void, Never>?
    @State
    private var errorMessage: String?
    @State
    private var isEncoding = false
    @State
    private var isShowingBlurHash = false
    #if os(iOS)
    @State
    private var selectedPhoto: PhotosPickerItem?
    #else
    @State
    private var isImporterPresented = false
    #endif
    @State
    private var sourceImage: CGImage?

    var body: some View {
        #if os(iOS)
        content
            .padding(24)
            .onChange(of: selectedPhoto) { _, item in
                loadPhoto(item)
            }
            .onDisappear {
                encodingTask?.cancel()
            }
        #else
        content
            .padding(24)
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.image]
            ) { result in
                loadImage(from: result)
            }
            .onDisappear {
                encodingTask?.cancel()
            }
        #endif
    }

    private var content: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("BlurHashKit")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Select an image to generate a BlurHash string, or paste one to render it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            previewPanel

            blurHashInputPanel

            imageChooser
        }
    }

    @ViewBuilder
    private var imageChooser: some View {
        #if os(iOS)
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label("Select Image", systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isEncoding)
        #else
        Button {
            isImporterPresented = true
        } label: {
            Label("Select Image", systemImage: "photo")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isEncoding)
        #endif
    }

    @ViewBuilder
    private var previewPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.10))

            if let blurHashImage {
                previewImage(blurHashImage, pixelated: true)
            }

            if let sourceImage {
                previewImage(sourceImage, pixelated: false)
                    .opacity(isShowingBlurHash ? 0 : 1)
            }

            if sourceImage == nil && blurHashImage == nil {
                Image(systemName: "photo")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .animation(.easeInOut(duration: 0.22), value: isShowingBlurHash)
        .frame(height: 320)
        .aspectRatio(1, contentMode: .fill)
        .background(.background.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottomLeading) {
            if isEncoding {
                HStack {
                    ProgressView()
                        .controlSize(.small)

                    Text("Encoding...")
                        .font(.footnote)
                        .foregroundStyle(.white)
                }
                .padding(10)
                .background(.thickMaterial, in: .capsule)
                .padding(10)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if sourceImage != nil && blurHashImage != nil {
                Button {
                    isShowingBlurHash.toggle()
                } label: {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.blue, in: .circle)
                        .padding(10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewAspectRatio: CGFloat {
        guard let image = sourceImage ?? blurHashImage else { return 1 }
        return CGFloat(image.width) / CGFloat(image.height)
    }

    private var previewSize: CGSize {
        let maxLength: CGFloat = 320
        let aspectRatio = previewAspectRatio

        if aspectRatio >= 1 {
            return CGSize(width: maxLength, height: maxLength / aspectRatio)
        } else {
            return CGSize(width: maxLength * aspectRatio, height: maxLength)
        }
    }

    @ViewBuilder
    private var blurHashInputPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("BlurHash", text: $blurHash)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .onSubmit(renderHash)

                Button("Render", action: renderHash)
                    .disabled(blurHash.isEmpty)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func previewImage(_ image: CGImage, pixelated: Bool) -> some View {
        Image(decorative: image, scale: 1)
            .interpolation(pixelated ? .none : .medium)
            .resizable()
            .frame(width: previewSize.width, height: previewSize.height)
    }

    #if os(iOS)
    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                    .orThrow("Unable to load photo.")
                let image = try CGImage.load(from: data)

                setSourceImage(image)
            } catch {
                clearImage()
                errorMessage = error.localizedDescription
            }
        }
    }
    #endif

    #if !os(iOS)
    private func loadImage(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let image = try CGImage.load(from: url)

            setSourceImage(image)
        } catch {
            clearImage()
            errorMessage = error.localizedDescription
        }
    }
    #endif

    private func setSourceImage(_ image: CGImage) {
        sourceImage = image
        blurHashImage = nil
        blurHash = ""
        isShowingBlurHash = false
        errorMessage = nil
        encode(image)
    }

    private func clearImage() {
        sourceImage = nil
        blurHashImage = nil
        blurHash = ""
        isShowingBlurHash = false
        isEncoding = false
    }

    private func encode(_ image: CGImage) {
        encodingTask?.cancel()
        isEncoding = true

        encodingTask = Task.detached(priority: .userInitiated) {
            do {
                let hash = try image.blurHash(components: (4, 3))
                    .orThrow("Unable to encode image.")

                let decodedImage = try BlurHashKit.cgImage(
                    blurHash: hash,
                    size: Self.blurHashPreviewSize(matching: image)
                )
                .orThrow("Unable to decode generated blurhash.")

                await MainActor.run {
                    blurHash = hash
                    blurHashImage = decodedImage
                    errorMessage = nil
                    isEncoding = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isEncoding = false
                }
            }
        }
    }

    private func renderHash() {
        guard !blurHash.isEmpty else { return }

        guard let image = BlurHashKit.cgImage(
            blurHash: blurHash,
            size: Self.blurHashPreviewSize(matching: sourceImage)
        ) else {
            blurHashImage = nil
            errorMessage = "Unable to decode blurhash."
            return
        }

        blurHashImage = image
        isShowingBlurHash = true
        errorMessage = nil
    }

    private nonisolated static func blurHashPreviewSize(matching image: CGImage?) -> CGSize {
        guard let image else {
            return CGSize(width: 96, height: 96)
        }

        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longEdge: CGFloat = 160

        if width >= height {
            return CGSize(width: longEdge, height: max(1, round(longEdge * height / width)))
        } else {
            return CGSize(width: max(1, round(longEdge * width / height)), height: longEdge)
        }
    }
}

private extension CGImage {
    #if !os(iOS)
    static func load(from url: URL) throws -> CGImage {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        return try load(from: data)
    }
    #endif

    static func load(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw SampleError("Unable to read image.")
        }

        return image
    }
}

private extension Optional {
    nonisolated func orThrow(_ message: String) throws -> Wrapped {
        guard let value = self else {
            throw SampleError(message)
        }

        return value
    }
}

private struct SampleError: LocalizedError {
    let errorDescription: String?

    init(_ message: String) {
        self.errorDescription = message
    }
}
