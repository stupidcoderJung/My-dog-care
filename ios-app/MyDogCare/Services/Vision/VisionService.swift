import AVFoundation
import Combine
import CoreData
import CoreGraphics
import CoreImage
import CoreVideo
import CryptoKit
import Foundation
import UIKit

struct DogUIState: Identifiable {
    let id: UUID
    let name: String
    let bounds: CGRect
    let action: String
    let confidence: Float
}

final class VisionService: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: CGImage?
    @Published var detectedDogs: [DogUIState] = []
    @Published var lastDetections: [DetectedObject] = []
    @Published var currentDogStates: [DogState] = [] // Rich data states for logging
    @Published var currentPacket: DeviceStatePacket?

    private var cachedKnownDogs: [Dog] = [] // Cache for known dogs
    private var frameBuffer: [(UIImage, [DetectedObject], Date)] = [] // Synchronized buffer for VLM (Image, Detections, Timestamp)
    private var trackIdMap: [Int: UUID] = [:] // Temporal Consistency: TrackID -> DogID

    private let yoloClient: YOLOClient
    private let reidTracker: ReIDTracker?
    private let context: NSManagedObjectContext
    private let visionClient: VisionClient
    private let imageTagger: ImageTagger
    private let vlmStateMapper: VLMStateMapper
    private let statePacketBuilder: StatePacketBuilder
    private let deepSortTracker = DeepSortTracker() // DeepSORT Tracker
    
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
    
    // FPS Tracking
    @Published var fps: Double = 0.0
    private var lastFrameTime: TimeInterval = 0
    private var frameCountForFPS: Int = 0

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
        self.vlmStateMapper = VLMStateMapper()
        self.statePacketBuilder = StatePacketBuilder()
        
        super.init()
        configureSession()
    }
    
    override convenience init() {
        let yolo = YOLOClient()
        let reid = try? ReIDTracker()
        self.init(yoloClient: yolo, reidTracker: reid)
    }

    // ... (existing properties)
    func startProcessing() {
        // Fetch dogs once when starting
        Task {
            self.cachedKnownDogs = await fetchKnownDogs()
            print("🐕 VisionService: Cached \(self.cachedKnownDogs.count) dogs for identification")
        }
        
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
        
        // FPS Calculation
        let currentTime = CACurrentMediaTime()
        if lastFrameTime == 0 {
            lastFrameTime = currentTime
        }
        
        frameCountForFPS += 1
        let elapsed = currentTime - lastFrameTime
        
        if elapsed >= 1.0 {
            let currentFPS = Double(frameCountForFPS) / elapsed
            Task { @MainActor in
                self.fps = currentFPS
            }
            lastFrameTime = currentTime
            frameCountForFPS = 0
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
            // Use cached dogs instead of fetching every frame
            let knownDogs = self.cachedKnownDogs
            
            processFrame(pixelBuffer, timestamp: Date(), knownDogs: knownDogs) { [weak self] detections, timestamp in
                guard let self else { return }
                
                let states = detections.map { detection in
                    DogUIState(
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


    
    // Add a method to refresh manually if needed (e.g. after adding a dog)
    func refreshKnownDogs() {
        Task {
            self.cachedKnownDogs = await fetchKnownDogs()
            print("🔄 VisionService: Refreshed dog cache. Count: \(self.cachedKnownDogs.count)")
        }
    }
    
    // MARK: - Processing

    func processFrame(_ pixelBuffer: CVPixelBuffer, 
                     timestamp: Date,
                     knownDogs: [Dog],
                     completion: @escaping ([DetectedObject], Date) -> Void) {
        
        yoloClient.predict(pixelBuffer: pixelBuffer) { [weak self] detections in
            guard let self else {
                completion([], timestamp)
                return
            }
            
            let imageSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            
            // PHASE 1: DeepSORT preliminary matching (IoU only, no ReID)
            let detectionsNeedingReID = self.deepSortTracker.matchWithoutReID(detections: detections)
            
            // PHASE 2: Run ReID ONLY for detections that need it
            var reidDetections = detections
            
            if !detectionsNeedingReID.isEmpty {
                let syncQueue = DispatchQueue(label: "com.mydogcare.detectionSync")
                let reIDGroup = DispatchGroup()
                
                for detectionIdx in detectionsNeedingReID {
                    var detection = detections[detectionIdx]
                    
                    if let tracker = self.reidTracker,
                       let cropRect = self.rectForCropping(from: detection.bbox, imageSize: imageSize) {
                        let croppedImage = ciImage.cropped(to: cropRect)
                        reIDGroup.enter()
                        Task {
                            do {
                                let embedding = try await tracker.extractEmbedding(from: croppedImage)
                                detection.embedding = embedding
                                
                                let dogId = tracker.identifyRobust(
                                    embedding: embedding,
                                    knownDogs: knownDogs,
                                    threshold: 0.4,
                                    margin: 0.05
                                )
                                
                                detection.dogId = dogId
                                if let dogId = dogId,
                                   let dog = knownDogs.first(where: { $0.uuid == dogId }) {
                                    detection.dogName = dog.name
                                }
                            } catch {
                                print("⚠️ ReID failed for detection #\(detectionIdx): \(error)")
                            }
                            
                            syncQueue.sync {
                                reidDetections[detectionIdx] = detection
                            }
                            reIDGroup.leave()
                        }
                    }
                }
                
                reIDGroup.notify(queue: .main) {
                    // PHASE 3: DeepSORT final update with ReID results
                    let trackedDetections = self.deepSortTracker.finalizeWithReID(detections: reidDetections)
                    
                    self.lastDetections = trackedDetections
                    
                    // Update Frame Buffer
                    if let cgImage = self.currentFrame {
                        let uiImage = UIImage(cgImage: cgImage)
                        self.frameBuffer.append((uiImage, trackedDetections, timestamp))
                        if self.frameBuffer.count > 10 {
                            self.frameBuffer.removeFirst()
                        }
                    }
                    
                    completion(trackedDetections, timestamp)
                    
                    // Generate packet
                    let dogStates = trackedDetections.map { self.mapToDogState(detection: $0, imageSize: imageSize, timestamp: timestamp) }
                    _ = self.generateStatePacket(dogStates: dogStates, sessionId: UUID().uuidString)
                }
            } else {
                // No ReID needed - all tracks confirmed!
                DispatchQueue.main.async {
                    let trackedDetections = self.deepSortTracker.finalizeWithReID(detections: reidDetections)
                    
                    self.lastDetections = trackedDetections
                    
                    // Update Frame Buffer
                    if let cgImage = self.currentFrame {
                        let uiImage = UIImage(cgImage: cgImage)
                        self.frameBuffer.append((uiImage, trackedDetections, timestamp))
                        if self.frameBuffer.count > 10 {
                            self.frameBuffer.removeFirst()
                        }
                    }
                    
                    completion(trackedDetections, timestamp)
                    
                    // Generate packet
                    let dogStates = trackedDetections.map { self.mapToDogState(detection: $0, imageSize: imageSize, timestamp: timestamp) }
                    _ = self.generateStatePacket(dogStates: dogStates, sessionId: UUID().uuidString)
                }
            }
        }
    }
    
    func analyzeWithVLM(
        knownDogs: [Dog]
    ) async throws -> (VisionResponse, [UIImage], [DebugTurn]) {
        // Use last 5 frames from buffer (resized to 320px in VisionClient)
        let bufferSnapshot = frameBuffer.suffix(5)
        guard !bufferSnapshot.isEmpty else {
            throw NSError(domain: "VisionService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No frames in buffer"])
        }
        
        let taggedFrames = bufferSnapshot.map { (image, detections, _) in
            imageTagger.tagImage(image, detections: detections)
        }
        
        let (response, debugTurns) = try await visionClient.analyzeStream(
            images: taggedFrames,
            dogs: knownDogs
        )
        
        // Map VLM response to DogState (Rich Data)
        if let (lastImage, lastDetections, lastTimestamp) = bufferSnapshot.last {
             let frameSize = lastImage.size
             let dogStates = vlmStateMapper.mapToDogStates(
                 vlmResponse: response,
                 detections: lastDetections,
                 frameSize: frameSize
             )
             
             await MainActor.run {
                 self.currentDogStates = dogStates
                 print("📊 VisionService: Updated currentDogStates with \(dogStates.count) items")
                 for state in dogStates {
                     print("  - Dog: \(state.dogId?.uuidString ?? "Unknown")")
                     print("    Action: \(state.vlmAction ?? "nil") -> \(state.behaviorProbs)")
                     print("    Emotion: \(state.vlmEmotion ?? "nil") -> Stress: \(state.stressProxy ?? 0.0)")
                 }
                 
                 // Generate packet with rich VLM data
                 _ = self.generateStatePacket(dogStates: dogStates, sessionId: UUID().uuidString)
             }
        }
        
        return (response, taggedFrames, debugTurns)
    }

    func generateStatePacket(
        dogStates: [DogState],
        sessionId: String
    ) -> DeviceStatePacket {
        let packet = statePacketBuilder.buildPacket(
            dogStates: dogStates,
            sessionId: sessionId,
            fps: Float(self.fps)
        )
        
        Task { @MainActor in
            self.currentPacket = packet
        }
        return packet
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
    ) -> DogUIState {
        let identifier = matchedDog?.uuid ?? UUID()
        let displayName = matchedDog?.name ?? detection.label.capitalized

        return DogUIState(
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
    
    private func mapToDogState(detection: DetectedObject, imageSize: CGSize, timestamp: Date) -> DogState {
        let normRect = normalize(rect: detection.bbox, imageSize: imageSize)
        let bboxNorm = BBoxNorm(
            cx: Float(normRect.midX),
            cy: Float(normRect.midY),
            w: Float(normRect.width),
            h: Float(normRect.height)
        )
        
        return DogState(
            timestamp: timestamp,
            dogId: detection.dogId,
            tempTrackId: detection.trackId ?? 0,
            bboxNorm: bboxNorm,
            speedPx: nil,
            directionRad: nil,
            behaviorProbs: [:],
            stressProxy: nil,
            vlmAction: nil,
            vlmEmotion: nil
        )
    }
}
