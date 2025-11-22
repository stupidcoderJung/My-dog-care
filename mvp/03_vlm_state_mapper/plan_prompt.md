# AI Assistant Prompt: VLM → DogState Mapping

## Task Overview
Create VLMStateMapper to convert VisionResponse (VLM output) into DogState structures with behaviorProbs and stressProxy fields.

## Context
- **Prerequisites**: Step 02 completed (VLM returns VisionResponse)
- **Key Mapping**:
  - VLM `action` → `behaviorProbs` dictionary
  - VLM `emotion` → `stressProxy` (0~1 float)

## Your Task

### 1. Create DogState and BBoxNorm Models
**File**: `ios-app/MyDogCare/Models/DogState.swift`

```swift
import Foundation

struct BBoxNorm: Codable {
    let cx: Float   // center x (0~1)
    let cy: Float   // center y (0~1)
    let w: Float    // width (0~1)
    let h: Float    // height (0~1)
}

struct DogState: Codable {
    let timestamp: Date
    let dogId: UUID?
    let tempTrackId: Int
    
    // YOLO + ReID
    let bboxNorm: BBoxNorm
    var speedPx: Float?
    var directionRad: Float?
    
    // VLM → Mapped
    var behaviorProbs: [String: Float]
    var stressProxy: Float?
}
```

### 2. Create VLMStateMapper
**File**: `ios-app/MyDogCare/Services/Vision/VLMStateMapper.swift`

```swift
import Foundation
import CoreGraphics

class VLMStateMapper {
    // Action → BehaviorProbs mapping
    private let actionToBehaviorMap: [String: [String: Float]] = [
        "playing": ["play": 1.0, "rest": 0.0, "chase": 0.2, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "sleeping": ["play": 0.0, "rest": 1.0, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "eating": ["play": 0.0, "rest": 0.3, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "walking": ["play": 0.1, "rest": 0.0, "chase": 0.3, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "idle": ["play": 0.0, "rest": 0.5, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "grooming": ["play": 0.0, "rest": 0.4, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0]
    ]
    
    func mapToDogStates(
        vlmResponse: VisionResponse,
        detections: [DetectedObject],
        frameSize: CGSize,
        timestamp: Date = Date()
    ) -> [DogState] {
        var dogStates: [DogState] = []
        
        for (index, dogAnalysis) in vlmResponse.dogs.enumerated() {
            // 1. Match VLM response with Detection (by name)
            guard let detection = detections.first(where: { 
                $0.dogName == dogAnalysis.name 
            }) else {
                print("Warning: No detection for VLM dog: \(dogAnalysis.name)")
                continue
            }
            
            // 2. Normalize bbox
            let bboxNorm = BBoxNorm(
                cx: Float(detection.bbox.midX / frameSize.width),
                cy: Float(detection.bbox.midY / frameSize.height),
                w: Float(detection.bbox.width / frameSize.width),
                h: Float(detection.bbox.height / frameSize.height)
            )
            
            // 3. Action → BehaviorProbs
            let behaviorProbs = actionToBehaviorMap[dogAnalysis.action.lowercased()] 
                ?? ["play": 0.0, "rest": 0.5, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0]
            
            // 4. Emotion → StressProxy
            let stressProxy = emotionToStress(dogAnalysis.emotion)
            
            // 5. Create DogState
            let dogState = DogState(
                timestamp: timestamp,
                dogId: detection.dogId,
                tempTrackId: detection.trackId ?? index,
                bboxNorm: bboxNorm,
                speedPx: nil,  // TODO: calculate from previous frame
                directionRad: nil,
                behaviorProbs: behaviorProbs,
                stressProxy: stressProxy
            )
            
            dogStates.append(dogState)
        }
        
        return dogStates
    }
    
    private func emotionToStress(_ emotion: String) -> Float {
        switch emotion.lowercased() {
        case "relaxed": return 0.1
        case "tail_wagging": return 0.2
        case "ears_flat": return 0.6
        case "panting": return 0.5
        case "whale_eye": return 0.7
        case "anxious": return 0.8
        default: return 0.5
        }
    }
}
```

### 3. Add to VisionService
**File**: `ios-app/MyDogCare/Services/Vision/VisionService.swift`

Add property and method:
```swift
class VisionService: ObservableObject {
    // ... existing code ...
    private let vlmStateMapper = VLMStateMapper()
    
    func createDogStates(
        vlmResponse: VisionResponse,
        detections: [DetectedObject],
        frameSize: CGSize
    ) -> [DogState] {
        return vlmStateMapper.mapToDogStates(
            vlmResponse: vlmResponse,
            detections: detections,
            frameSize: frameSize
        )
    }
}
```

## Acceptance Criteria

1. **DogState model** has all required fields
2. **VLMStateMapper.mapToDogStates()** returns `[DogState]`
3. **Action mapping** works correctly:
   - "playing" → behaviorProbs["play"] == 1.0
   - "sleeping" → behaviorProbs["rest"] == 1.0
4. **Emotion mapping** works correctly:
   - "relaxed" → stressProxy == 0.1
   - "anxious" → stressProxy == 0.8
5. **Test**: Console shows correct mapping

## Testing
```swift
let vlmResponse = // ... from Step 02
let detections = // ... from Step 01
let frameSize = CGSize(width: 1920, height: 1080)

let dogStates = visionService.createDogStates(
    vlmResponse: vlmResponse,
    detections: detections,
    frameSize: frameSize
)

for state in dogStates {
    print("DogState: \(state.dogId?.uuidString ?? "Unknown")")
    print("  behaviorProbs: \(state.behaviorProbs)")
    print("  stressProxy: \(state.stressProxy ?? 0.0)")
}
```

Expected output:
```
DogState: buddy-uuid
  behaviorProbs: ["play": 1.0, "rest": 0.0, ...]
  stressProxy: 0.1
```

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Models/DogState.swift` (create)
- ✏️ `ios-app/MyDogCare/Services/Vision/VLMStateMapper.swift` (create)
- ✏️ `ios-app/MyDogCare/Services/Vision/VisionService.swift` (add createDogStates)

## References
- See `mvp/03_vlm_state_mapper/plan.md` for full details
- VisionResponse structure in `Services/ModelRegistry.swift` lines 12-30
