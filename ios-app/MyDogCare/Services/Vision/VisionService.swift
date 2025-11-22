import Combine
import CoreData
import CoreGraphics
import CoreImage
import CoreVideo
import CryptoKit
import Foundation

struct DogState: Identifiable {
    let id: UUID // Dog's UUID (derived from Core Data when possible)
    let name: String
    let bounds: CGRect // Normalized [0, 1] coordinates
    let action: String // "Standing", "Sitting" (Placeholder for now)
    let confidence: Float
}

final class VisionService: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var detectedDogs: [DogState] = []

    private let cameraManager: CameraManager
    private let yoloClient: YOLOClient
    private let reidTracker: ReIDTracker
    private let context: NSManagedObjectContext

    private var frameCancellable: AnyCancellable?
    private var pendingFrame: CGImage?
    private var isProcessingFrame = false
    private let frameControlQueue = DispatchQueue(label: "com.mydogcare.vision.frame-control", qos: .userInitiated)
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    init(
        cameraManager: CameraManager = CameraManager(),
        yoloClient: YOLOClient,
        reidTracker: ReIDTracker,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        self.cameraManager = cameraManager
        self.yoloClient = yoloClient
        self.reidTracker = reidTracker
        self.context = context
    }

    func startProcessing() {
        guard frameCancellable == nil else { return }
        cameraManager.start()

        frameCancellable = cameraManager.$currentFrame
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] frame in
                guard let self else { return }
                self.currentFrame = frame
                self.enqueueFrameForProcessing(frame)
            }
    }

    func stopProcessing() {
        frameCancellable?.cancel()
        frameCancellable = nil
        cameraManager.stop()

        frameControlQueue.async { [weak self] in
            guard let self else { return }
            self.pendingFrame = nil
            self.isProcessingFrame = false
        }
    }

    deinit {
        stopProcessing()
    }
}

private extension VisionService {
    func enqueueFrameForProcessing(_ frame: CGImage) {
        frameControlQueue.async { [weak self] in
            guard let self else { return }
            self.pendingFrame = frame
            self.processPendingFrameIfNeededLocked()
        }
    }

    func processPendingFrameIfNeededLocked() {
        guard !isProcessingFrame, let frame = pendingFrame else { return }
        isProcessingFrame = true
        pendingFrame = nil

        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.runPipeline(with: frame)
            self.frameControlQueue.async { [weak self] in
                guard let self else { return }
                self.isProcessingFrame = false
                self.processPendingFrameIfNeededLocked()
            }
        }
    }

    func runPipeline(with frame: CGImage) async {
        let imageSize = CGSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
        guard let pixelBuffer = makePixelBuffer(from: frame) else { return }

        do {
            let detections = try await yoloClient.predict(pixelBuffer: pixelBuffer)
            guard !detections.isEmpty else {
                await MainActor.run { self.detectedDogs = [] }
                return
            }

            let knownDogs = await fetchKnownDogs()
            let ciImage = CIImage(cgImage: frame)
            var dogStates: [DogState] = []

            for detection in detections {
                guard let cropRect = rectForCropping(from: detection.boundingBox, imageSize: imageSize) else {
                    continue
                }

                let croppedImage = ciImage.cropped(to: cropRect)

                do {
                    let embedding = try await reidTracker.extractEmbedding(from: croppedImage)
                    let identifiedDog = reidTracker.identify(embedding: embedding, knownDogs: knownDogs)
                    let normalizedBounds = normalize(rect: cropRect, imageSize: imageSize)

                    let dogState = makeDogState(
                        detection: detection,
                        matchedDog: identifiedDog,
                        normalizedBounds: normalizedBounds
                    )
                    dogStates.append(dogState)
                } catch {
                    continue
                }
            }

            await MainActor.run {
                self.detectedDogs = dogStates
            }
        } catch {
            await MainActor.run {
                self.detectedDogs = []
            }
        }
    }

    func makePixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height

        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return pixelBuffer
    }

    func rectForCropping(from boundingBox: CGRect, imageSize: CGSize) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let rect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: boundingBox.origin.y * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        let imageRect = CGRect(origin: .zero, size: imageSize)
        let clamped = rect.intersection(imageRect)
        guard !clamped.isNull, clamped.width > 0, clamped.height > 0 else { return nil }

        return clamped
    }

    func normalize(rect: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        return CGRect(
            x: rect.origin.x / imageSize.width,
            y: rect.origin.y / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }

    func makeDogState(
        detection: DetectedObject,
        matchedDog: Dog?,
        normalizedBounds: CGRect
    ) -> DogState {
        let identifier = matchedDog.map(deterministicIdentifier(for:)) ?? UUID()
        let displayName = matchedDog?.name ?? detection.label.capitalized

        return DogState(
            id: identifier,
            name: displayName,
            bounds: normalizedBounds,
            action: "Standing",
            confidence: detection.confidence
        )
    }

    func deterministicIdentifier(for dog: Dog) -> UUID {
        let uriString = dog.objectID.uriRepresentation().absoluteString
        let hash = SHA256.hash(data: Data(uriString.utf8))
        var bytes = Array(hash.prefix(16))

        if bytes.count < 16 {
            bytes.append(contentsOf: Array(repeating: 0, count: 16 - bytes.count))
        }

        return bytes.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt8.self)
            return UUID(uuid: (
                buffer[0], buffer[1], buffer[2], buffer[3],
                buffer[4], buffer[5], buffer[6], buffer[7],
                buffer[8], buffer[9], buffer[10], buffer[11],
                buffer[12], buffer[13], buffer[14], buffer[15]
            ))
        }
    }

    func fetchKnownDogs() async -> [Dog] {
        await withCheckedContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Dog> = Dog.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                    let dogs = try self.context.fetch(request)
                    continuation.resume(returning: dogs)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
