# Step 01: YOLO + ReID 통합

## 목표
카메라 프레임을 받아 YOLO로 강아지를 감지하고, ReID로 등록된 강아지를 식별하는 파이프라인 구축.

**Output**: `[DetectedObject with dogId]` - 강아지 이름이 태깅된 감지 결과

---

## 📋 체크리스트

### 1.1. YOLOClient와 ReIDTracker 확인
- [ ] **YOLOClient 코드 리뷰**
  - 파일: `ios-app/MyDogCare/Services/Vision/YOLOClient.swift`
  - 확인사항: `predict()` 메서드가 `[DetectedObject]` 반환하는지
  - 필요시 수정: embedding 필드가 제대로 추출되는지

- [ ] **ReIDTracker 코드 리뷰**
  - 파일: `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift`
  - 확인사항: `identify()` 메서드가 embedding을 받아 `UUID?` 반환하는지
  - 필요시 수정: Dog의 referenceEmbeddings와 비교 로직

### 1.2. VisionService 통합 레이어 구현
- [ ] **VisionService.swift 생성**
  - 위치: `ios-app/MyDogCare/Services/Vision/VisionService.swift`
  - 역할: YOLO와 ReID를 순차적으로 실행하는 오케스트레이터
  
  ```swift
  class VisionService: ObservableObject {
      private let yoloClient: YOLOClient
      private let reidTracker: ReIDTracker
      
      @Published var detectedDogs: [DetectedObject] = []
      
      func processFrame(_ pixelBuffer: CVPixelBuffer, 
                       knownDogs: [Dog]) -> [DetectedObject] {
          // 1. YOLO 감지
          let detections = yoloClient.predict(pixelBuffer: pixelBuffer)
          
          // 2. ReID 식별
          let identified = detections.map { detection in
              var mutableDetection = detection
              if let embedding = detection.embedding {
                  mutableDetection.dogId = reidTracker.identify(
                      embedding: embedding, 
                      knownDogs: knownDogs
                  )
              }
              return mutableDetection
          }
          
          return identified
      }
  }
  ```

### 1.3. DetectedObject 모델 확장
- [ ] **DetectedObject.swift 확인/수정**
  - 위치: `ios-app/MyDogCare/Models/DetectedObject.swift`
  - 필수 필드:
    ```swift
    struct DetectedObject {
        var bbox: CGRect
        var confidence: Float
        var classId: Int
        var trackId: Int?
        var embedding: [Float]?
        var dogId: UUID?        // ReID 매칭 결과
        var dogName: String?    // Dog 이름 (UI용)
    }
    ```

### 1.4. Dog 엔티티 referenceEmbeddings 확인
- [ ] **Dog 모델 확인**
  - 파일: `ios-app/MyDogCare/Models/Dog.swift` or Core Data
  - 필수 필드: `referenceEmbeddings: [[Float]]`
  - 없으면 추가 필요

---

## 🔧 구현 가이드

### VisionService 구현 예시

```swift
import Foundation
import CoreML
import Vision
import UIKit

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
            
            // ReID 임베딩이 있으면 식별 시도
            if let embedding = detection.embedding {
                let dogId = reidTracker.identify(
                    embedding: embedding,
                    knownDogs: knownDogs,
                    threshold: 0.7
                )
                
                identified.dogId = dogId
                
                // dogId가 있으면 이름도 설정
                if let dogId = dogId,
                   let dog = knownDogs.first(where: { $0.id == dogId }) {
                    identified.dogName = dog.name
                }
            }
            
            return identified
        }
        
        // 결과 저장
        self.lastDetections = identifiedDetections
        
        return identifiedDetections
    }
}
```

---

## 📚 참고 문서

### 기존 구현
- [YOLOClient 구현 가이드](../ios-app/MyDogCare/docs/plan/01_yolo_client.md)
- [ReIDTracker 구현 가이드](../ios-app/MyDogCare/docs/plan/02_reid_tracker.md)
- [VisionService 구현 가이드](../ios-app/MyDogCare/docs/plan/03_vision_service.md)

### 모델 및 데이터
- [DetectedObject 정의](../docs/project_roadmap_new.md#1-1-기본-데이터-모델-정의)
- [Dog 엔티티 확장](../docs/project_roadmap_new.md#1-2-dog-profile-엔티티-확장)

### 관련 코드
- `ios-app/MyDogCare/Services/Vision/YOLOClient.swift`
- `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift`
- `ios-app/MyDogCare/Services/Vision/VisionService.swift` (생성 필요)
- `ios-app/MyDogCare/Models/DetectedObject.swift`
- `ios-app/MyDogCare/Models/Dog.swift`

---

## ✅ 완료 조건

### 단위 테스트
- [ ] VisionService.processFrame() 호출 시 DetectedObject 배열 반환
- [ ] 등록된 강아지는 dogId와 dogName이 설정됨
- [ ] 등록되지 않은 강아지는 dogId가 nil

### 통합 테스트
- [ ] OnAirView에서 VisionService 호출
- [ ] 카메라 프레임이 들어올 때마다 감지 수행
- [ ] Console에 감지된 강아지 정보 로그 출력:
  ```
  Detected: [
    DetectedObject(dogId: UUID, dogName: "Buddy", confidence: 0.95),
    DetectedObject(dogId: nil, dogName: nil, confidence: 0.87)
  ]
  ```

### 다음 단계로 넘어가기 전 확인
- [ ] VisionService가 정상적으로 DetectedObject 배열 반환
- [ ] dogId와 dogName이 올바르게 태깅됨
- **→ Step 02로 진행**
