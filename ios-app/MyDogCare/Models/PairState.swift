import Foundation

struct PairState: Codable {
    let dogIId: UUID
    let dogJId: UUID  // Always dogIId < dogJId
    let distanceNorm: Float
    var relativeAngle: Float?
    var affinityScore: Float?  // nil for now
    var tensionScore: Float?   // nil for now
    var interactionTags: [String]
}
