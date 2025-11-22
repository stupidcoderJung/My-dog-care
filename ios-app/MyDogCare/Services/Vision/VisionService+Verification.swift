import Foundation
import CoreVideo

extension VisionService {
    @MainActor
    static func verifyIntegration() async {
        let visionService = VisionService(
            yoloClient: YOLOClient(),
            reidTracker: try! ReIDTracker()
        )
        
        // Mock data
        let knownDogs: [Dog] = [] // In real app, fetch from Core Data
        
        // Mock pixel buffer (1x1 pixel)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, 1, 1, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        
        guard let buffer = pixelBuffer else { return }
        
        visionService.processFrame(buffer, knownDogs: knownDogs) { detections in
            print("Detected \(detections.count) dogs:")
            for detection in detections {
                print("  - \(detection.dogName ?? "Unknown") (confidence: \(detection.confidence))")
            }
        }
    }
}
