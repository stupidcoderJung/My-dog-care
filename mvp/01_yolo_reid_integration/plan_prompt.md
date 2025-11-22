# AI Assistant Prompt: YOLO + ReID Integration

## Task Overview
Implement a VisionService that integrates YOLO object detection and ReID identification to detect and identify dogs in camera frames.

## Context
- **Project**: MyDogCare iOS app (Swift/SwiftUI)
- **Existing Code**:
  - `Services/Vision/YOLOClient.swift` - YOLO detection (already implemented)
  - `Services/Vision/ReIDTracker.swift` - ReID identification (already implemented)
  - `Services/Vision/VisionService.swift` - Orchestrator (exists, needs update)
  - `Models/DetectedObject.swift` - Detection model (needs review/update)
  - `Models/Dog.swift` - Dog entity (needs referenceEmbeddings field)

## Your Task

### 1. Review and Update DetectedObject Model
**File**: `ios-app/MyDogCare/Models/DetectedObject.swift`

Ensure the struct has these fields:
```swift
struct DetectedObject {
    var bbox: CGRect
    var confidence: Float
    var classId: Int
    var trackId: Int?
    var embedding: [Float]?
    var dogId: UUID?        // NEW: ReID matching result
    var dogName: String?    // NEW: Dog name for UI
}
```

### 2. Verify Dog Model Has referenceEmbeddings
**File**: `ios-app/MyDogCare/Models/Dog.swift` or Core Data model

Add if missing:
```swift
var referenceEmbeddings: [[Float]]  // 3-5 reference embeddings, each 512d or 128d
```

### 3. Implement VisionService Integration
**File**: `ios-app/MyDogCare/Services/Vision/VisionService.swift`

Create or update to include:
```swift
@MainActor
class VisionService: ObservableObject {
    private let yoloClient: YOLOClient
    private let reidTracker: ReIDTracker
    
    @Published var lastDetections: [DetectedObject] = []
    
    init() {
        self.yoloClient = YOLOClient()
        self.reidTracker = ReIDTracker()
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, 
                     knownDogs: [Dog]) async throws -> [DetectedObject] {
        // Step 1: YOLO Detection
        let detections = try await yoloClient.predict(pixelBuffer: pixelBuffer)
        
        // Step 2: ReID Identification
        let identifiedDetections = detections.compactMap { detection -> DetectedObject? in
            var identified = detection
            
            if let embedding = detection.embedding {
                let dogId = reidTracker.identify(
                    embedding: embedding,
                    knownDogs: knownDogs,
                    threshold: 0.7
                )
                
                identified.dogId = dogId
                
                if let dogId = dogId,
                   let dog = knownDogs.first(where: { $0.id == dogId }) {
                    identified.dogName = dog.name
                }
            }
            
            return identified
        }
        
        self.lastDetections = identifiedDetections
        return identifiedDetections
    }
}
```

## Acceptance Criteria

1. **DetectedObject** has `dogId` and `dogName` fields
2. **Dog** model has `referenceEmbeddings: [[Float]]` field
3. **VisionService.processFrame()** returns `[DetectedObject]` with:
   - Identified dogs have `dogId` and `dogName` set
   - Unidentified dogs have `dogId = nil`
4. **Test**: Call `processFrame()` and verify console output shows detected dogs with names

## Testing
Run this code in OnAirView or a test:
```swift
let visionService = VisionService()
let knownDogs = // fetch from Core Data
let detections = try await visionService.processFrame(pixelBuffer, knownDogs: knownDogs)

print("Detected \(detections.count) dogs:")
for detection in detections {
    print("  - \(detection.dogName ?? "Unknown") (confidence: \(detection.confidence))")
}
```

Expected output:
```
Detected 2 dogs:
  - Buddy (confidence: 0.95)
  - Unknown (confidence: 0.87)
```

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Models/DetectedObject.swift` (update)
- ✏️ `ios-app/MyDogCare/Models/Dog.swift` (add referenceEmbeddings)
- ✏️ `ios-app/MyDogCare/Services/Vision/VisionService.swift` (implement)

## References
- See `mvp/01_yolo_reid_integration/plan.md` for full details
- Existing implementations: YOLOClient.swift, ReIDTracker.swift
