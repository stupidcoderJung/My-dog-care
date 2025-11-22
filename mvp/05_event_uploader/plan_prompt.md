# AI Assistant Prompt: Event Uploader

## Task Overview
Create EventUploader to buffer DeviceStatePackets and batch upload to backend with retry logic and local persistence for network failures.

## Context
- **Prerequisites**: Step 04 completed (DeviceStatePacket generation)
- **Backend Endpoint**: `POST /events/batch` (accepts `[DeviceStatePacket]`)
- **Features**: Buffering, batch upload every 10s, local storage on failure, retry on recovery

## Your Task

### Create EventUploader
**File**: `ios-app/MyDogCare/Services/Network/EventUploader.swift`

```swift
import Foundation
import Combine

@MainActor
class EventUploader: ObservableObject {
    private let baseURL: URL
    private var packetBuffer: [DeviceStatePacket] = []
    private let maxBufferSize = 10
    private var uploadTimer: Timer?
    
    @Published var isUploading = false
    @Published var lastUploadTime: Date?
    @Published var uploadError: String?
    
    init(baseURL: String = "http://YOUR_BACKEND_URL") {
        self.baseURL = URL(string: baseURL)!
        
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
    
    func addPacket(_ packet: DeviceStatePacket) {
        packetBuffer.append(packet)
        
        if packetBuffer.count >= maxBufferSize {
            Task {
                await uploadBufferedPackets()
            }
        }
    }
    
    func uploadBufferedPackets() async {
        guard !packetBuffer.isEmpty else { return }
        guard !isUploading else { return }
        
        isUploading = true
        defer { isUploading = false }
        
        let packetsToUpload = packetBuffer
        print("📤 Uploading \(packetsToUpload.count) packets...")
        
        do {
            try await uploadToBackend(packets: packetsToUpload)
            
            packetBuffer.removeAll()
            lastUploadTime = Date()
            uploadError = nil
            print("✅ Upload successful")
            
        } catch {
            print("❌ Upload failed: \(error)")
            uploadError = error.localizedDescription
            saveToLocalStorage(packets: packetsToUpload)
        }
    }
    
    private func uploadToBackend(packets: [DeviceStatePacket]) async throws {
        let endpoint = baseURL.appendingPathComponent("/events/batch")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(packets)
        
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
        
        if let jsonResponse = try? JSONDecoder().decode([String: Int].self, from: data) {
            print("Server inserted: \(jsonResponse["inserted"] ?? 0) records")
        }
    }
    
    private func saveToLocalStorage(packets: [DeviceStatePacket]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(packets) else { return }
        
        let filename = "pending_packets_\(Date().timeIntervalSince1970).json"
        let fileURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
        print("💾 Saved \(packets.count) packets to: \(fileURL)")
    }
    
    func retryPendingUploads() async {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }
        
        let pendingFiles = files.filter { 
            $0.lastPathComponent.hasPrefix("pending_packets_") 
        }
        
        for fileURL in pendingFiles {
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let packets = try? decoder.decode([DeviceStatePacket].self, from: data) else {
                continue
            }
            
            do {
                try await uploadToBackend(packets: packets)
                try? FileManager.default.removeItem(at: fileURL)
                print("✅ Retry successful: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Retry failed: \(fileURL.lastPathComponent)")
            }
        }
    }
}
```

## Acceptance Criteria

1. **EventUploader.addPacket()** buffers packets
2. **Auto-upload** triggers every 10 seconds or when buffer reaches 10 packets
3. **Local storage** saves packets when network fails
4. **Retry logic** re-uploads pending packets on app start or recovery
5. **Test**: Works with mock backend

## Testing

### Mock Backend (Python Flask)
```python
from flask import Flask, request
app = Flask(__name__)

@app.route('/events/batch', methods=['POST'])
def events_batch():
    data = request.json
    print(f"Received {len(data)} packets")
    return {"inserted": len(data)}

app.run(port=8000)
```

### iOS Test
```swift
let uploader = EventUploader(baseURL: "http://localhost:8000")

// Add packets
for i in 0..<5 {
    uploader.addPacket(testPacket)
}

// Wait for upload
try await Task.sleep(nanoseconds: 11_000_000_000)  // 11 seconds

// Check
print("Last upload: \(uploader.lastUploadTime)")
print("Error: \(uploader.uploadError ?? "none")")

// Test retry
await uploader.retryPendingUploads()
```

### Network Failure Simulation
1. Turn off WiFi
2. Add packets → Should save to local storage
3. Turn on WiFi
4. Run `retryPendingUploads()` → Should upload

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Services/Network/EventUploader.swift` (create)

## References
- See `mvp/05_event_uploader/plan.md` for full details
- Backend API will be at `POST /events/batch` (Phase 2)
