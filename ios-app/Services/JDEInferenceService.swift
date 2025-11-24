import Vision
import CoreML
import UIKit

class JDEInferenceService {
    
    private var request: VNCoreMLRequest?
    
    init() {
        setupModel()
    }
    
    func setupModel() {
        // Recommend loading FP16 model
        // Note: The model file "YOLO11nJDE_FP16.mlmodelc" is expected to be in the bundle.
        // If it's not there yet (since we haven't trained/exported it), this will fail gracefully.
        guard let modelURL = Bundle.main.url(forResource: "YOLO11nJDE_FP16", withExtension: "mlmodelc") else {
            print("⚠️ YOLO11nJDE_FP16 model not found in bundle.")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all // Neural Engine usage required
            
            let coremlModel = try MLModel(contentsOf: modelURL, configuration: config)
            let visionModel = try VNCoreMLModel(for: coremlModel)
            
            self.request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                self?.processResults(request: request)
            }
            // Use ScaleFill if input image is not 640x640 (Avoid Crop)
            self.request?.imageCropAndScaleOption = .scaleFill 
        } catch {
            print("Model Init Error: \(error)")
        }
    }
    
    func run(pixelBuffer: CVPixelBuffer) {
        guard let request = self.request else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        // Recommend async execution (global queue)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Inference Error: \(error)")
            }
        }
    }
    
    private func processResults(request: VNRequest?) {
        guard let results = request?.results as? [VNCoreMLFeatureValueObservation] else { return }
        
        var boxes: MLMultiArray?
        var embeddings: MLMultiArray?
        
        // Find by Output name specified during Model Export
        for result in results {
            if result.featureName == "boxes" {
                boxes = result.featureValue.multiArrayValue
            } else if result.featureName == "embeddings" {
                embeddings = result.featureValue.multiArrayValue
            }
        }
        
        if let b = boxes, let e = embeddings {
            // TODO: Call Tracker update function here
            // updateTracker(boxes: b, feats: e)
            print("📦 Boxes Shape: \(b.shape), 🧠 Embeddings Shape: \(e.shape)")
        }
    }
}
