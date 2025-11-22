import torch
import torchvision
import coremltools as ct

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

# 5. Save
mlmodel.save("ResNet50_ReID.mlmodel")
