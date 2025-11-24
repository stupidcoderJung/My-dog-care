# YOLO11-JDE iOS(CoreML) Practical Application Guide

This document is a technical specification for lightweighting the YOLO11-JDE (Object Detection + Re-ID) model to YOLO11n (Nano) specs and porting it to the iOS environment (CoreML) to implement real-time object tracking.

## 1. Project Goals and Strategy

*   **Base Model**: YOLO11n (Nano) - Use Nano (n) instead of Small (s) for mobile real-time processing.
*   **Output**: Bounding Boxes (Detection) + Embeddings (Re-ID Vector).
*   **Format**: CoreML (.mlpackage).
*   **Precision**:
    *   **FP16 (Recommended)**: Optimal balance of performance and accuracy (iPhone NPU optimization).
    *   **Int8 (Optional)**: Use only when extreme capacity reduction is needed (beware of Re-ID accuracy loss).

## 2. Model Configuration (YOLO11s -> YOLO11n Change)

Create `yolo11n-jde.yaml` based on `yolo11s-jde.yaml`. Modify the `scales` value to reduce the depth and width of the model.

**File**: `models/yolo11n-jde.yaml`

```yaml
# YOLO11n-JDE Configuration
nc: 1  # Number of classes (e.g., 1 person)
scales:
  # [depth, width, max_channels]
  n: [0.50, 0.25, 1024]  # YOLO11 Nano specs

backbone:
  # ... (Same as existing yolo11s-jde.yaml)

head:
  # ... (Maintain JDE Head structure)
```

> **Note**: After changing the configuration, you must perform **Fine-tuning** with a dataset (MOT17, CrowdHuman, etc.). An untrained JDE head will not output valid embedding vectors.

## 3. CoreML Conversion and Quantization (Python)

Script to convert PyTorch model to CoreML. Generates two versions: **FP16 (Default)** and Int8 (8-bit).

**File**: `export_ios.py`

```python
import torch
import coremltools as ct
from ultralytics import YOLO
import os

# 1. Settings
MODEL_PATH = 'runs/detect/train/weights/best.pt' # Path to trained model
INPUT_SIZE = (640, 640) # iOS input resolution

print(f"🚀 Loading model from {MODEL_PATH}...")
model = YOLO(MODEL_PATH)
torch_model = model.model.cpu().eval()

# 2. Tracing (JIT Trace)
# JDE models have complex outputs like (Output, Embedding) or [Box, Conf, Embed].
# A wrapper might be needed to ensure correct output return by checking model forward.
print("🔄 Tracing model...")
dummy_input = torch.zeros(1, 3, *INPUT_SIZE)
traced_model = torch.jit.trace(torch_model, dummy_input)

# 3. CoreML Conversion (FP32 -> FP16)
# Apple Neural Engine (NPU) is most efficient at FP16.
print("🔄 Converting to CoreML (FP16)...")
model_fp16 = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="image", shape=dummy_input.shape, scale=1/255.0)], # Includes auto-normalization
    outputs=[
        ct.TensorType(name="boxes"),      # Detection results
        ct.TensorType(name="embeddings")  # Re-ID vectors
    ],
    compute_precision=ct.precision.FLOAT16, # NPU optimization (Required)
    minimum_deployment_target=ct.target.iOS16
)

save_path_fp16 = "YOLO11nJDE_FP16.mlpackage"
model_fp16.save(save_path_fp16)
print(f"✅ Saved FP16 model: {save_path_fp16}")

# 4. CoreML Quantization (FP16 -> Int8 Weights)
# Use if further capacity reduction is needed. (Caution: Embedding accuracy may drop)
print("🔄 Quantizing to Int8 (Linear Quantization)...")
from coremltools.models.neural_network import quantization_utils

# For ML Program (latest format), optimization library is recommended,
# but here is an example using op_selector for compatibility:
import coremltools.optimize.coreml as cto

op_config = cto.OpLinearQuantizerConfig(
    mode="linear_symmetric", 
    weight_threshold=512
)
config = cto.OptimizationConfig(global_config=op_config)

# Compress Weights to 8-bit based on FP16 model
model_int8 = cto.linear_quantize_weights(model_fp16, config=config)

save_path_int8 = "YOLO11nJDE_Int8.mlpackage"
model_int8.save(save_path_int8)
print(f"✅ Saved Int8 model: {save_path_int8}")
```

## 4. Performance Analysis and Bottleneck Precautions

When applying in practice, the most critical point for developers is not NPU inference speed, but **CPU post-processing speed**.

### 📊 Expected Performance (iPhone 13/14 Pro)

*   **YOLO11n (FP16) Inference Speed**: 3ms ~ 6ms (Approx. 150 FPS+ possible)
*   **YOLO11n (Int8) Inference Speed**: Similar to FP16 or slightly faster (Memory bandwidth gain)

### ⚠️ Actual Bottlenecks

Even if the model is fast, if the logic below is slow, the app will struggle to defend even 30fps.

1.  **NMS (Non-Maximum Suppression)**: Filtering thousands of boxes. Very slow if performed on Swift (CPU).
2.  **Tracker Matching**: Cosine Similarity calculation of previous frame objects vs current objects -> Hungarian Algorithm matching.

### 💡 Optimization Guide

*   **Avoid Model Compression**: 8-bit (Int8) conversion can degrade Re-ID embedding vector precision, causing ID Switching (tracking failure). Use **FP16** as default.
*   **Focus on Swift Optimization**: Optimizing the **Swift Tracker Algorithm (JDE/ByteTrack logic)** is much more effective for overall frame defense than reducing model capacity.
*   **Use Accelerate**: If possible, use the Accelerate framework (vDSP) to parallelize cosine similarity calculations.

## 5. iOS Implementation Example (Swift)

Basic structure using Vision framework to infer and receive results.

```swift
import Vision
import CoreML

class JDEInferenceService {
    
    private var request: VNCoreMLRequest?
    
    init() {
        setupModel()
    }
    
    func setupModel() {
        // Recommend loading FP16 model
        guard let modelURL = Bundle.main.url(forResource: "YOLO11nJDE_FP16", withExtension: "mlmodelc") else { return }
        
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
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        // Recommend async execution (global queue)
        try? handler.perform([request!])
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
        }
    }
}
```

## 6. Summary and Work Instructions

1.  **Model Preparation**: Change to `yolo11n` configuration and proceed with dataset training.
2.  **Conversion**: Generate FP16 model using the provided Python script (Int8 is for testing purposes).
3.  **App Development**:
    *   Build inference pipeline with `VNCoreMLRequest`.
    *   Receive inference results (Box, Embedding) and pass to JDE Tracker implemented in Swift.
    *   **Caution**: Tracker operation optimization is the key to performance.
