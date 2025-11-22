# MyDogCare AI Models 🧪

This directory contains training scripts, datasets, and conversion pipelines for the AI models used in MyDogCare.

## 🎯 Models

### 1. Object Detection (YOLO)
*   **Goal**: Detect dogs in real-time.
*   **Base Model**: YOLOv11-s or YOLOv12-s.
*   **Format**: CoreML (`.mlmodel`).

### 2. Re-Identification (ReID)
*   **Goal**: Identify specific dogs based on appearance.
*   **Architecture**: ResNet50 or OSNet (Lightweight).
*   **Output**: 128d or 256d embedding vector.

## 🔄 Workflow
1.  **Train/Fine-tune**: Use PyTorch/Ultralytics.
2.  **Export**: Convert to CoreML using `coremltools`.
3.  **Deploy**: Move `.mlmodel` to `../ios-app/MyDogCare/Resources/Models/`.
