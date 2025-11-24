import Foundation

/// Normalized Bounding Box (0.0 ~ 1.0)
struct BBoxNorm: Codable {
    let cx: Float   // center x (0~1)
    let cy: Float   // center y (0~1)
    let w: Float    // width (0~1)
    let h: Float    // height (0~1)
}

/// Comprehensive Dog State for Data Logging (Backend Sync)
struct DogState: Codable, Identifiable {
    var id: UUID { dogId ?? UUID() } // For Identifiable conformance, though dogId is optional in logic
    
    let timestamp: Date
    let dogId: UUID?              // Set only if matched with reference
    let tempTrackId: Int
    
    // YOLO + ReID
    let bboxNorm: BBoxNorm        // Normalized bbox
    var speedPx: Float?           // px/s
    var directionRad: Float?      // Radians
    
    // VLM → Mapping
    var behaviorProbs: [String: Float]  // VLM action → behavior probabilities
    var stressProxy: Float?             // VLM emotion → stress level (0~1)
    
    // Raw VLM Data (Optional, for debugging or rich display)
    var vlmAction: String?
    var vlmEmotion: String?
}
