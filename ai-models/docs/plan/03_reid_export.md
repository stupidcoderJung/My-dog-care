# 🆔 Task 3: ReID Export

## 🎯 Objective
Export a lightweight Re-Identification (ReID) model to CoreML. This model extracts a feature vector (embedding) from a dog's image to identify it.

## 📋 Detailed Steps
1.  **Select Architecture**: Use `ResNet50` (robust) or `OSNet` (lightweight). For this task, we will use a standard **ResNet50** pre-trained on ImageNet as a baseline feature extractor (removing the classification head).
2.  **Prepare Script**:
    *   Load `torchvision.models.resnet50(pretrained=True)`.
    *   Remove the final fully connected layer (`fc`).
    *   Trace the model with a dummy input (224x224).
    *   Convert to CoreML using `coremltools`.
3.  **Run Export**: Generate `.mlmodel`.

## 🤖 AI Execution Prompt
(Copy this to the AI Agent)

```text
@ai-models/

I need you to execute **Task 3: ReID Export**.

**Instructions**:
1.  Ensure you are in `ai-models/`.
2.  Create a Python script named `export_reid.py` with the following logic:
```python
    import torch
    import torchvision
    import coremltools as ct
    from coremltools.models.neural_network import quantization_utils

    # 1. Load Pre-trained ResNet50
    model = torchvision.models.resnet50(weights=torchvision.models.ResNet50_Weights.DEFAULT)
    
    # 2. Remove Classification Head (We want the feature vector)
    # ResNet's last layer is 'fc'. We replace it with Identity or just slice.
    # A common trick is to set it to Identity, but for CoreML it's cleaner to just trace and not include the output.
    class FeatureExtractor(torch.nn.Module):
        def __init__(self, original_model):
            super(FeatureExtractor, self).__init__()
            self.features = torch.nn.Sequential(*list(original_model.children())[:-1]) # Remove fc
            
        def forward(self, x):
            x = self.features(x)
            x = torch.flatten(x, 1)
            return x

    feature_model = FeatureExtractor(model)
    feature_model.eval()

    # 3. Trace
    dummy_input = torch.rand(1, 3, 224, 224)
    traced_model = torch.jit.trace(feature_model, dummy_input)

    # 4. Convert to CoreML
    mlmodel = ct.convert(
        traced_model,
        inputs=[ct.ImageType(name="image", shape=dummy_input.shape, scale=1/255.0, bias=[0,0,0])],
        outputs=[ct.TensorType(name="embedding")],
        convert_to="neuralnetwork"
    )
    
    # 5. Quantize (Int8)
    print("🔨 Applying Int8 Quantization...")
    quantized_model = quantization_utils.quantize_weights(
        mlmodel,
        nbits=8,
        quantization_mode="linear"
    )

    # 6. Save
    quantized_model.save("ResNet50_ReID_Int8.mlmodel")
    print("✅ Quantized model saved to: ResNet50_ReID_Int8.mlmodel")
    ```
3.  Run this script.
4.  Verify that `ResNet50_ReID_Int8.mlmodel` is created (approx. 25MB).

**Deliverable**:
*   `export_reid.py` script.
*   `ResNet50_ReID_Int8.mlmodel` file.
```
