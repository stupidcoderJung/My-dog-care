import CoreGraphics
import CoreML
import CoreVideo
import Foundation
import Vision

// DetectedObject is now in Models/DetectedObject.swift

enum YOLOClientError: Error, LocalizedError {
    case modelResourceMissing
    case requestUnavailable
    case predictionFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .modelResourceMissing:
            return "Unable to locate or load the YOLO model resource."
        case .requestUnavailable:
            return "Vision request is not configured. Initialize the YOLO client before predicting."
        case .predictionFailed(let underlying):
            return "Vision request failed with error: \(underlying.localizedDescription)"
        }
    }
}

final class YOLOClient {
    private enum Constants {
        static let confidenceThreshold: Float = 0.1 // Lowered for debugging
        static let allowedLabels: Set<String> = ["dog"]
        static let queueLabel = "com.mydogcare.yolo-client"
    }

    private var request: VNCoreMLRequest?
    private let processingQueue = DispatchQueue(label: Constants.queueLabel, qos: .userInitiated)

    init() {
        self.request = YOLOClient.makeRequest()
    }

    func predict(pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedObject]) -> Void) {
        guard let request else {
            print("YOLOClient: Request unavailable")
            completion([])
            return
        }

        // Perform synchronously on processingQueue, just like YoloStream
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([request])
            
            let detections = YOLOClient.parseResults(
                from: request,
                confidenceThreshold: Constants.confidenceThreshold,
                allowedLabels: Constants.allowedLabels
            )
            completion(detections)
        } catch {
            print("YOLOClient: Vision request failed: \(error)")
            completion([])
        }
    }
}

private extension YOLOClient {
    static func makeRequest() -> VNCoreMLRequest? {
        do {
            let model = try loadVisionModel()
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .scaleFill
            return request
        } catch {
            print("--------------------------------------------------")
            print("CRITICAL ERROR: YOLO Model failed to load: \(error)")
            print("PLEASE ENSURE 'yolo11n.mlpackage' IS ADDED TO THE XCODE PROJECT TARGET.")
            print("Location: ios-app/MyDogCare/Resources/Models/yolo11n.mlpackage")
            print("--------------------------------------------------")
            return nil
        }
    }

    static func loadVisionModel() throws -> VNCoreMLModel {
        guard let modelURL = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else {
            throw YOLOClientError.modelResourceMissing
        }

        // Enable Metal/GPU acceleration
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all  // Use CPU, GPU, and Neural Engine
        
        let mlModel = try MLModel(contentsOf: modelURL, configuration: configuration)
        return try VNCoreMLModel(for: mlModel)
    }

    static func parseResults(
        from request: VNCoreMLRequest,
        confidenceThreshold: Float,
        allowedLabels: Set<String>
    ) -> [DetectedObject] {
        guard let observations = request.results as? [VNRecognizedObjectObservation] else {
            return []
        }

        let normalizedAllowed = Set(allowedLabels.map { $0.lowercased() })

        return observations.compactMap { observation in
            guard let topLabel = observation.labels.first else { return nil }
            print("YOLOClient: Observation label: \(topLabel.identifier), confidence: \(topLabel.confidence)")
            
            guard topLabel.confidence > confidenceThreshold
            else {
                return nil
            }

            if !normalizedAllowed.isEmpty &&
                !normalizedAllowed.contains(topLabel.identifier.lowercased()) {
                return nil
            }

            return DetectedObject(
                bbox: observation.boundingBox,
                confidence: topLabel.confidence,
                classId: 0, // Assuming 0 for 'dog' for now, or we could map labels to IDs
                label: topLabel.identifier
            )
        }
    }
}
