import Foundation

struct DeviceStatePacket: Codable {
    let timestamp: Date
    let deviceId: String
    let sessionId: String
    var fps: Float?
    let dogs: [DogState]
    var relations: [PairState]?
    var environment: EnvironmentState?
}
