import AVFoundation
import Combine
import CoreImage
import UIKit

class CameraManager: NSObject, ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var currentPixelBuffer: CVPixelBuffer?
    @Published var permissionGranted = false

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.mydogcare.cameraQueue")
    private let processingQueue = DispatchQueue(label: "com.mydogcare.cameraProcessingQueue")
    private let ciContext = CIContext()
    private let frameStride = 2
    private let maxFrameRate: Double = 12
    private let targetPreviewWidth: CGFloat = 640
    private let burstSnapshotWidth: CGFloat = 512
    private var frameCounter = 0
    private var lastFrameTimestamp: CFTimeInterval = 0

    override init() {
        super.init()
        checkPermission()
    }
    
    deinit {
        stop()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

            if self.captureSession.canSetSessionPreset(.vga640x480) {
                self.captureSession.sessionPreset = .vga640x480
            } else if self.captureSession.canSetSessionPreset(.medium) {
                self.captureSession.sessionPreset = .medium
            }

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }

                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                    ]
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.processingQueue)

                    self.captureSession.addOutput(self.videoOutput)

                    if let connection = self.videoOutput.connection(with: .video) {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                        if connection.isVideoMirroringSupported {
                            connection.isVideoMirrored = false
                        }
                    }
                }

                print("Camera session configured. Waiting for start command.")
            } catch {
                print("Error setting up camera: \(error)")
            }
        }
    }

    func start() {
        sessionQueue.async {
            guard !self.captureSession.isRunning else { return }
            print("Starting camera session...")
            self.captureSession.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            guard self.captureSession.isRunning else { return }
            print("Stopping camera session...")
            self.captureSession.stopRunning()
        }
    }

    // Helper to capture a burst of frames
    func captureBurst(count: Int, interval: TimeInterval) async -> [UIImage] {
        var frames: [UIImage] = []
        for _ in 0..<count {
            let snapshot = await MainActor.run { () -> UIImage? in
                guard let cgImage = self.currentFrame else { return nil }
                return self.prepareSnapshot(from: cgImage)
            }

            if let snapshot {
                frames.append(snapshot)
            }

            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        return frames
    }

    @MainActor
    private func prepareSnapshot(from cgImage: CGImage) -> UIImage {
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
        guard burstSnapshotWidth > 0, image.size.width > burstSnapshotWidth else {
            return image
        }

        let scale = burstSnapshotWidth / image.size.width
        let targetSize = CGSize(width: burstSnapshotWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        frameCounter = (frameCounter + 1) % frameStride
        guard frameCounter == 0 else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let minInterval = maxFrameRate > 0 ? 1.0 / maxFrameRate : 0
        guard now - lastFrameTimestamp >= minInterval else { return }

        autoreleasepool {
            guard let cgImage = makeDisplayImage(from: pixelBuffer) else { return }
            lastFrameTimestamp = now
            DispatchQueue.main.async {
                self.currentFrame = cgImage
                self.currentPixelBuffer = pixelBuffer
            }
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
}
