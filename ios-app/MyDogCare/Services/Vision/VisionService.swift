import AVFoundation
import Combine
import CoreData
import CoreGraphics
import CoreImage
import CoreVideo
import CryptoKit
import Foundation
import UIKit

struct DogState: Identifiable {
    let id: UUID
    let name: String
    let bounds: CGRect
    let action: String
    let confidence: Float
}

final class VisionService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: CGImage?
    @Published var detectedDogs: [DogState] = []
    @Published var lastDetections: [DetectedObject] = []

    private let yoloClient: YOLOClient
    private let reidTracker: ReIDTracker?
    private let context: NSManagedObjectContext
    private let visionClient: VisionClient
    private let imageTagger: ImageTagger
    
    // Camera session (integrated from CameraManager)
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.mydogcare.cameraSession")
    private let processingQueue = DispatchQueue(label: "com.mydogcare.visionProcessing", qos: .userInitiated)
    private let ciContext = CIContext()
    
    // Frame control
    private var isProcessingFrame = false
    private var frameCounter = 0
    private let frameStride = 2  // Process every 2nd frame like YoloStream
    private var isConfigured = false
    
    // Display optimization
    private let targetPreviewWidth: CGFloat = 640
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    nonisolated init(
        yoloClient: YOLOClient,
        reidTracker: ReIDTracker?,
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext
    ) {
        self.yoloClient = yoloClient
        self.reidTracker = reidTracker
        self.context = context
        
        // Initialize MainActor-isolated types
        let client = MainActor.assumeIsolated { VisionClient() }
        self.visionClient = client
        self.imageTagger = ImageTagger()
        
        super.init()
        configureSession()
    }
    
    override convenience init() {
        let yolo = YOLOClient()
        let reid = try? ReIDTracker()
        self.init(yoloClient: yolo, reidTracker: reid)
    }

    func startProcessing() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func stopProcessing() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
        
        isProcessingFrame = false
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Check processing flag (no isolation needed - simple bool read)
        guard !isProcessingFrame else { return }
        
        // Frame striding to reduce processing load
        frameCounter = (frameCounter + 1) % frameStride
        guard frameCounter == 0 else { return }
        
        // Update UI frame on main thread
        if let cgImage = makeDisplayImage(from: pixelBuffer) {
            Task { @MainActor in
                self.currentFrame = cgImage
            }
        }
        
        // Mark as processing
        isProcessingFrame = true
        
        // Process detection on background queue
        Task {
            let knownDogs = await fetchKnownDogs()
            
            processFrame(pixelBuffer, knownDogs: knownDogs) { [weak self] detections in
                guard let self else { return }
                
                let states = detections.map { detection in
                    DogState(
                        id: detection.dogId ?? detection.id,
                        name: detection.dogName ?? detection.label.capitalized,
                        bounds: detection.bbox,
                        action: "Standing",
                        confidence: detection.confidence
                    )
                }
                
                DispatchQueue.main.async {
                    self.detectedDogs = states
                    self.isProcessingFrame = false
                }
            }
        }
    }
    
    // MARK: - Processing

    func processFrame(_ pixelBuffer: CVPixelBuffer, 
                     knownDogs: [Dog],
                     completion: @escaping ([DetectedObject]) -> Void) {
        // 🐕 LOG: Known dogs
        print("🐕 ProcessFrame: Known dogs count: \(knownDogs.count)")
        for dog in knownDogs {
            let dogName = dog.name ?? "unnamed"
            let hasEmbedding = dog.embedding != nil
            let refCount = dog.referenceEmbeddingsList.count
            print("  - \(dogName): has embedding: \(hasEmbedding), refs: \(refCount)")
            if let emb = dog.embedding {
                print("    Legacy embedding size: \(emb.count)")
            }
        }
        
        yoloClient.predict(pixelBuffer: pixelBuffer) { [weak self] detections in
            guard let self else {
                completion([])
                return
            }
            
            print("🎯 YOLO detected \(detections.count) objects")
            
            let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            var identifiedDetections: [DetectedObject] = []
            let syncQueue = DispatchQueue(label: "com.mydogcare.detectionSync")
            let reIDGroup = DispatchGroup()
            
            for (index, detection) in detections.enumerated() {
                var identified = detection
                
                if let tracker = self.reidTracker,
                   let cropRect = self.rectForCropping(from: detection.bbox, imageSize: imageSize) {
                    print("✅ ReIDTracker available for detection #\(index)")
                    let croppedImage = ciImage.cropped(to: cropRect)
                    reIDGroup.enter()
                    Task {
                        do {
                            let embedding = try await tracker.extractEmbedding(from: croppedImage)
                            print("  📊 Extracted embedding (size: \(embedding.count))")
                            identified.embedding = embedding
                            
                            let dogId = tracker.identify(
                                embedding: embedding,
                                knownDogs: knownDogs,
                                threshold: 0.4  // Lowered to 40% as requested
                            )
                            
                            identified.dogId = dogId
                            
                            if let dogId = dogId,
                               let dog = knownDogs.first(where: { $0.uuid == dogId }) {
                                identified.dogName = dog.name
                                print("🎉 MATCH FOUND! Dog ID: \(dogId), Name: \(dog.name ?? "unknown")")
                            } else {
                                print("❌ No match for detection #\(index) (similarity < threshold)")
                            }
                        } catch {
                            print("⚠️ ReID failed for detection #\(index): \(error)")
                        }
                        
                        // Thread-safe append
                        syncQueue.sync {
                            identifiedDetections.append(identified)
                        }
                        reIDGroup.leave()
                    }
                } else {
                    if self.reidTracker == nil {
                        print("⚠️ ReIDTracker is nil - cannot identify detection #\(index)")
                    } else {
                        print("⚠️ Could not crop detection #\(index)")
                    }
                    syncQueue.sync {
                        identifiedDetections.append(identified)
                    }
                }
            }
            
            reIDGroup.notify(queue: .main) {
                print("✨ ProcessFrame complete: \(identifiedDetections.count) detections processed")
                for (idx, det) in identifiedDetections.enumerated() {
                    print("  Detection #\(idx): dogName=\(det.dogName ?? "nil"), dogId=\(det.dogId?.uuidString ?? "nil")")
                }
                self.lastDetections = identifiedDetections
                completion(identifiedDetections)
            }
        }
    }
    
    func analyzeWithVLM(
        frameHistory: [UIImage],
        detections: [DetectedObject],
        knownDogs: [Dog]
    ) async throws -> VisionResponse {
        let recentFrames = Array(frameHistory.suffix(5))
        let taggedFrames = recentFrames.map { frame in
            imageTagger.tagImage(frame, detections: detections)
        }
        
        let (response, _) = try await visionClient.analyzeStream(
            images: taggedFrames,
            dogs: knownDogs
        )
        
        return response
    }

    // MARK: - Camera Session Configuration
    
    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.isConfigured else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .vga640x480
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("Unable to access back camera")
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }
            } catch {
                print("Camera input error: \(error)")
            }
            
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)
            
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
                self.videoOutput.connection(with: .video)?.videoOrientation = .portrait
            }
            
            self.captureSession.commitConfiguration()
            self.isConfigured = true
        }
    }
    
    private func makeDisplayImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent.integral
        guard extent.width > 0, extent.height > 0 else { return nil }

        var imageForDisplay = ciImage
        if extent.width > targetPreviewWidth, targetPreviewWidth > 0 {
            let scale = targetPreviewWidth / extent.width
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            imageForDisplay = ciImage.transformed(by: transform)
        }

        let outputRect = imageForDisplay.extent.integral
        return ciContext.createCGImage(imageForDisplay, from: outputRect)
    }

    // MARK: - Helpers

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
        let identifier = matchedDog?.uuid ?? UUID()
        let displayName = matchedDog?.name ?? detection.label.capitalized

        return DogState(
            id: identifier,
            name: displayName,
            bounds: normalizedBounds,
            action: "Standing",
            confidence: detection.confidence
        )
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
