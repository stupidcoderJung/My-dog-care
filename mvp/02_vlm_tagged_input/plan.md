# Step 02: VLM에 태깅된 이미지 전달

## 목표
YOLO+ReID 결과를 받아 강아지 이름이 시각적으로 표시된 이미지를 생성하고, 이를 VLM에 전달하여 행동 분석을 받습니다.

**Output**: `VisionResponse` - VLM이 분석한 각 강아지의 posture, action, emotion

---

## 📋 체크리스트

### 2.1. 이미지 태깅 유틸리티 구현
- [ ] **ImageTagger.swift 생성**
  - 위치: `ios-app/MyDogCare/Services/Vision/ImageTagger.swift`
  - 역할: DetectedObject 정보를 이미지에 오버레이
  
  ```swift
  class ImageTagger {
      func tagImage(_ image: UIImage, 
                    detections: [DetectedObject]) -> UIImage {
          // 1. 이미지 위에 bbox 그리기
          // 2. 각 bbox 위에 강아지 이름 텍스트 그리기
          // 3. 태깅된 새 이미지 반환
      }
  }
  ```

### 2.2. VisionClient analyzeStream 메서드 확장
- [ ] **VisionClient.swift 확인**
  - 파일: `ios-app/MyDogCare/Services/ModelRegistry.swift`
  - 현재 상태: `analyzeStream(images: [UIImage], dogs: [Dog])` 메서드 존재
  - 확장 필요: 태깅된 이미지를 받을 수 있도록 수정 (또는 그대로 사용)

### 2.3. VLM 프롬프트 업데이트
- [ ] **analyzeStream 프롬프트 수정**
  - 현재: 일반적인 강아지 분석 요청
  - 수정: 이미지에 표시된 강아지 이름을 참조하도록 안내
  
  ```swift
  let finalUserPrompt = """
  Analyze the attached sequence of images.
  
  **IMPORTANT**: Each detected dog has its NAME labeled above the bounding box.
  Please use these EXACT NAMES in your response.
  
  Context: Known dogs are: \(dogNamesString).
  
  For each dog visible in the images:
  1. Use the NAME shown on the image
  2. Analyze posture, action, emotion, health_signals
  
  Output Format: (기존과 동일한 JSON 스키마)
  ```

### 2.4. VisionService에 VLM 호출 통합
- [ ] **VisionService.swift 확장**
  - Step 01에서 생성한 VisionService에 VLM 호출 추가
  
  ```swift
  class VisionService: ObservableObject {
      private let visionClient: VisionClient
      private let imageTagger: ImageTagger
      
      func analyzeWithVLM(_ pixelBuffer: CVPixelBuffer,
                         detections: [DetectedObject],
                         knownDogs: [Dog],
                         frameHistory: [UIImage]) async throws -> VisionResponse {
          // 1. 최신 5프레임 선택
          let recentFrames = Array(frameHistory.suffix(5))
          
          // 2. 각 프레임에 detection 정보 태깅
          let taggedFrames = recentFrames.map { frame in
              imageTagger.tagImage(frame, detections: detections)
          }
          
          // 3. VLM 호출
          let (response, _) = try await visionClient.analyzeStream(
              images: taggedFrames,
              dogs: knownDogs
          )
          
          return response
      }
  }
  ```

---

## 🔧 구현 가이드

### ImageTagger 구현 예시

```swift
import UIKit
import CoreGraphics

class ImageTagger {
    func tagImage(_ image: UIImage, 
                  detections: [DetectedObject]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let taggedImage = renderer.image { context in
            // 원본 이미지 그리기
            image.draw(at: .zero)
            
            let cgContext = context.cgContext
            
            for detection in detections {
                // 1. BBox 그리기
                cgContext.setStrokeColor(UIColor.green.cgColor)
                cgContext.setLineWidth(3.0)
                cgContext.stroke(detection.bbox)
                
                // 2. 강아지 이름 텍스트 그리기
                if let dogName = detection.dogName {
                    let text = "\(dogName) (\(Int(detection.confidence * 100))%)"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.green.withAlphaComponent(0.7)
                    ]
                    
                    let textPoint = CGPoint(
                        x: detection.bbox.minX,
                        y: detection.bbox.minY - 30
                    )
                    
                    (text as NSString).draw(at: textPoint, 
                                           withAttributes: attributes)
                } else {
                    // 등록되지 않은 강아지
                    let text = "Unknown Dog"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.red.withAlphaComponent(0.7)
                    ]
                    
                    let textPoint = CGPoint(
                        x: detection.bbox.minX,
                        y: detection.bbox.minY - 30
                    )
                    
                    (text as NSString).draw(at: textPoint,
                                           withAttributes: attributes)
                }
            }
        }
        
        return taggedImage
    }
}
```

### OnAirView에서 프레임 히스토리 관리

```swift
@State private var frameHistory: [UIImage] = []
private let maxFrameHistory = 10

func captureFrame(_ pixelBuffer: CVPixelBuffer) {
    // CVPixelBuffer → UIImage 변환
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
        let uiImage = UIImage(cgImage: cgImage)
        
        // 히스토리에 추가
        frameHistory.append(uiImage)
        if frameHistory.count > maxFrameHistory {
            frameHistory.removeFirst()
        }
    }
}
```

---

## 📚 참고 문서

### 기존 구현
- [VisionClient (ModelRegistry.swift)](../../ios-app/MyDogCare/Services/ModelRegistry.swift)
  - 라인 100-292: `analyzeStream()` 메서드
  - 현재 로직: 멀티턴 대화 → VLM 호출

### 관련 문서
- [Phase 0: Bootstrap](../../docs/project_roadmap_new.md#phase-0-bootstrap)
- [VLM Enhanced Pipeline](../../docs/project_roadmap_new.md#핵심-의존성-및-전략)

### 관련 코드
- `ios-app/MyDogCare/Services/ModelRegistry.swift` - VisionClient
- `ios-app/MyDogCare/Services/Vision/ImageTagger.swift` (생성 필요)
- `ios-app/MyDogCare/Services/Vision/VisionService.swift` (Step 01에서 생성)

---

## ✅ 완료 조건

### 단위 테스트
- [ ] ImageTagger.tagImage() 호출 시 강아지 이름이 표시된 이미지 반환
- [ ] VisionService.analyzeWithVLM() 호출 시 VisionResponse 반환
- [ ] VLM이 이미지의 라벨을 참조하여 응답 생성 (name 필드 일치)

### 통합 테스트
- [ ] OnAirView에서 5프레임마다 VLM 호출
- [ ] 태깅된 이미지가 VLM에 정상 전달
- [ ] VisionResponse에 각 강아지의 posture, action, emotion 포함

### 디버깅
- [ ] 태깅된 이미지를 로컬에 저장하여 확인:
  ```swift
  if let data = taggedImage.pngData() {
      let url = FileManager.default.temporaryDirectory
                 .appendingPathComponent("tagged_\(Date().timeIntervalSince1970).png")
      try? data.write(to: url)
      print("Tagged image saved: \(url)")
  }
  ```

### 다음 단계로 넘어가기 전 확인
- [ ] VLM이 태깅된 이미지를 받아 분석 수행
- [ ] VisionResponse.dogs[].name이 DetectedObject.dogName과 일치
- **→ Step 03으로 진행**
