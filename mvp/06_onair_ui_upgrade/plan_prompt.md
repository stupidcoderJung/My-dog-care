# AI Assistant Prompt: On-Air UI Upgrade

## Task Overview
Integrate entire pipeline into OnAirView and create OverlayView to display real-time dog names, actions, and emotions on camera feed.

## Context
- **Prerequisites**: Steps 01-05 completed
- **Pipeline**: Camera → YOLO → ReID → VLM → DogState → StatePacket → Upload
- **UI Goal**: Show bounding boxes + dog names + actions + emotions in real-time

## Your Task

### 1. Create OverlayView
**File**: `ios-app/MyDogCare/Views/OnAir/OverlayView.swift`

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
        let scaledBbox = detection.bbox  // Already in screen coordinates
        
        ZStack(alignment: .topLeading) {
            // Bbox Rectangle
            Rectangle()
                .stroke(detection.dogId != nil ? Color.green : Color.red, lineWidth: 3)
                .frame(width: scaledBbox.width, height: scaledBbox.height)
                .position(x: scaledBbox.midX, y: scaledBbox.midY)
            
            // Labels
            VStack(alignment: .leading, spacing: 2) {
                // Dog name
                Text(detection.dogName ?? "Unknown")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(detection.dogId != nil ? Color.green : Color.red)
                    .cornerRadius(4)
                
                // VLM action
                if let analysis = vlmAnalysis {
                    Text(analysis.action.capitalized)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(4)
                    
                    // Emotion icon
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

### 2. Update OnAirView
**File**: `ios-app/MyDogCare/Views/OnAirView.swift`

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
    
    private let analyzeInterval = 1.0
    @State private var lastAnalyzeTime = Date()
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // Bounding box overlay
            OverlayView(detections: currentDetections,
                       vlmResponse: currentVLMResponse)
            
            // Status UI
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
            
            Task {
                await eventUploader.retryPendingUploads()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private func setupFrameProcessing() {
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
            await runYOLOReID(pixelBuffer)
            
            if Date().timeIntervalSince(lastAnalyzeTime) >= analyzeInterval {
                await runVLMAndUpload()
                lastAnalyzeTime = Date()
            }
        }
    }
    
    @MainActor
    private func runYOLOReID(_ pixelBuffer: CVPixelBuffer) async {
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
            // 1. VLM analysis
            let vlmResponse = try await visionService.analyzeWithVLM(
                frameHistory: frameHistory,
                detections: currentDetections,
                knownDogs: knownDogs
            )
            currentVLMResponse = vlmResponse
            
            // 2. Create DogState
            let dogStates = visionService.createDogStates(
                vlmResponse: vlmResponse,
                detections: currentDetections,
                frameSize: CGSize(width: 1920, height: 1080)
            )
            
            // 3. Generate StatePacket
            let packet = visionService.generateStatePacket(
                dogStates: dogStates,
                sessionId: sessionId
            )
            
            // 4. Upload
            eventUploader.addPacket(packet)
            
            print("✅ Packet generated and buffered")
            
        } catch {
            print("VLM+Upload Error: \(error)")
        }
    }
    
    private func fetchKnownDogs() -> [Dog] {
        // TODO: Fetch from Core Data
        return []
    }
}
```

## Acceptance Criteria

1. **On Air screen** shows live camera feed
2. **Bounding boxes** appear over detected dogs
3. **Dog names** displayed above each box (green for known, red for unknown)
4. **Actions** from VLM displayed ("Playing", "Resting", etc.)
5. **Emotion icons** displayed (😊, 😰, etc.)
6. **Every 1 second**: VLM analysis + StatePacket generation
7. **Every 10 seconds**: Batch upload to backend
8. **Performance**: UI remains responsive during analysis

## Testing

### Manual Test
1. Run app and go to On Air screen
2. Point camera at dog(s)
3. Verify:
   - ✓ Bounding boxes appear
   - ✓ Dog names show up
   - ✓ After 1-2 seconds, action appears ("Playing")
   - ✓ Emotion icon appears (😊)
4. Check console:
   ```
   📹 Frame captured
   🔍 YOLO detected: 1 dogs
   ✅ ReID identified: Buddy
   🧠 VLM analyzing...
   📊 VLM: Buddy is playing, relaxed
   📦 StatePacket generated
   📤 Uploading 1 packets...
   ✅ Upload successful
   ```

### Performance Test
- FPS should stay ~30fps
- No UI freezing during VLM calls
- Memory usage stable (frame history limited to 10)

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Views/OnAir/OverlayView.swift` (create)
- ✏️ `ios-app/MyDogCare/Views/OnAirView.swift` (major update)

## References
- See `mvp/06_onair_ui_upgrade/plan.md` for full details
- CameraManager at `Services/CameraManager.swift`
- Existing OnAirView at `Views/OnAirView.swift`

---

## 🎉 MVP Stage 1 Complete!

After this step, users will have:
- ✅ Real-time dog detection with names
- ✅ Live behavior and emotion analysis
- ✅ All data flowing to backend
- ✅ Ready for Chat queries!
