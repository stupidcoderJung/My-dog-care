# Step 03: VLM → DogState 매핑

## 목표
VLM의 `VisionResponse`를 받아 `DogState` 구조체로 변환합니다. 특히 `action` → `behaviorProbs`, `emotion` → `stressProxy` 매핑이 핵심입니다.

**Output**: `[DogState]` - VLM 기반 behavior/stress 정보가 포함된 강아지 상태 배열

---

## 📋 체크리스트

### 3.1. DogState 모델 정의/확인
- [ ] **DogState.swift 생성/확인**
  - 위치: `ios-app/MyDogCare/Models/DogState.swift`
  - 필수 필드:
    ```swift
    struct DogState: Codable {
        let timestamp: Date
        let dogId: UUID?
        let tempTrackId: Int
        
        // YOLO + ReID
        let bboxNorm: BBoxNorm    // Normalized bbox
        var speedPx: Float?
        var directionRad: Float?
        
        // VLM → 매핑
        var behaviorProbs: [String: Float]  // VLM action → behavior
        var stressProxy: Float?             // VLM emotion → stress
    }
    
    struct BBoxNorm: Codable {
        let cx: Float   // center x (0~1)
        let cy: Float   // center y (0~1)
        let w: Float    // width (0~1)
        let h: Float    // height (0~1)
    }
    ```

### 3.2. VLMStateMapper 구현
- [ ] **VLMStateMapper.swift 생성**
  - 위치: `ios-app/MyDogCare/Services/Vision/VLMStateMapper.swift`
  - 역할: VisionResponse → DogState 변환
  
  ```swift
  class VLMStateMapper {
      func mapToDogStates(
          vlmResponse: VisionResponse,
          detections: [DetectedObject],
          frameSize: CGSize
      ) -> [DogState] {
          // VLM의 dogs 배열을 순회하며 DogState 생성
      }
  }
  ```

### 3.3. Action → BehaviorProbs 매핑 규칙 정의
- [ ] **행동 매핑 딕셔너리 작성**
  ```swift
  private let actionToBehaviorMap: [String: [String: Float]] = [
      // VLM action → behaviorProbs 딕셔너리
      "playing": [
          "play": 1.0,
          "rest": 0.0,
          "chase": 0.2,
          "avoid": 0.0,
          "freeze": 0.0,
          "face_off": 0.0
      ],
      "sleeping": [
          "play": 0.0,
          "rest": 1.0,
          "chase": 0.0,
          "avoid": 0.0,
          "freeze": 0.0,
          "face_off": 0.0
      ],
      "eating": [
          "play": 0.0,
          "rest": 0.3,
          "chase": 0.0,
          "avoid": 0.0,
          "freeze": 0.0,
          "face_off": 0.0
      ],
      "walking": [
          "play": 0.1,
          "rest": 0.0,
          "chase": 0.3,
          "avoid": 0.0,
          "freeze": 0.0,
          "face_off": 0.0
      ],
      "idle": [
          "play": 0.0,
          "rest": 0.5,
          "chase": 0.0,
          "avoid": 0.0,
          "freeze": 0.0,
          "face_off": 0.0
      ],
      "grooming": [
          "play": 0.0,
          "rest": 0.4,
          "chase": 0.0,
          "avoid": 0.0,
          "freeze": 0.0,
          "face_off": 0.0
      ]
      // 필요한 action 추가
  ]
  ```

### 3.4. Emotion → StressProxy 매핑 규칙 정의
- [ ] **감정 → 스트레스 매핑 함수 작성**
  ```swift
  private func emotionToStress(_ emotion: String) -> Float {
      switch emotion.lowercased() {
      case "relaxed": return 0.1
      case "tail_wagging": return 0.2
      case "ears_flat": return 0.6
      case "panting": return 0.5
      case "whale_eye": return 0.7
      case "anxious": return 0.8
      default: return 0.5  // neutral
      }
  }
  ```

---

## 🔧 구현 가이드

### VLMStateMapper 전체 구현

```swift
import Foundation
import CoreGraphics

class VLMStateMapper {
    // Action → BehaviorProbs 매핑
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
            // 1. VLM 응답과 Detection 매칭 (이름 기준)
            guard let detection = detections.first(where: { 
                $0.dogName == dogAnalysis.name 
            }) else {
                print("Warning: No detection found for VLM dog: \(dogAnalysis.name)")
                continue
            }
            
            // 2. BBox 정규화
            let bboxNorm = BBoxNorm(
                cx: Float(detection.bbox.midX / frameSize.width),
                cy: Float(detection.bbox.midY / frameSize.height),
                w: Float(detection.bbox.width / frameSize.width),
                h: Float(detection.bbox.height / frameSize.height)
            )
            
            // 3. Action → BehaviorProbs 변환
            let behaviorProbs = actionToBehaviorMap[dogAnalysis.action.lowercased()] 
                ?? ["play": 0.0, "rest": 0.5, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0]
            
            // 4. Emotion → StressProxy 변환
            let stressProxy = emotionToStress(dogAnalysis.emotion)
            
            // 5. DogState 생성
            let dogState = DogState(
                timestamp: timestamp,
                dogId: detection.dogId,
                tempTrackId: detection.trackId ?? index,
                bboxNorm: bboxNorm,
                speedPx: nil,  // TODO: 이전 프레임과 비교하여 계산
                directionRad: nil,  // TODO: 이전 프레임과 비교하여 계산
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

### VisionService에 매핑 추가

```swift
class VisionService: ObservableObject {
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

---

## 📚 참고 문서

### 데이터 모델
- [DogState 정의](../../docs/project_roadmap_new.md#1-1-기본-데이터-모델-정의)
- [VisionResponse 구조](../../ios-app/MyDogCare/Services/ModelRegistry.swift) - 라인 12-30

### 매핑 전략
- [VLM → DogState 매핑 예시](../../docs/project_roadmap_new.md#vlm--dogstate-매핑-예시)
- [Phase 0: Bootstrap](../../docs/project_roadmap_new.md#phase-0-bootstrap-vlm-provides-all-functionality)

### 관련 코드
- `ios-app/MyDogCare/Models/DogState.swift` (생성 필요)
- `ios-app/MyDogCare/Services/Vision/VLMStateMapper.swift` (생성 필요)
- `ios-app/MyDogCare/Services/Vision/VisionService.swift` (Step 01에서 생성)

---

## ✅ 완료 조건

### 단위 테스트
- [ ] VLMStateMapper.mapToDogStates() 호출 시 DogState 배열 반환
- [ ] Action "playing" → behaviorProbs["play"] == 1.0
- [ ] Emotion "relaxed" → stressProxy == 0.1
- [ ] Emotion "anxious" → stressProxy == 0.8

### 통합 테스트
- [ ] VLM 응답 → DogState 변환 성공
- [ ] 각 DogState의 behaviorProbs 딕셔너리가 올바른 값 포함
- [ ] 각 DogState의 stressProxy가 0~1 범위

### 로그 확인
- [ ] Console에 변환 결과 출력:
  ```
  DogState: Buddy
    - action: playing → behaviorProbs: {"play": 1.0, "rest": 0.0}
    - emotion: relaxed → stressProxy: 0.1
  ```

### 다음 단계로 넘어가기 전 확인
- [ ] VLM 응답이 DogState로 정확히 변환됨
- [ ] behaviorProbs와 stressProxy 필드가 올바른 값 포함
- **→ Step 04로 진행**
