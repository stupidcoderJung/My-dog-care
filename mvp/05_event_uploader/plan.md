# Step 05: Event Uploader - 백엔드 전송

## 목표
생성된 `DeviceStatePacket`을 로컬에 버퍼링하고, 주기적으로 백엔드로 배치 전송합니다.

**Output**: 백엔드 `POST /events/batch` 성공 → 데이터 저장 완료

---

## 📋 체크리스트

### 5.1. EventUploader 구현
- [ ] **EventUploader.swift 생성**
  - 위치: `ios-app/MyDogCare/Services/Network/EventUploader.swift`
  - 역할: Packet 버퍼링 + 배치 업로드 + 재시도 로직

### 5.2. 로컬 버퍼링 (UserDefaults 또는 FileManager)
- [ ] **로컬 저장 구현**
  - 네트워크 오류 시 로컬 디스크에 임시 저장
  - 복구 시 자동 업로드

### 5.3. 백엔드 API 엔드포인트 (Mock 또는 실제)
- [ ] **백엔드 준비 확인**
  - `POST /events/batch` 엔드포인트
  - Request Body: `[DeviceStatePacket]`
  - Response: `{ "inserted": 10 }`

---

## 🔧 구현 가이드

### EventUploader 구현

```swift
import Foundation
import Combine

@MainActor
class EventUploader: ObservableObject {
    private let baseURL: URL
    private var packetBuffer: [DeviceStatePacket] = []
    private let maxBufferSize = 10  // 10초마다 전송
    private var uploadTimer: Timer?
    
    @Published var isUploading = false
    @Published var lastUploadTime: Date?
    @Published var uploadError: String?
    
    init(baseURL: String = "http://YOUR_BACKEND_URL") {
        self.baseURL = URL(string: baseURL)!
        
        // 10초마다 자동 업로드
        self.uploadTimer = Timer.scheduledTimer(
            withTimeInterval: 10.0,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.uploadBufferedPackets()
            }
        }
    }
    
    deinit {
        uploadTimer?.invalidate()
    }
    
    // Packet 추가
    func addPacket(_ packet: DeviceStatePacket) {
        packetBuffer.append(packet)
        
        // 버퍼 크기 초과 시 즉시 업로드
        if packetBuffer.count >= maxBufferSize {
            Task {
                await uploadBufferedPackets()
            }
        }
    }
    
    // 배치 업로드
    func uploadBufferedPackets() async {
        guard !packetBuffer.isEmpty else { return }
        guard !isUploading else { return }
        
        isUploading = true
        defer { isUploading = false }
        
        let packetsToUpload = packetBuffer
        print("📤 Uploading \(packetsToUpload.count) packets...")
        
        do {
            try await uploadToBackend(packets: packetsToUpload)
            
            // 업로드 성공 → 버퍼 클리어
            packetBuffer.removeAll()
            lastUploadTime = Date()
            uploadError = nil
            print("✅ Upload successful")
            
        } catch {
            print("❌ Upload failed: \(error)")
            uploadError = error.localizedDescription
            
            // 실패 시 로컬에 저장
            saveToLocalStorage(packets: packetsToUpload)
        }
    }
    
    // 백엔드 API 호출
    private func uploadToBackend(packets: [DeviceStatePacket]) async throws {
        let endpoint = baseURL.appendingPathComponent("/events/batch")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JSON 인코딩
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(packets)
        
        // API 호출
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "EventUploader",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorBody)"]
            )
        }
        
        // 성공 응답 파싱 (옵션)
        if let jsonResponse = try? JSONDecoder().decode([String: Int].self, from: data) {
            print("Server inserted: \(jsonResponse["inserted"] ?? 0) records")
        }
    }
    
    // 로컬 저장 (네트워크 오류 시)
    private func saveToLocalStorage(packets: [DeviceStatePacket]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(packets) else { return }
        
        let filename = "pending_packets_\(Date().timeIntervalSince1970).json"
        let fileURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
        print("💾 Saved \(packets.count) packets to local storage: \(fileURL)")
    }
    
    // 로컬 저장된 Packet 복구 및 재업로드
    func retryPendingUploads() async {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }
        
        let pendingFiles = files.filter { $0.lastPathComponent.hasPrefix("pending_packets_") }
        
        for fileURL in pendingFiles {
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let packets = try? decoder.decode([DeviceStatePacket].self, from: data) else {
                continue
            }
            
            do {
                try await uploadToBackend(packets: packets)
                // 성공 시 파일 삭제
                try? FileManager.default.removeItem(at: fileURL)
                print("✅ Retry successful: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Retry failed: \(fileURL.lastPathComponent)")
            }
        }
    }
}
```

### OnAirView에서 사용

```swift
@StateObject private var eventUploader = EventUploader(baseURL: "http://localhost:8000")

// 1초마다 실행되는 타이머에서
func onSecondTick() {
    // ... VisionService로 DogState 생성
    
    // StatePacket 생성
    let packet = visionService.generateStatePacket(
        dogStates: dogStates,
        sessionId: currentSessionId
    )
    
    // EventUploader에 추가
    eventUploader.addPacket(packet)
}

// 앱 시작 시 pending 업로드 재시도
.onAppear {
    Task {
        await eventUploader.retryPendingUploads()
    }
}
```

---

## 📚 참고 문서

### 백엔드 API
- [Event Ingestion API](../../docs/project_roadmap_new.md#2-3-api-implementation)
- Request Body: `[DeviceStatePacket]`
- Endpoint: `POST /events/batch`

### 로드맵
- [Event Upload](../../docs/project_roadmap_new.md#0-a-vlm-기반-실시간-분석-및-state-packet-생성)
- [Phase 0: Complete DeviceStatePacket](../../docs/project_roadmap_new.md#phase-0-bootstrap-vlm-provides-all-functionality)

### 관련 코드
- `ios-app/MyDogCare/Services/Network/EventUploader.swift` (생성 필요)
- `ios-app/MyDogCare/Views/OnAirView.swift` (업데이트 필요)

---

## ✅ 완료 조건

### 단위 테스트
- [ ] EventUploader.addPacket() → 버퍼에 추가됨
- [ ] 버퍼 10개 도달 시 자동 업로드 트리거
- [ ] uploadBufferedPackets() 성공 시 버퍼 클리어

### 통합 테스트 (Mock Backend)
- [ ] Mock 서버 설정:
  ```bash
  # Python Flask Mock Server
  from flask import Flask, request
  app = Flask(__name__)
  
  @app.route('/events/batch', methods=['POST'])
  def events_batch():
      data = request.json
      print(f"Received {len(data)} packets")
      return {"inserted": len(data)}
  
  app.run(port=8000)
  ```

- [ ] iOS에서 Packet 전송 → Mock 서버 로그 확인
- [ ] 네트워크 끊김 시뮬레이션 → 로컬 저장 확인
- [ ] 네트워크 복구 → 재업로드 성공 확인

### 실제 백엔드 연동 (Phase 2 이후)
- [ ] 백엔드 `POST /events/batch` 구현 완료 후 URL 변경
- [ ] TimescaleDB에 데이터 저장 확인

### 다음 단계로 넘어가기 전 확인
- [ ] Packet이 백엔드(또는 Mock)로 정상 전송됨
- [ ] 오류 시 로컬 저장 및 재시도 로직 작동
- **→ Step 06으로 진행**
