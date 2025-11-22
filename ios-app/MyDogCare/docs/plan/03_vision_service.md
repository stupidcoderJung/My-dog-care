# 🎬 Task 3: VisionService Orchestration

## 🎯 Objective
Create `VisionService` (ObservableObject) that connects `CameraManager`, `YOLOClient`, and `ReIDTracker` to drive the UI.

## 📋 Detailed Steps
1.  **Create File**: `ios-app/MyDogCare/Services/Vision/VisionService.swift`.
2.  **Dependencies**: Inject `YOLOClient` and `ReIDTracker`.
3.  **Loop**:
    *   Consume frames from `CameraManager`.
    *   Run `yolo.predict()`.
    *   For each detection:
        *   Crop image.
        *   Run `reid.extractEmbedding()`.
        *   Run `reid.identify()`.
    *   Update `@Published var detectedDogs: [DogState]`.

## 🤖 AI Execution Prompt
(Copy this to the AI Agent)

```text
@ios-app/MyDogCare/Services/Vision/

I need you to execute **Task 3: VisionService Orchestration**.

**Instructions**:
1.  Create `ios-app/MyDogCare/Services/Vision/VisionService.swift`.
2.  Define `struct DogState`:
    ```swift
    struct DogState: Identifiable {
        let id: UUID // Dog's UUID
        let name: String
        let bounds: CGRect
        let action: String // "Standing", "Sitting" (Placeholder for now)
        let confidence: Float
    }
    ```
3.  Implement `class VisionService: ObservableObject`:
    *   `@Published var currentFrame: CGImage?`
    *   `@Published var detectedDogs: [DogState] = []`
    *   `func startProcessing()`: Start camera and analysis loop.
    *   **Pipeline**:
        *   Get frame -> YOLO -> [DetectedObject].
        *   For each object:
            *   Crop frame to `boundingBox`.
            *   Get Embedding.
            *   Match with CoreData `Dog` entities.
            *   Create `DogState`.

**Deliverable**:
*   `VisionService.swift` connecting all pieces.
```
