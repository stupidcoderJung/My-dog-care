import Foundation
import CoreGraphics

enum TrackState {
    case tentative
    case confirmed
    case deleted
}

final class Track {
    let trackId: Int
    private(set) var state: TrackState
    private(set) var timeSinceUpdate: Int = 0
    private(set) var hits: Int = 0
    private(set) var age: Int = 0
    
    // Kalman Filter for this track
    private let kalmanFilter: KalmanFilter
    
    // Last known embedding for ReID association
    private(set) var lastEmbedding: [Float]?
    
    // Dog identity (preserved across frames)
    private(set) var dogId: UUID?
    private(set) var dogName: String?
    
    // Temporal Voting System
    private var voteHistory: [UUID?] = []  // Last 10 votes
    private let maxVotes = 10
    private(set) var isIdentityConfirmed = false
    
    // Last known bounding box (predicted or updated)
    var currentBBox: CGRect {
        return kalmanFilter.currentState
    }
    
    init(trackId: Int, initialBBox: CGRect, embedding: [Float]?, dogId: UUID? = nil, dogName: String? = nil) {
        self.trackId = trackId
        self.state = .tentative
        self.kalmanFilter = KalmanFilter(initialBBox: initialBBox)
        self.lastEmbedding = embedding
        self.dogId = dogId
        self.dogName = dogName
    }
    
    func predict() {
        kalmanFilter.predict()
        age += 1
        timeSinceUpdate += 1
    }
    
    func update(detection: DetectedObject) {
        kalmanFilter.update(measurementBBox: detection.bbox)
        
        if let newEmbedding = detection.embedding {
            self.lastEmbedding = newEmbedding
        }
        
        // Temporal Voting: Add vote to history
        voteHistory.append(detection.dogId)
        if voteHistory.count > maxVotes {
            voteHistory.removeFirst()
        }
        
        // Always update dogName from detection (if available)
        if detection.dogId != nil && detection.dogName != nil {
            self.dogName = detection.dogName
        }
        
        // Confirm identity after 10 votes (or when we have enough data)
        if !isIdentityConfirmed && voteHistory.count >= maxVotes {
            confirmIdentity()
        } else if isIdentityConfirmed {
            // Already confirmed, just keep the confirmed identity
            // (don't change based on new votes)
        } else {
            // Still voting, use current majority
            updateFromVotes()
        }
        
        hits += 1
        timeSinceUpdate = 0
        
        // Simple logic: Confirm if hit enough times
        if state == .tentative && hits >= 3 {
            state = .confirmed
        }
    }
    
    func markMissed() {
        if state == .tentative {
            state = .deleted
        } else if timeSinceUpdate > 30 { // Lost for ~1 sec (at 30fps)
            state = .deleted
        }
    }
    
    func isConfirmed() -> Bool {
        return state == .confirmed
    }
    
    // MARK: - Temporal Voting
    
    private func confirmIdentity() {
        let winnerDogId = getMajorityVote()
        self.dogId = winnerDogId
        // Note: dogName will be set by the caller when they see dogId
        self.isIdentityConfirmed = true
        print("✅ Track #\(trackId): Identity CONFIRMED as \(winnerDogId?.uuidString ?? "Unknown") after \(voteHistory.count) votes")
    }
    
    private func updateFromVotes() {
        // Use current majority (but not confirmed yet)
        self.dogId = getMajorityVote()
    }
    
    private func getMajorityVote() -> UUID? {
        var voteCounts: [UUID?: Int] = [:]
        for vote in voteHistory {
            voteCounts[vote, default: 0] += 1
        }
        
        // Find the dogId with most votes
        return voteCounts.max(by: { $0.value < $1.value })?.key ?? nil
    }
}
