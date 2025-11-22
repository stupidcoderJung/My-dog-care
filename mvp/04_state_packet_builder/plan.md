# Step 04: State Packet 생성

## 목표
`[DogState]`를 받아 `PairState`, `EnvironmentState`를 계산하고, 최종적으로 완전한 `DeviceStatePacket`을 생성합니다.

**Output**: `DeviceStatePacket` - 백엔드에 전송할 완전한 상태 패킷

---

## 📋 체크리스트

### 4.1. 모델 정의
- [ ] **PairState.swift 생성**
  - 위치: `ios-app/MyDogCare/Models/PairState.swift`
  ```swift
  struct PairState: Codable {
      let dogIId: UUID
      let dogJId: UUID  // 항상 dog

IId < dogJId
      let distanceNorm: Float  // 정규화된 거리 (0~1)
      var relativeAngle: Float?
      var affinityScore: Float?  // 초기엔 nil 가능
      var tensionScore: Float?   // 초기엔 nil 가능
      var interactionTags: [String]
  }
  ```

- [ ] **EnvironmentState.swift 생성**
  - 위치: `ios-app/MyDogCare/Models/EnvironmentState.swift`
  ```swift
  struct EnvironmentState: Codable {
      var lux: Float?
      var decibel: Float?
      var crowding: Int?  // 화면 내 강아지 개수
  }
  ```

- [ ] **DeviceStatePacket.swift 생성**
  - 위치: `ios-app/MyDogCare/Models/DeviceStatePacket.swift`
  ```swift
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

### 4.2. PairBuilder 구현
- [ ] **PairBuilder.swift 생성**
  - 위치: `ios-app/MyDogCare/Services/Vision/PairBuilder.swift`
  - 역할: DogState 배열 → PairState 배열
  
  ```swift
  class PairBuilder {
      func buildPairs(from dogStates: [DogState]) -> [PairState] {
          // N개 강아지 → (i, j) 조합 생성 (i < j)
          // distanceNorm 계산
          // (옵션) 너무 먼 쌍 스킵
      }
  }
  ```

### 4.3. StatePacketBuilder 구현
- [ ] **StatePacketBuilder.swift 생성**
  - 위치: `ios-app/MyDogCare/Services/Vision/StatePacketBuilder.swift`
  - 역할: 모든 요소를 조합하여 DeviceStatePacket 생성

---

## 🔧 구현 가이드

### PairBuilder 구현

```swift
import Foundation

class PairBuilder {
    // 너무 먼 쌍은 스킵 (옵션)
    private let maxDistanceNorm: Float = 0.7
    
    func buildPairs(from dogStates: [DogState]) -> [PairState] {
        var pairs: [PairState] = []
        
        // N개 강아지 중 2개 선택 (조합)
        for i in 0..<dogStates.count {
            for j in (i+1)..<dogStates.count {
                let dogI = dogStates[i]
                let dogJ = dogStates[j]
                
                // 두 강아지 모두 식별된 경우만 처리
                guard let idI = dogI.dogId, let idJ = dogJ.dogId else {
                    continue
                }
                
                // UUID 정렬 (항상 작은 값이 먼저)
                let (smallerId, largerId) = idI < idJ ? (idI, idJ) : (idJ, idI)
                
                // 거리 계산
                let distanceNorm = calculateDistance(dogI.bboxNorm, dogJ.bboxNorm)
                
                // 너무 먼 쌍은 스킵 (옵션)
                if distanceNorm > maxDistanceNorm {
                    continue
                }
                
                // Relative Angle 계산 (옵션)
                let relativeAngle = calculateRelativeAngle(dogI.bboxNorm, dogJ.bboxNorm)
                
                // PairState 생성
                let pairState = PairState(
                    dogIId: smallerId,
                    dogJId: largerId,
                    distanceNorm: distanceNorm,
                    relativeAngle: relativeAngle,
                    affinityScore: nil,  // Phase 6에서 모델로 계산
                    tensionScore: nil,   // Phase 6에서 모델로 계산
                    interactionTags: []  // Phase 6에서 모델로 계산
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

### StatePacketBuilder 구현

```swift
import Foundation
import UIKit

class StatePacketBuilder {
    private let pairBuilder = PairBuilder()
    
    // Device ID는 앱 첫 실행 시 생성하여 저장
    private let deviceId: String
    
    init(deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString) {
        self.deviceId = deviceId
    }
    
    func buildPacket(
        dogStates: [DogState],
        sessionId: String,
        fps: Float? = nil
    ) -> DeviceStatePacket {
        // 1. PairState 생성
        let pairs = pairBuilder.buildPairs(from: dogStates)
        
        // 2. EnvironmentState 생성
        let environment = EnvironmentState(
            lux: nil,  // TODO: AVCaptureDevice로 측정 or 추정
            decibel: nil,  // TODO: AVAudioRecorder로 측정
            crowding: dogStates.count  // 간단히 감지된 강아지 수로 설정
        )
        
        // 3. DeviceStatePacket 생성
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

### VisionService에 통합

```swift
class VisionService: ObservableObject {
    private let statePacketBuilder: StatePacketBuilder
    
    @Published var currentPacket: DeviceStatePacket?
    
    init(deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString) {
        self.statePacketBuilder = StatePacketBuilder(deviceId: deviceId)
        // ... 기존 초기화
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

---

## 📚 참고 문서

### 데이터 모델
- [PairState 정의](../../docs/project_roadmap_new.md#1-1-기본-데이터-모델-정의)
- [DeviceStatePacket 정의](../../docs/project_roadmap_new.md#1-1-기본-데이터-모델-정의)

### 관련 로드맵
- [State Packet Generation](../../docs/project_roadmap_new.md#phase-0-bootstrap-vlm-provides-all-functionality)
- [Phase 0 데이터 흐름](../../docs/project_roadmap_new.md#phase-0의-역할-중요)

### 관련 코드
- `ios-app/MyDogCare/Models/PairState.swift` (생성 필요)
- `ios-app/MyDogCare/Models/EnvironmentState.swift` (생성 필요)
- `ios-app/MyDogCare/Models/DeviceStatePacket.swift` (생성 필요)
- `ios-app/MyDogCare/Services/Vision/PairBuilder.swift` (생성 필요)
- `ios-app/MyDogCare/Services/Vision/StatePacketBuilder.swift` (생성 필요)

---

## ✅ 완료 조건

### 단위 테스트
- [ ] PairBuilder.buildPairs() 호출 시 PairState 배열 반환
- [ ] 2마리 강아지 → 1개 PairState
- [ ] 3마리 강아지 → 3개 PairState (조합 C(3,2))
- [ ] dogIId < dogJId 규칙 준수

- [ ] StatePacketBuilder.buildPacket() 호출 시 DeviceStatePacket 반환
- [ ] dogs 배열 포함
- [ ] relations 배열 포함 (강아지 2마리 이상일 때)
- [ ] environment crowding == 강아지 수

### 통합 테스트
- [ ] VisionService에서 완전한 DeviceStatePacket 생성
- [ ] Packet JSON 인코딩 성공:
  ```swift
  let encoder = JSONEncoder()
  encoder.dateEncodingStrategy = .iso8601
  let jsonData = try encoder.encode(packet)
  let jsonString = String(data: jsonData, encoding: .utf8)
  print(jsonString)
  ```

### JSON 샘플 확인
```json
{
  "timestamp": "2025-11-22T14:30:00Z",
  "deviceId": "iPhone-UUID",
  "sessionId": "session-UUID",
  "fps": 30.0,
  "dogs": [
    {
      "dogId": "buddy-uuid",
      "bboxNorm": {"cx": 0.5, "cy": 0.5, "w": 0.2, "h": 0.3},
      "behaviorProbs": {"play": 1.0, "rest": 0.0},
      "stressProxy": 0.1
    }
  ],
  "relations": [
    {
      "dogIId": "buddy-uuid",
      "dogJId": "max-uuid",
      "distanceNorm": 0.3,
      "interactionTags": []
    }
  ],
  "environment": {
    "crowding": 2
  }
}
```

### 다음 단계로 넘어가기 전 확인
- [ ] DeviceStatePacket이 완전한 형태로 생성됨
- [ ] JSON 인코딩 가능
- **→ Step 05로 진행**
