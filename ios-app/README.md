# iOS App - MyDogCare

Real-time multi-dog tracking and monitoring application with on-device AI.

## Features

### Bootstrap Phase (Initial 1 Month)
**VLM-Based Data Collection**: Before deploying on-device Behavior/Stress models, the app uses VLM (Vision-Language Model) via `VisionClient.swift` to analyze frames in real-time. 

**Enhanced Pipeline**: Camera → YOLO Detection → ReID Identification → Tagged Image Streaming → 5 Frames → VLM Analysis. By preprocessing frames with YOLO+ReID, the VLM receives context about which dogs are present (name, bbox), enabling more accurate behavior labeling.

Results are logged and uploaded to backend for training data collection (~10k samples). After 1 month, transition to on-device models.

### On-Device AI Pipeline
- **YOLO Object Detection**: YOLOv11-nano for real-time dog detection
- **ReID Identification**: ResNet50-based feature extraction for individual dog identification
- **Behavior Classifier**: Lightweight MLP/1D-CNN for action classification
  - Input: Recent N-frame bbox trajectories (motion vectors)
  - Output: `behaviorProbs` - {"play": 0.8, "rest": 0.1, "chase": 0.05, ...}
  - Implementation: `Services/Vision/BehaviorHead.swift` (planned)
- **Stress Proxy Head**: Small regression model for stress estimation
  - Input: Behavior probs + motion statistics  
  - Output: `stressProxy` (0~1)
  - Implementation: Simple MLP or rule-based + calibration network

### Dual Mode Operation
- **Camera Mode (Sender)**: Dedicated monitoring device
  - 24/7 operation with screen-off prevention
  - Continuous YOLO + ReID processing
  - State packet generation every second
  - Automatic clip triggering on events
  
- **Viewer Mode (Receiver)**: Personal control device
  - AI Chat Interface
  - Care Calendar
  - Real-time monitoring dashboard
  - Historical analysis

### Data Structures
- `DetectedObject`: YOLO output (bbox, confidence, embedding)
- `DogState`: Per-dog state (normalized bbox, speed, behavior probs, stress)
- `PairState`: Pair-wise relations (distance, affinity, tension)
- `DeviceStatePacket`: Complete state snapshot sent to backend

### Core Services
-  `YOLOClient`: CoreML model inference
- `ReIDTracker`: Identity matching
- `StateBuilder`: Convert detections to `DogState`
- `PairBuilder`: Generate pair-wise relationships
- `EventUploader`: Batch upload to backend

## Tech Stack
- Swift 5.9+
- SwiftUI
- CoreML (Vision framework)
- Core Data
- Combine

## Setup
1. Open `MyDogCare.xcodeproj` in Xcode 15+
2. Ensure models are in `Resources/Models/`:
   - `yolo11n.mlpackage`
   - `ResNet50_ReID.mlmodel`
3. Build and run on iOS 17+ device

## Models
Models are exported from `../ai-models/` and copied to `Resources/Models/`.
See `docs/plan/` for detailed implementation guides.
