import Foundation
import UIKit

class StatePacketBuilder {
    private let pairBuilder = PairBuilder()
    private let deviceId: String
    
    init(deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString) {
        self.deviceId = deviceId
    }
    
    func buildPacket(
        dogStates: [DogState],
        sessionId: String,
        fps: Float? = nil
    ) -> DeviceStatePacket {
        let pairs = pairBuilder.buildPairs(from: dogStates)
        
        let environment = EnvironmentState(
            lux: nil,
            decibel: nil,
            crowding: dogStates.count
        )
        
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
