import Foundation
import CoreGraphics

class VLMStateMapper {
    // Action → BehaviorProbs Mapping
    private let actionToBehaviorMap: [String: [String: Float]] = [
        "playing": ["play": 1.0, "rest": 0.0, "chase": 0.2, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "sleeping": ["play": 0.0, "rest": 1.0, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "eating": ["play": 0.0, "rest": 0.3, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "drinking": ["play": 0.0, "rest": 0.3, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "walking": ["play": 0.1, "rest": 0.0, "chase": 0.3, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "idle": ["play": 0.0, "rest": 0.5, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "grooming": ["play": 0.0, "rest": 0.4, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "standing": ["play": 0.1, "rest": 0.2, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "sitting": ["play": 0.0, "rest": 0.6, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0],
        "lying": ["play": 0.0, "rest": 0.9, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0]
    ]
    
    func mapToDogStates(
        vlmResponse: VisionResponse,
        detections: [DetectedObject],
        frameSize: CGSize,
        timestamp: Date = Date()
    ) -> [DogState] {
        var dogStates: [DogState] = []
        
        for (index, dogAnalysis) in vlmResponse.dogs.enumerated() {
            // 1. Match VLM response with Detection (by Name)
            // Note: VLM uses names provided in the prompt (from detections).
            // If name is "Unknown", we might have multiple.
            // Ideally, we should pass trackId to VLM, but VLM is text-based.
            // For now, we match by name. If duplicates, this might be ambiguous,
            // but in MVP1 we assume distinct names or best effort.
            
            guard let detection = detections.first(where: { 
                $0.dogName == dogAnalysis.name || ($0.dogName == nil && dogAnalysis.name == "Unknown")
            }) else {
                print("Warning: No detection found for VLM dog: \(dogAnalysis.name)")
                continue
            }
            
            // 2. Normalize BBox
            let bboxNorm = BBoxNorm(
                cx: Float(detection.bbox.midX / frameSize.width),
                cy: Float(detection.bbox.midY / frameSize.height),
                w: Float(detection.bbox.width / frameSize.width),
                h: Float(detection.bbox.height / frameSize.height)
            )
            
            // 3. Action → BehaviorProbs
            // Use lowercased action for matching, default to idle if not found
            let actionKey = dogAnalysis.action.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            // Try exact match, then contains match (e.g. "lying down" -> "lying")
            var behaviorProbs = actionToBehaviorMap[actionKey]
            
            if behaviorProbs == nil {
                // Fallback: check if any key is contained in the action string
                for (key, value) in actionToBehaviorMap {
                    if actionKey.contains(key) {
                        behaviorProbs = value
                        break
                    }
                }
            }
            
            // Default if still nil
            let finalBehaviorProbs = behaviorProbs ?? ["play": 0.0, "rest": 0.5, "chase": 0.0, "avoid": 0.0, "freeze": 0.0, "face_off": 0.0]
            
            // 4. Emotion → StressProxy
            let stressProxy = emotionToStress(dogAnalysis.emotion)
            
            // 5. Create DogState
            let dogState = DogState(
                timestamp: timestamp,
                dogId: detection.dogId,
                tempTrackId: detection.trackId ?? index, // Fallback to index if no trackId
                bboxNorm: bboxNorm,
                speedPx: nil,  // TODO: Calculate from previous frame
                directionRad: nil,  // TODO: Calculate from previous frame
                behaviorProbs: finalBehaviorProbs,
                stressProxy: stressProxy,
                vlmAction: dogAnalysis.action,
                vlmEmotion: dogAnalysis.emotion
            )
            
            dogStates.append(dogState)
        }
        
        return dogStates
    }
    
    private func emotionToStress(_ emotion: String) -> Float {
        switch emotion.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "relaxed", "happy", "playful", "calm": return 0.1
        case "tail_wagging", "excited": return 0.2
        case "alert", "attentive": return 0.3
        case "panting": return 0.5
        case "ears_flat", "submissive": return 0.6
        case "whale_eye", "scared", "fearful": return 0.7
        case "anxious", "nervous", "shaking": return 0.8
        case "aggressive", "growling": return 0.9
        default: return 0.5  // neutral / unknown
        }
    }
}
