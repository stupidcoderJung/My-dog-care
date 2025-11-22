import Foundation
import CoreGraphics

struct DetectedObject: Identifiable {
    let id = UUID()
    var bbox: CGRect
    var confidence: Float
    var classId: Int
    var trackId: Int?
    var embedding: [Float]?
    var dogId: UUID?        // NEW: ReID matching result
    var dogName: String?    // NEW: Dog name for UI
    
    // Helper to maintain compatibility with existing code that might use 'label' or 'boundingBox'
    // If the previous YOLOClient used 'label', we might want to keep it or map it.
    // The prompt asked for specific fields, but let's add 'label' back if needed or just classId.
    // The prompt specified: bbox, confidence, classId, trackId, embedding, dogId, dogName.
    // However, YOLOClient previously used 'label'. I should probably keep 'label' or map classId to it.
    // Let's stick to the prompt's requested fields but add 'label' as a computed property or stored if useful.
    // Actually, looking at the prompt again, it says: "Ensure the struct has these fields".
    // It doesn't forbid others. YOLOClient uses 'label'. I will add 'label' to avoid breaking too much, 
    // or I will update YOLOClient to use classId. 
    // Let's add 'label' for safety as it was in the old DetectedObject.
    var label: String
    
    // Computed property for backward compatibility if needed, or just use bbox
    var boundingBox: CGRect {
        return bbox
    }
    
    init(bbox: CGRect, confidence: Float, classId: Int, label: String, trackId: Int? = nil, embedding: [Float]? = nil, dogId: UUID? = nil, dogName: String? = nil) {
        self.bbox = bbox
        self.confidence = confidence
        self.classId = classId
        self.label = label
        self.trackId = trackId
        self.embedding = embedding
        self.dogId = dogId
        self.dogName = dogName
    }
}
