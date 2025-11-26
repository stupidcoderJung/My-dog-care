import Foundation

class PairBuilder {
    private let maxDistanceNorm: Float = 0.7  // Skip pairs too far apart
    
    func buildPairs(from dogStates: [DogState]) -> [PairState] {
        var pairs: [PairState] = []
        
        for i in 0..<dogStates.count {
            for j in (i+1)..<dogStates.count {
                let dogI = dogStates[i]
                let dogJ = dogStates[j]
                
                // Ensure both dogs have IDs (either identified or temporary)
                // Using the UUID from Identifiable conformance if dogId is nil
                let idI = dogI.dogId ?? dogI.id
                let idJ = dogJ.dogId ?? dogJ.id
                
                // Sort UUIDs (smaller first) to ensure consistent pair ordering
                // UUID string comparison is sufficient for deterministic ordering
                let (smallerId, largerId) = idI.uuidString < idJ.uuidString ? (idI, idJ) : (idJ, idI)
                
                // Calculate distance
                let distanceNorm = calculateDistance(dogI.bboxNorm, dogJ.bboxNorm)
                
                if distanceNorm > maxDistanceNorm {
                    continue
                }
                
                let relativeAngle = calculateRelativeAngle(dogI.bboxNorm, dogJ.bboxNorm)
                
                let pairState = PairState(
                    dogIId: smallerId,
                    dogJId: largerId,
                    distanceNorm: distanceNorm,
                    relativeAngle: relativeAngle,
                    affinityScore: nil,
                    tensionScore: nil,
                    interactionTags: []
                )
                
                pairs.append(pairState)
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
