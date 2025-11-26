import Foundation
import Combine

@MainActor
class EventUploader: ObservableObject {
    private let baseURL: URL
    private var packetBuffer: [DeviceStatePacket] = []
    private let maxBufferSize = 10  // Upload every 10 packets (approx 10 seconds)
    private var uploadTimer: Timer?
    
    @Published var isUploading = false
    @Published var lastUploadTime: Date?
    @Published var uploadError: String?
    
    // Default to localhost for testing, can be overridden
//    init(baseURL: String = "http://localhost:8000") {
    init(baseURL: String = "http://192.168.0.77:8000") {
        self.baseURL = URL(string: baseURL)!
        
        // Auto-upload every 10 seconds as a fallback if buffer doesn't fill
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
    
    // Add packet to buffer
    func addPacket(_ packet: DeviceStatePacket) {
        packetBuffer.append(packet)
        
        // Trigger upload if buffer is full
        if packetBuffer.count >= maxBufferSize {
            Task {
                await uploadBufferedPackets()
            }
        }
    }
    
    // Batch upload
    func uploadBufferedPackets() async {
        guard !packetBuffer.isEmpty else { return }
        guard !isUploading else { return }
        
        isUploading = true
        defer { isUploading = false }
        
        let packetsToUpload = packetBuffer
        print("📤 EventUploader: Uploading \(packetsToUpload.count) packets...")
        
        do {
            try await uploadToBackend(packets: packetsToUpload)
            
            // Success: Clear buffer
            packetBuffer.removeAll()
            lastUploadTime = Date()
            uploadError = nil
            print("✅ EventUploader: Upload successful")
            
        } catch {
            print("❌ EventUploader: Upload failed: \(error)")
            uploadError = error.localizedDescription
            
            // Failure: Save to local storage for retry
            saveToLocalStorage(packets: packetsToUpload)
            
            // Clear buffer to prevent blocking new packets (they are saved to disk)
            packetBuffer.removeAll()
        }
    }
    
    // Backend API Call
    private func uploadToBackend(packets: [DeviceStatePacket]) async throws {
        let endpoint = baseURL.appendingPathComponent("/events/batch")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JSON Encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(packets)
        
        // API Call
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
        
        // Parse success response (optional)
        if let jsonResponse = try? JSONDecoder().decode([String: Int].self, from: data) {
            print("   Server inserted: \(jsonResponse["inserted"] ?? 0) records")
        }
    }
    
    // Local Storage (for offline/failure)
    private func saveToLocalStorage(packets: [DeviceStatePacket]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(packets) else { return }
        
        let filename = "pending_packets_\(Date().timeIntervalSince1970).json"
        let fileURL = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(filename)
        
        try? data.write(to: fileURL)
        print("💾 EventUploader: Saved \(packets.count) packets to local storage: \(fileURL.lastPathComponent)")
    }
    
    // Retry Pending Uploads
    func retryPendingUploads() async {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ) else { return }
        
        let pendingFiles = files.filter { $0.lastPathComponent.hasPrefix("pending_packets_") }
        
        if !pendingFiles.isEmpty {
            print("🔄 EventUploader: Found \(pendingFiles.count) pending files to retry")
        }
        
        for fileURL in pendingFiles {
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let packets = try? decoder.decode([DeviceStatePacket].self, from: data) else {
                // Corrupt file? Delete it
                try? FileManager.default.removeItem(at: fileURL)
                continue
            }
            
            do {
                try await uploadToBackend(packets: packets)
                // Success: Delete file
                try? FileManager.default.removeItem(at: fileURL)
                print("✅ EventUploader: Retry successful for \(fileURL.lastPathComponent)")
            } catch {
                print("❌ EventUploader: Retry failed for \(fileURL.lastPathComponent): \(error)")
                // Keep file for next retry
            }
        }
    }
}
