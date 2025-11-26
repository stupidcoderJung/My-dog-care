import Foundation

// MARK: - Mocks for Models
// Copying minimal definitions to make the script standalone

struct BBoxNorm: Codable {
    let cx: Float, cy: Float, w: Float, h: Float
}

struct DogState: Codable, Identifiable {
    var id: UUID { dogId ?? UUID() }
    let timestamp: Date
    let dogId: UUID?
    let tempTrackId: Int
    let bboxNorm: BBoxNorm
    var speedPx: Float?
    var directionRad: Float?
    var behaviorProbs: [String: Float]
    var stressProxy: Float?
    var vlmAction: String?
    var vlmEmotion: String?
}

struct PairState: Codable {
    let dogIId: UUID
    let dogJId: UUID
    let distanceNorm: Float
    var relativeAngle: Float?
    var affinityScore: Float?
    var tensionScore: Float?
    var interactionTags: [String]
}

struct EnvironmentState: Codable {
    var lux: Float?
    var decibel: Float?
    var crowding: Int?
}

struct DeviceStatePacket: Codable {
    let timestamp: Date
    let deviceId: String
    let sessionId: String
    var fps: Float?
    let dogs: [DogState]
    var relations: [PairState]?
    var environment: EnvironmentState?
}

// MARK: - Builder Logic (Copied from implementation)

class PairBuilder {
    private let maxDistanceNorm: Float = 0.7
    
    func buildPairs(from dogStates: [DogState]) -> [PairState] {
        var pairs: [PairState] = []
        for i in 0..<dogStates.count {
            for j in (i+1)..<dogStates.count {
                let dogI = dogStates[i]
                let dogJ = dogStates[j]
                let idI = dogI.dogId ?? dogI.id
                let idJ = dogJ.dogId ?? dogJ.id
                let (smallerId, largerId) = idI.uuidString < idJ.uuidString ? (idI, idJ) : (idJ, idI)
                
                let distanceNorm = calculateDistance(dogI.bboxNorm, dogJ.bboxNorm)
                if distanceNorm > maxDistanceNorm { continue }
                
                let relativeAngle = calculateRelativeAngle(dogI.bboxNorm, dogJ.bboxNorm)
                pairs.append(PairState(
                    dogIId: smallerId,
                    dogJId: largerId,
                    distanceNorm: distanceNorm,
                    relativeAngle: relativeAngle,
                    affinityScore: nil,
                    tensionScore: nil,
                    interactionTags: []
                ))
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

class StatePacketBuilder {
    private let pairBuilder = PairBuilder()
    private let deviceId: String
    
    init(deviceId: String = "TEST_DEVICE_ID") {
        self.deviceId = deviceId
    }
    
    func buildPacket(dogStates: [DogState], sessionId: String, fps: Float? = nil) -> DeviceStatePacket {
        let pairs = pairBuilder.buildPairs(from: dogStates)
        let environment = EnvironmentState(lux: nil, decibel: nil, crowding: dogStates.count)
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

// MARK: - Verification Script

print("🚀 Starting State Packet Builder Verification...")

// 1. Setup Mock Data
let dog1Id = UUID()
let dog2Id = UUID()
let sessionId = UUID().uuidString

print("📋 Creating 2 Mock Dogs...")
print("   - Dog 1: \(dog1Id)")
print("   - Dog 2: \(dog2Id)")

let dog1 = DogState(
    timestamp: Date(),
    dogId: dog1Id,
    tempTrackId: 1,
    bboxNorm: BBoxNorm(cx: 0.2, cy: 0.2, w: 0.1, h: 0.1),
    speedPx: nil, directionRad: nil, behaviorProbs: [:], stressProxy: nil, vlmAction: nil, vlmEmotion: nil
)

let dog2 = DogState(
    timestamp: Date(),
    dogId: dog2Id,
    tempTrackId: 2,
    bboxNorm: BBoxNorm(cx: 0.3, cy: 0.3, w: 0.1, h: 0.1), // Close enough to pair
    speedPx: nil, directionRad: nil, behaviorProbs: [:], stressProxy: nil, vlmAction: nil, vlmEmotion: nil
)

// 2. Run Builder
print("\n⚙️  Running StatePacketBuilder...")
let builder = StatePacketBuilder()
let packet = builder.buildPacket(dogStates: [dog1, dog2], sessionId: sessionId, fps: 30.0)

// 3. Verify Output
print("\n✅ Packet Generated!")
print("   - Device ID: \(packet.deviceId)")
print("   - Session ID: \(packet.sessionId)")
print("   - Dog Count: \(packet.dogs.count)")
print("   - Relations Count: \(packet.relations?.count ?? 0)")

// 4. Print JSON
let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted
encoder.dateEncodingStrategy = .iso8601

if let data = try? encoder.encode(packet), let json = String(data: data, encoding: .utf8) {
    print("\n📜 JSON Output:")
    print(json)
} else {
    print("\n❌ JSON Encoding Failed")
}
