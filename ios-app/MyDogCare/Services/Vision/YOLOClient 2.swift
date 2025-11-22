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
        static let confidenceThreshold: Float = 0.5
        static let allowedLabels: Set<String> = ["dog"]
        static let queueLabel = "com.mydogcare.yolo-client"
    }

    private var request: VNCoreMLRequest?
    private let processingQueue = DispatchQueue(label: Constants.queueLabel, qos: .userInitiated)

    init() {
        self.request = YOLOClient.makeRequest()
    }

    func predict(pixelBuffer: CVPixelBuffer) async throws -> [DetectedObject] {
        try Task.checkCancellation()
        guard let request else {
            throw YOLOClientError.requestUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
                    request.results = nil
                    try handler.perform([request])

                    let detections = YOLOClient.parseResults(
                        from: request,
                        confidenceThreshold: Constants.confidenceThreshold,
                        allowedLabels: Constants.allowedLabels
                    )
                    continuation.resume(returning: detections)
                } catch {
                    continuation.resume(throwing: YOLOClientError.predictionFailed(underlying: error))
                }
            }
        }
    }
}

private extension YOLOClient {
    static func makeRequest() -> VNCoreMLRequest? {
        guard let model = try? loadVisionModel() else {
            return nil
        }

        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        return request
    }

    static func loadVisionModel() throws -> VNCoreMLModel {
        if let model = try? VNCoreMLModel(for: yolo11n().model) {
            return model
        }

        guard let modelURL = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else {
            throw YOLOClientError.modelResourceMissing
        }

        let mlModel = try MLModel(contentsOf: modelURL)
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
            guard let topLabel = observation.labels.first,
                  topLabel.confidence > confidenceThreshold
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
