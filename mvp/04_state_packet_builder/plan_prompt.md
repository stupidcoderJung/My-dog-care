# AI Assistant Prompt: State Packet Builder

## Task Overview
Create PairBuilder and StatePacketBuilder to generate complete DeviceStatePacket from DogState array.

## Context
- **Prerequisites**: Step 03 completed (DogState array available)
- **Goal**: Build PairState (dog relationships) and combine with DogState into DeviceStatePacket

## Your Task

### 1. Create Supporting Models
**File**: `ios-app/MyDogCare/Models/PairState.swift`
```swift
import Foundation

struct PairState: Codable {
    let dogIId: UUID
    let dogJId: UUID  // Always dogIId < dogJId
    let distanceNorm: Float
    var relativeAngle: Float?
    var affinityScore: Float?  // nil for now
    var tensionScore: Float?   // nil for now
    var interactionTags: [String]
}
```

**File**: `ios-app/MyDogCare/Models/EnvironmentState.swift`
```swift
import Foundation

struct EnvironmentState: Codable {
    var lux: Float?
    var decibel: Float?
    var crowding: Int?
}
```

**File**: `ios-app/MyDogCare/Models/DeviceStatePacket.swift`
```swift
import Foundation

struct DeviceStatePacket: Codable {
    let timestamp: Date
    let deviceId: String
    let sessionId: String
    var fps: Float?
    let dogs: [DogState]
    var relations: [PairState]?
    var environment: EnvironmentState?
}
```

### 2. Create PairBuilder
**File**: `ios-app/MyDogCare/Services/Vision/PairBuilder.swift`

```swift
import Foundation

class PairBuilder {
    private let maxDistanceNorm: Float = 0.7  // Skip pairs too far apart
    
    func buildPairs(from dogStates: [DogState]) -> [PairState] {
        var pairs: [PairState] = []
        
        for i in 0..<dogStates.count {
            for j in (i+1)..<dogStates.count {
                let dogI = dogStates[i]
                let dogJ = dogStates[j]
                
                guard let idI = dogI.dogId, let idJ = dogJ.dogId else {
                    continue
                }
                
                // Sort UUIDs (smaller first)
                let (smallerId, largerId) = idI < idJ ? (idI, idJ) : (idJ, idI)
                
                // Calculate distance
                let distanceNorm = calculateDistance(dogI.bboxNorm, dogJ.bboxNorm)
                
                if distanceNorm > maxDistanceNorm {
                    continue
                }
                
                let relativeAngle = calculateRelativeAngle(dogI.bboxNorm, dogJ.bboxNorm)
                
                let pairState = PairState(
                    dogIId: smallerId,
                    dogJId: largerId,
                    distanceNorm: distanceNorm,
                    relativeAngle: relativeAngle,
                    affinityScore: nil,
                    tensionScore: nil,
                    interactionTags: []
                )
                
                pairs.append(pairState)
            }
        }
        
        return pairs
    }
    
    private func calculateDistance(_ bbox1: BBoxNorm, _ bbox2: BBoxNorm) -> Float {
        let dx = bbox1.cx - bbox2.cx
        let dy = bbox1.cy - bbox2.cy
        return sqrt(dx * dx + dy * dy)
    }
    
    private func calculateRelativeAngle(_ bbox1: BBoxNorm, _ bbox2: BBoxNorm) -> Float {
        let dx = bbox2.cx - bbox1.cx
        let dy = bbox2.cy - bbox1.cy
        return atan2(dy, dx)
    }
}
```

### 3. Create StatePacketBuilder
**File**: `ios-app/MyDogCare/Services/Vision/StatePacketBuilder.swift`

```swift
import Foundation
import UIKit

class StatePacketBuilder {
    private let pairBuilder = PairBuilder()
    private let deviceId: String
    
    init(deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString) {
        self.deviceId = deviceId
    }
    
    func buildPacket(
        dogStates: [DogState],
        sessionId: String,
        fps: Float? = nil
    ) -> DeviceStatePacket {
        let pairs = pairBuilder.buildPairs(from: dogStates)
        
        let environment = EnvironmentState(
            lux: nil,
            decibel: nil,
            crowding: dogStates.count
        )
        
        return DeviceStatePacket(
            timestamp: Date(),
            deviceId: deviceId,
            sessionId: sessionId,
            fps: fps,
            dogs: dogStates,
            relations: pairs.isEmpty ? nil : pairs,
            environment: environment
        )
    }
}
```

### 4. Add to VisionService
**File**: `ios-app/MyDogCare/Services/Vision/VisionService.swift`

```swift
class VisionService: ObservableObject {
    // ... existing code ...
    private let statePacketBuilder: StatePacketBuilder
    
    @Published var currentPacket: DeviceStatePacket?
    
    init(deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString) {
        // ... existing init ...
        self.statePacketBuilder = StatePacketBuilder(deviceId: deviceId)
    }
    
    func generateStatePacket(
        dogStates: [DogState],
        sessionId: String
    ) -> DeviceStatePacket {
        let packet = statePacketBuilder.buildPacket(
            dogStates: dogStates,
            sessionId: sessionId
        )
        
        self.currentPacket = packet
        return packet
    }
}
```

## Acceptance Criteria

1. **PairBuilder** creates pairs correctly:
   - 2 dogs → 1 pair
   - 3 dogs → 3 pairs
   - Always dogIId < dogJId
2. **StatePacketBuilder** creates complete DeviceStatePacket
3. **JSON encoding** works correctly
4. **Test**: Print JSON packet

## Testing
```swift
let dogStates = // ... from Step 03
let sessionId = UUID().uuidString

let packet = visionService.generateStatePacket(
    dogStates: dogStates,
    sessionId: sessionId
)

// Test JSON encoding
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = .prettyPrinted

if let jsonData = try? encoder.encode(packet),
   let jsonString = String(data: jsonData, encoding: .utf8) {
    print("DeviceStatePacket JSON:")
    print(jsonString)
}
```

Expected output:
```json
{
  "timestamp": "2025-11-22T14:30:00Z",
  "deviceId": "...",
  "sessionId": "...",
  "dogs": [...],
  "relations": [...],
  "environment": {"crowding": 2}
}
```

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Models/PairState.swift` (create)
- ✏️ `ios-app/MyDogCare/Models/EnvironmentState.swift` (create)
- ✏️ `ios-app/MyDogCare/Models/DeviceStatePacket.swift` (create)
- ✏️ `ios-app/MyDogCare/Services/Vision/PairBuilder.swift` (create)
- ✏️ `ios-app/MyDogCare/Services/Vision/StatePacketBuilder.swift` (create)
- ✏️ `ios-app/MyDogCare/Services/Vision/VisionService.swift` (add generateStatePacket)

## References
- See `mvp/04_state_packet_builder/plan.md` for full details
