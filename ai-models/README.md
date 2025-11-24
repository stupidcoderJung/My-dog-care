# AI Models - MyDogCare

Model training, export, and VLM auto-labeling scripts.

## Models

### 1. YOLO (Object Detection)
- **Model**: YOLOv11-nano / YOLOv12-nano
- **Input**: 640x640 RGB image
- **Output**: Bounding boxes, class IDs, confidence scores, (optional) embeddings
- **Export**: CoreML with baked-in NMS

**Training**:
```bash
# Fine-tune on custom dog dataset
python train_yolo.py --data dogs.yaml --epochs 100
```

**Export**:
```bash
# Export to CoreML with NMS
python export_yolo.py
# Output: yolo11n.mlpackage
```

### 2. ReID (Re-Identification)
- **Model**: ResNet50 (feature extractor)
- **Input**: 224x224 RGB image (cropped dog)
- **Output**: 512-d feature vector (or 128-d with projection head)
- **Export**: CoreML

**Training**:
```bash
# Train on dog ReID dataset
python train_reid.py --dataset dog_reid --embedding_dim 512
```

**Export**:
```bash
# Export to CoreML
python export_reid.py
# Output: ResNet50_ReID.mlmodel
```

### 3. Behavior Classifier (Lightweight Head)
- **Model**: Small MLP or 1D-CNN
- **Input Features**: Recent N-frame bbox trajectories (motion vectors)
  - Normalized speed, direction, acceleration
  - Distance changes between frames
- **Output**: Behavior probabilities (play, rest, chase, avoid, freeze, face_off)
- **Export**: CoreML

**Training**:
```bash
# Train on annotated sequences
python train_behavior.py --data behavior_sequences.json --epochs 50
```

**Export**:
```bash
python export_behavior.py
# Output: BehaviorClassifier.mlmodel
```


### 4. Stress Proxy Head
- **Model**: Small regression head (MLP with 1-2 hidden layers)
- **Input**: 
  - Behavior probs vector
  - Motion statistics (speed variance, direction changes)
  - (Optional) Pose-based features
- **Output**: Stress estimate (0~1)
- **Implementation Options**:
  - **Pure ML**: Train on annotated stress labels
  - **Hybrid**: Rule-based baseline + calibration network

**Training**:
```bash
# Train stress regression model
python train_stress.py --data stress_labels.json
```

**Export**:
```bash
python export_stress.py
# Output: StressProxy.mlmodel
```

## VLM Auto-Labeling (Gemini 2.5 Pro)

### Hard Example Mining
```bash
# Select uncertain detections and interesting clips
python mine_hard_examples.py --confidence_range 0.3 0.5
```

### Annotation Worker
```bash
# Send clips to Gemini 2.5 Pro for structured labeling
python annotate_clips.py --input hard_examples/ --output annotations/
```

**Annotation Schema**:
```json
{
  "clip_id": "uuid",
  "caption": "Two dogs are play-fighting on the couch.",
  "scene_tags": ["indoor", "play"],
  "per_dog": {
    "dog_A": { "behavior": ["play"], "emotion": ["excited"] },
    "dog_B": { "behavior": ["play"], "emotion": ["relaxed"] }
  },
  "interaction": { "type": "play", "tension_level": "low" },
  "risk_estimate": { "stage": "none", "reason": "No aggressive signals." }
}
```

### Training Data Loop
```bash
# Aggregate annotations and retrain models
python aggregate_labels.py
python retrain_behavior.py --annotations annotations/
```

## Directory Structure
```
ai-models/
├── export_yolo.py          # YOLO CoreML export
├── export_reid.py          # ReID CoreML export
├── train_yolo.py           # YOLO fine-tuning
├── train_reid.py           # ReID training
├── train_behavior.py       # Behavior classifier training
├── mine_hard_examples.py   # Hard example selector
├── annotate_clips.py       # VLM annotation worker
├── docs/plan/              # Detailed task plans
└── venv/                   # Python virtual environment
```

## Setup
```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install ultralytics coremltools torch torchvision google-generativeai
```

## Tech Stack
- PyTorch
- Ultralytics (YOLO)
- CoreML Tools
- Google Generative AI (Gemini 2.5 Pro)
- NumPy, Pandas
