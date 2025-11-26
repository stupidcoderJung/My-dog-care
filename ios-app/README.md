# iOS App - MyDogCare

Real-time multi-dog tracking and monitoring application with on-device AI.

## Features

### Bootstrap Phase (Initial 1 Month)
**VLM-Based Data Collection**: Before deploying on-device Behavior/Stress models, the app uses VLM (Vision-Language Model) via `VisionClient.swift` to analyze frames in real-time. 

**Enhanced Pipeline**: Camera → YOLO Detection → ReID Identification → Tagged Image Streaming → 5 Frames → VLM Analysis. By preprocessing frames with YOLO+ReID, the VLM receives context about which dogs are present (name, bbox), enabling more accurate behavior labeling.

Results are logged and uploaded to backend for training data collection (~10k samples). After 1 month, transition to on-device models.

### On-Device AI Pipeline
- **YOLO Object Detection**: YOLOv11-nano for real-time dog detection
- **DeepSORT Tracking System**: Advanced multi-object tracking
  - **Kalman Filter**: Constant velocity model for position prediction
  - **Temporal Voting**: 10-frame majority vote for identity confirmation
  - **ReID Optimization**: 99% reduction after confirmation (first 10 frames only)
  - **Track Management**: Handles occlusions, crossings, and ID persistence
- **ReID Identification**: ResNet50-based feature extraction (Int8 quantized)
  - Int8 quantization reduces model size from 98MB to 23.7MB (4x smaller)
  - Inference speed improved 2-3x on Neural Engine
  - **Robust Matching**: Voting (Top-3) + Margin Check (5%) for similar dogs
  - Core Data caching eliminates per-frame database queries
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
  - Continuous YOLO + DeepSORT processing
  - State packet generation every second
  - Automatic clip triggering on events
  
- **Viewer Mode (Receiver)**: Personal control device
  - AI Chat Interface
  - Care Calendar
  - Real-time monitoring dashboard
  - Historical analysis

### Data Structures
- `DetectedObject`: YOLO output (bbox, confidence, trackId, embedding, dogId, dogName)
- `DogState`: Per-dog state (normalized bbox, speed, behavior probs, stress)
- `PairState`: Pair-wise relations (distance, affinity, tension)
- `DeviceStatePacket`: Complete state snapshot sent to backend

### Core Services
- `YOLOClient`: CoreML model inference
- `ReIDTracker`: Identity matching with robust voting
- **`DeepSortTracker`**: Two-phase tracking (IoU → ReID → Update)
- **`KalmanFilter`**: Motion prediction for smooth tracking
- **`Track`**: Individual track state management with temporal voting
- `VisionClient`: VLM-based behavior analysis
- `VLMStateMapper`: Maps VLM text response to structured `DogState`
- `StatePacketBuilder`: Aggregates states into `DeviceStatePacket`
- `EventUploader`: Buffers and uploads packets to backend (with offline support)

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
   - `ResNet50_ReID_Int8.mlmodel`
3. Build and run on iOS 17+ device

## Models
Models are exported from `../ai-models/` and copied to `Resources/Models/`.
See `docs/plan/` for detailed implementation guides.
