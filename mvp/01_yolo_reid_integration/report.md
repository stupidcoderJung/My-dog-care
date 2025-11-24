# Report: Step 01 - YOLO + ReID Integration

## ✅ Status: Completed (Extended with DeepSORT)

The integration of YOLOv11 for object detection and ResNet50 for Re-Identification (ReID) has been successfully implemented with significant enhancements. The system now includes **DeepSORT tracking** for robust identity management and **Temporal Voting** to reduce false positives.

## 🏗 Implementation Details

### Core Components
1.  **VisionService**: Orchestrates the two-phase pipeline.
    -   Captures frames from `AVCaptureSession`.
    -   **Phase 1**: DeepSORT preliminary matching (IoU-based, no ReID).
    -   **Phase 2**: Selective ReID execution (only for unconfirmed tracks).
    -   **Phase 3**: DeepSORT final update with ReID results.
    -   Publishes `detectedDogs` (as `DogUIState`) for UI consumption.
2.  **YOLOClient**: Wraps the YOLOv11 CoreML model.
    -   Returns `[DetectedObject]` with bounding boxes and confidence scores.
3.  **ReIDTracker**: Wraps the ResNet50 CoreML model with improvements.
    -   Extracts 2048-dim feature vectors (embeddings) from cropped dog images.
    -   **Robust Matching**: Voting (Top-3) + Margin Check (5%) for similar dogs.
    -   Implements Cosine Similarity matching against registered `Dog` entities.
4.  **DeepSORT Tracker** (NEW): Advanced object tracking system.
    -   **KalmanFilter**: Predicts position using constant velocity model.
    -   **Track**: Manages individual object state with Temporal Voting (10-frame window).
    -   **DeepSortTracker**: Matches detections using IoU + ReID cost, manages track lifecycle.
5.  **Data Models**:
    -   `DetectedObject`: Includes `trackId`, `dogId`, `dogName`, `embedding`.
    -   `Dog`: Extended with `embedding` (primary) and `referenceEmbeddingsList` (history).

### DeepSORT Features
-   **Kalman Filter**: Smooth bounding box tracking + motion prediction
-   **Temporal Voting**: 10-frame majority vote for identity confirmation
-   **ReID Optimization**: 99% reduction after identity confirmation
-   **Coasting**: Maintains track for 5 frames during brief occlusions

## 🔄 Deviations & Refinements

| Planned | Implemented | Rationale |
| :--- | :--- | :--- |
| Direct use of `DetectedObject` in UI | Created `DogUIState` struct | Decouples internal vision model types from SwiftUI views, ensuring thread safety and cleaner UI code. |
| Basic ReID logic | **DeepSORT + Temporal Voting** | Reduces ID switching during occlusions, crossings, and handles similar-looking dogs. |
| Threshold 0.7 | Threshold 0.4 (with Margin Check) | Lowered threshold + 5% margin check improves matching while preventing false positives. |
| Simple Integration | Two-Phase Pipeline | Phase 1 (IoU) → Phase 2 (selective ReID) → Phase 3 (finalize) for 99% ReID skip. |
| - | **Korean Logging** | All DeepSORT/Track logs in Korean with detailed vote tracking. |
| - | `DetectionOverlay` | Dedicated SwiftUI view for visualizing bounding boxes, track IDs, and names. |

## 📊 Performance Improvements

### ReID Execution Reduction
- **Before**: Every frame, every detection → 1800 ReID calls/min (30fps, 1 dog)
- **After**: First 10 frames only → 10 ReID calls total, then 0 calls
- **Result**: **99.4% ReID reduction** after confirmation

### Tracking Stability
- **ID Persistence**: Maintains identity across brief occlusions (up to 5 frames)
- **Smooth Motion**: Kalman Filter reduces bounding box jitter
- **False Positive Reduction**: Temporal Voting prevents single-frame misidentifications

## 📝 Notes
-   **Concurrency**: All UI updates on main thread via `DispatchQueue.main.async`.
-   **Debuggability**: Korean logs with vote distribution, match results, and ReID execution stats.
-   **Thread Safety**: Synchronized frame buffer and detection processing with proper queue management.
-   **Scalability**: Handles multiple dogs efficiently with greedy matching algorithm.
