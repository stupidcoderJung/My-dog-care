import torch
import coremltools as ct
from ultralytics import YOLO
import os

# 1. Settings
MODEL_PATH = 'runs/detect/train/weights/best.pt' # Path to trained model
INPUT_SIZE = (640, 640) # iOS input resolution

# Check if model exists, if not, warn user (or use a placeholder if appropriate for testing logic)
if not os.path.exists(MODEL_PATH):
    print(f"⚠️ Warning: Model file not found at {MODEL_PATH}. Please ensure you have trained the model.")
    # For the purpose of this script creation, we'll proceed but it will fail at runtime without the file.
    # In a real scenario, we might download a dummy or exit.
    
print(f"🚀 Loading model from {MODEL_PATH}...")
try:
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
    # from coremltools.models.neural_network import quantization_utils # Old way

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

except Exception as e:
    print(f"❌ Error: {e}")
