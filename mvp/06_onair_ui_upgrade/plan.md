# Step 06: On-Air UI 업그레이드

## 목표
전체 파이프라인을 OnAirView에 통합하고, 사용자에게 실시간으로 강아지 이름, 행동, 감정을 보여주는 UI를 구현합니다.

**Output**: 완성된 On-Air 화면 - 바운딩 박스 + 강아지 이름 + 행동 + (옵션) 감정 아이콘

---

## 📋 체크리스트

### 6.1. OnAirView 전체 통합
- [ ] **전체 파이프라인 연결**
  - Camera → YOLO → ReID → VLM → DogState → StatePacket → Upload
  - 매 프레임마다 YOLO+ReID 실행
  - 5프레임마다 (또는 1초마다) VLM 호출
  - 1초마다 StatePacket 생성 및 버퍼링
  - 10초마다 배치 업로드

### 6.2. OverlayView 구현
- [ ] **바운딩 박스 오버레이**
  - 위치: `ios-app/MyDogCare/Views/OnAir/OverlayView.swift` (생성)
  - DetectedObject 배열을 받아 화면에 bbox 그리기
  - 각 강아지 이름, 행동, confidence 표시

### 6.3. UI 상태 관리
- [ ] **OnAirViewModel 생성** (옵션)
  - 위치: `ios-app/MyDogCare/ViewModels/OnAirViewModel.swift`
  - VisionService, EventUploader 관리
  - 상태: isAnalyzing, currentDetections, lastVLMResponse

---

## 🔧 구현 가이드

### OnAirView 전체 구조

```swift
import SwiftUI
import AVFoundation

struct OnAirView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var visionService = VisionService()
    @StateObject private var eventUploader = EventUploader(baseURL: "http://localhost:8000")
    
    @State private var currentDetections: [DetectedObject] = []
    @State private var currentVLMResponse: VisionResponse?
    @State private var frameHistory: [UIImage] = []
    @State private var sessionId = UUID().uuidString
    
    @State private var isAnalyzing = false
    @State private var frameCount = 0
    
    // Timer
    private let analyzeInterval = 1.0  // 1초마다 VLM+StatePacket 생성
    @State private var lastAnalyzeTime = Date()
    
    var body: some View {
        ZStack {
            // 카메라 프리뷰
            CameraPreviewView(session: cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // 바운딩 박스 오버레이
            OverlayView(detections: currentDetections,
                       vlmResponse: currentVLMResponse)
            
            // 상태 표시
            VStack {
                HStack {
                    Text("On Air")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red)
                        .cornerRadius(8)
                    
                    if isAnalyzing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Spacer()
                    
                    Text("Detected: \(currentDetections.count)")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
                .padding()
                
                Spacer()
            }
        }
        .onAppear {
            cameraManager.startSession()
            setupFrameProcessing()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func setupFrameProcessing() {
        // 카메라 프레임 캡처 콜백 설정
        cameraManager.onFrameCaptured = { pixelBuffer, image in
            processFrame(pixelBuffer, image: image)
        }
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer, image: UIImage) {
        frameCount += 1
        frameHistory.append(image)
        if frameHistory.count > 10 {
            frameHistory.removeFirst()
        }
        
        Task {
            // 매 프레임: YOLO + ReID
            await runYOLOReID(pixelBuffer)
            
            // 1초마다: VLM 분석 + StatePacket 생성
            if Date().timeIntervalSince(lastAnalyzeTime) >= analyzeInterval {
                await runVLMAndUpload()
                lastAnalyzeTime = Date()
            }
        }
    }
    
    @MainActor
    private func runYOLOReID(_ pixelBuffer: CVPixelBuffer) async {
        // 강아지 목록 가져오기 (Core Data 또는 메모리)
        let knownDogs = fetchKnownDogs()
        
        do {
            let detections = try await visionService.processFrame(
                pixelBuffer,
                knownDogs: knownDogs
            )
            currentDetections = detections
        } catch {
            print("YOLO+ReID Error: \(error)")
        }
    }
    
    @MainActor
    private func runVLMAndUpload() async {
        guard !currentDetections.isEmpty else { return }
        guard frameHistory.count >= 5 else { return }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let knownDogs = fetchKnownDogs()
        
        do {
            // 1. VLM 분석
            let vlmResponse = try await visionService.analyzeWithVLM(
                frameHistory: frameHistory,
                detections: currentDetections,
                knownDogs: knownDogs
            )
            currentVLMResponse = vlmResponse
            
            // 2. DogState 생성
            let dogStates = visionService.createDogStates(
                vlmResponse: vlmResponse,
                detections: currentDetections,
                frameSize: CGSize(width: 1920, height: 1080)  // TODO: 실제 프레임 크기
            )
            
            // 3. StatePacket 생성
            let packet = visionService.generateStatePacket(
                dogStates: dogStates,
                sessionId: sessionId
            )
            
            // 4. EventUploader에 추가
            eventUploader.addPacket(packet)
            
            print("✅ Packet generated and buffered")
            
        } catch {
            print("VLM+Upload Error: \(error)")
        }
    }
    
    private func fetchKnownDogs() -> [Dog] {
        // TODO: Core Data에서 Dog 목록 가져오기
        // 임시로 빈 배열 반환
        return []
    }
}
```

### OverlayView 구현

```swift
import SwiftUI

struct OverlayView: View {
    let detections: [DetectedObject]
    let vlmResponse: VisionResponse?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(detections.enumerated()), id: \.offset) { index, detection in
                    BoundingBoxView(
                        detection: detection,
                        vlmAnalysis: matchVLMAnalysis(for: detection),
                        frameSize: geometry.size
                    )
                }
            }
        }
    }
    
    private func matchVLMAnalysis(for detection: DetectedObject) -> DogAnalysis? {
        guard let vlmResponse = vlmResponse else { return nil }
        return vlmResponse.dogs.first { $0.name == detection.dogName }
    }
}

struct BoundingBoxView: View {
    let detection: DetectedObject
    let vlmAnalysis: DogAnalysis?
    let frameSize: CGSize
    
    var body: some View {
        let scaledBbox = scaleBBox(detection.bbox, to: frameSize)
        
        ZStack(alignment: .topLeading) {
            // BBox Rectangle
            Rectangle()
                .stroke(detection.dogId != nil ? Color.green : Color.red, lineWidth: 3)
                .frame(width: scaledBbox.width, height: scaledBbox.height)
                .position(x: scaledBbox.midX, y: scaledBbox.midY)
            
            // Label (Name + Action)
            VStack(alignment: .leading, spacing: 2) {
                // 강아지 이름
                Text(detection.dogName ?? "Unknown")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(detection.dogId != nil ? Color.green : Color.red)
                    .cornerRadius(4)
                
                // VLM 행동 (있으면)
                if let analysis = vlmAnalysis {
                    Text(analysis.action.capitalized)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(4)
                    
                    // 감정 (옵션)
                    Text(emotionIcon(analysis.emotion))
                        .font(.system(size: 20))
                        .padding(4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                }
            }
            .position(x: scaledBbox.minX + 50, y: scaledBbox.minY - 40)
        }
    }
    
    private func scaleBBox(_ bbox: CGRect, to frameSize: CGSize) -> CGRect {
        // YOLO bbox는 원본 이미지 좌표 → 화면 좌표로 변환
        return CGRect(
            x: bbox.origin.x,
            y: bbox.origin.y,
            width: bbox.width,
            height: bbox.height
        )
    }
    
    private func emotionIcon(_ emotion: String) -> String {
        switch emotion.lowercased() {
        case "relaxed": return "😊"
        case "tail_wagging": return "😄"
        case "ears_flat": return "😟"
        case "panting": return "😮"
        case "whale_eye": return "😰"
        case "anxious": return "😨"
        default: return "🐶"
        }
    }
}
```

---

## 📚 참고 문서

### UI 가이드
- [On Air UI Overhaul](../../docs/project_roadmap_new.md#3-1-on-air-ui)
- [Bounding Box Overlay](../../docs/project_roadmap_new.md#3-1-on-air-ui)

### 기존 코드
- [OnAirView.swift](../../ios-app/MyDogCare/Views/OnAirView.swift) - 현재 구현
- [CameraManager.swift](../../ios-app/MyDogCare/Services/CameraManager.swift)

### 관련 파일
- `ios-app/MyDogCare/Views/OnAirView.swift` (업데이트)
- `ios-app/MyDogCare/Views/OnAir/OverlayView.swift` (생성 필요)
- `ios-app/MyDogCare/ViewModels/OnAirViewModel.swift` (옵션)

---

## ✅ 완료 조건

### 기능 테스트
- [ ] On Air 화면 진입 시 카메라 시작
- [ ] 강아지 감지 시 바운딩 박스 실시간 표시
- [ ] 등록된 강아지: 초록색 박스 + 이름
- [ ] 등록되지 않은 강아지: 빨간색 박스 + "Unknown"
- [ ] VLM 분석 결과 표시: 행동 ("Playing", "Resting" 등)
- [ ] (옵션) 감정 아이콘 표시 (😊, 😰 등)

### 성능 테스트
- [ ] 실시간 감지 (30fps 유지)
- [ ] VLM 분석 중에도 UI 반응성 유지
- [ ] 메모리 사용량 모니터링 (프레임 히스토리 관리)

### 디버깅
- [ ] Console 로그:
  ```
  📹 Frame captured
  🔍 YOLO detected: 2 dogs
  ✅ ReID identified: Buddy
  🧠 VLM analyzing...
  📊 VLM response: Buddy is playing, relaxed
  📦 StatePacket generated
  📤 Uploaded to backend
  ```

### 최종 확인
- [ ] 전체 파이프라인 통합 완료
- [ ] 사용자가 On Air 화면에서 모든 정보 확인 가능
- [ ] 백엔드에 데이터 정상 전송

---

## 🎉 MVP Stage 1 완료!

**축하합니다!** 이제 사용자는:
1. ✅ On Air 화면에서 실시간으로 강아지 이름을 볼 수 있습니다
2. ✅ 각 강아지의 행동과 감정을 확인할 수 있습니다
3. ✅ 모든 데이터가 백엔드에 저장되어 Chat에서 질의할 준비가 되었습니다

**다음 단계:**
- Phase 2: Backend Infrastructure 구축
- Phase 3: LLM Agent 개발
- Chat 화면에서 "Buddy가 오늘 뭐했어?" 질문 가능!
