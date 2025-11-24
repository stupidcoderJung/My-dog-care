import Foundation
import CoreGraphics

final class DeepSortTracker {
    private var tracks: [Track] = []
    private var nextTrackId = 1
    
    // Parameters
    private let maxAge = 30
    private let nInit = 3
    private let maxCosineDistance: Float = 0.4
    private let maxIouDistance: Float = 0.7
    
    func update(detections: [DetectedObject]) -> [DetectedObject] {
        var results: [DetectedObject] = []
        
        print("🔄 DeepSORT 업데이트: \(detections.count)개 감지. 활성 트랙: \(tracks.count)개, 확정: \(tracks.filter { $0.isIdentityConfirmed }.count)개")
        
        // 1. Predict
        for track in tracks {
            track.predict()
        }
        
        // 2. Match
        // Separate confirmed and tentative tracks
        let confirmedTracks = tracks.filter { $0.isConfirmed() }
        let tentativeTracks = tracks.filter { !$0.isConfirmed() }
        
        // Match confirmed tracks with detections
        var (matches, unmatchedTracks, unmatchedDetections) = match(
            tracks: confirmedTracks,
            detections: detections
        )
        
        // Match tentative tracks with remaining detections (IoU only usually, but we use same logic)
        // For simplicity in this Lite version, we treat them similarly or could do a second pass.
        // Let's do a second pass for unmatched tentative tracks and unmatched detections using IoU only
        // to handle initialization.
        
        // Actually, let's keep it simple: Single pass greedy matching for now.
        // If we split, we need to handle the indices carefully.
        // Let's refine:
        // We matched confirmed. Now try to match tentative with remaining detections.
        
        // ... (Skipping complex cascade for Lite version) ...
        
        // Let's just use the results from the first pass for simplicity, 
        // but we need to handle tentative tracks that were not in 'confirmedTracks'.
        // They are technically "unmatched" in the first pass context.
        
        // Re-merge for processing
        // 'unmatchedTracks' currently only contains indices from 'confirmedTracks'.
        // We need to add all 'tentativeTracks' to the 'unmatched' set to see if they can match remaining detections?
        // Or better: Just match ALL tracks against ALL detections in one go for this Lite version.
        // It's O(N*M) which is fine for N, M < 20.
        
        (matches, unmatchedTracks, unmatchedDetections) = match(tracks: tracks, detections: detections)
        
        // 3. Update Tracks FIRST (so track.dogId is current)
        for (trackIdx, detectionIdx) in matches {
            tracks[trackIdx].update(detection: detections[detectionIdx])
        }
        
        // 4. Add matched detections to results with updated Track info
        for (trackIdx, detectionIdx) in matches {
            var detection = detections[detectionIdx]
            let track = tracks[trackIdx]
            
            detection.trackId = track.trackId
            // Use Kalman Filter predicted position for smooth tracking
            detection.bbox = track.currentBBox
            
            // ALWAYS use track's identity (it's been updated in step 3)
            detection.dogId = track.dogId
            detection.dogName = track.dogName
            
            results.append(detection)
        }
        
        // 5. Create New Tracks for unmatched detections
        for detectionIdx in unmatchedDetections {
            let detection = detections[detectionIdx]
            let newTrack = initTrack(detection: detection)
            
            // Add to results immediately so they appear on UI
            var result = detection
            result.trackId = newTrack.trackId
            // dogId and dogName come from ReID (stored in newTrack)
            result.dogId = newTrack.dogId
            result.dogName = newTrack.dogName
            results.append(result)
        }
        
        // 6. Mark ONLY unmatched tracks as missed
        for unmatchedIdx in unmatchedTracks {
            tracks[unmatchedIdx].markMissed()
        }
        
        // 7. Add coasting tracks BEFORE deletion (to use correct indices)
        // If a track is confirmed but missed this frame, we can output its prediction.
        for trackIdx in unmatchedTracks {
            let track = tracks[trackIdx]
            if track.isConfirmed() && track.timeSinceUpdate < 5 { // Coast for 5 frames
                let prediction = DetectedObject(
                    bbox: track.currentBBox,
                    confidence: 0.0, // Low confidence to indicate prediction
                    classId: 0,
                    label: track.dogName ?? "dog",  // Use stored dog name
                    trackId: track.trackId,
                    embedding: track.lastEmbedding,
                    dogId: track.dogId,  // Use stored dog ID
                    dogName: track.dogName  // Use stored dog name
                )
                results.append(prediction)
            }
        }
        
        // 8. Delete lost tracks (AFTER using indices)
        tracks.removeAll { track in
            return track.state == .deleted
        }
        
        return results
    }
    
    // MARK: - Two-Phase Update (ReID Optimization)
    
    /// Phase 1: Match detections to tracks using only IoU (no ReID)
    /// Returns indices of detections that need ReID
    func matchWithoutReID(detections: [DetectedObject]) -> [Int] {
        print("🔄 1단계 매칭: \(detections.count)개 감지. 활성 트랙: \(tracks.count)개, 확정: \(tracks.filter { $0.isIdentityConfirmed }.count)개")
        
        // 1. Predict
        for track in tracks {
            track.predict()
        }
        
        // 2. Match using IoU only
        let (matches, unmatchedTracks, unmatchedDetections) = matchIoUOnly(tracks: tracks, detections: detections)
        
        print("  📊 매칭 결과: \(matches.count)개 매칭, \(unmatchedTracks.count)개 트랙 미매칭, \(unmatchedDetections.count)개 감지 미매칭")
        
        // 3. Identify which detections need ReID
        var needsReID: Set<Int> = []
        
        // Matched detections: only need ReID if track is NOT confirmed
        for (trackIdx, detectionIdx) in matches {
            let track = tracks[trackIdx]
            if !track.isIdentityConfirmed {
                needsReID.insert(detectionIdx)
                print("  🔍 감지 #\(detectionIdx) → ReID 필요 (미확정 트랙 #\(track.trackId)에 매칭됨)")
            } else {
                print("  ✅ 감지 #\(detectionIdx) → ReID 생략 (확정 트랙 #\(track.trackId)에 매칭됨)")
            }
        }
        
        // Unmatched detections: always need ReID (new tracks)
        for detectionIdx in unmatchedDetections {
            needsReID.insert(detectionIdx)
            print("  🆕 감지 #\(detectionIdx) → ReID 필요 (새로운/미매칭)")
        }
        
        let needReIDCount = needsReID.count
        let skipCount = detections.count - needReIDCount
        print("⚡ ReID 실행: \(needReIDCount)/\(detections.count)개 (생략: \(skipCount)개)")
        
        return Array(needsReID)
    }
    
    /// Phase 2: Finalize with ReID results
    func finalizeWithReID(detections: [DetectedObject]) -> [DetectedObject] {
        var results: [DetectedObject] = []
        
        // Match again (matching is cheap, ReID was expensive)
        let (matches, unmatchedTracks, unmatchedDetections) = match(tracks: tracks, detections: detections)
        
        // Update matched tracks
        for (trackIdx, detectionIdx) in matches {
            tracks[trackIdx].update(detection: detections[detectionIdx])
        }
        
        // Add matched detections to results
        for (trackIdx, detectionIdx) in matches {
            var detection = detections[detectionIdx]
            let track = tracks[trackIdx]
            
            detection.trackId = track.trackId
            detection.bbox = track.currentBBox
            detection.dogId = track.dogId
            detection.dogName = track.dogName
            
            results.append(detection)
        }
        
        // Create new tracks
        for detectionIdx in unmatchedDetections {
            let detection = detections[detectionIdx]
            let newTrack = initTrack(detection: detection)
            
            var result = detection
            result.trackId = newTrack.trackId
            result.dogId = newTrack.dogId
            result.dogName = newTrack.dogName
            results.append(result)
        }
        
        // Mark unmatched tracks as missed
        for unmatchedIdx in unmatchedTracks {
            tracks[unmatchedIdx].markMissed()
        }
        
        // Add coasting tracks
        for trackIdx in unmatchedTracks {
            let track = tracks[trackIdx]
            if track.isConfirmed() && track.timeSinceUpdate < 5 {
                let prediction = DetectedObject(
                    bbox: track.currentBBox,
                    confidence: 0.0,
                    classId: 0,
                    label: track.dogName ?? "dog",
                    trackId: track.trackId,
                    embedding: track.lastEmbedding,
                    dogId: track.dogId,
                    dogName: track.dogName
                )
                results.append(prediction)
            }
        }
        
        // Delete lost tracks
        tracks.removeAll { track in
            return track.state == .deleted
        }
        
        return results
    }

    
    private func initTrack(detection: DetectedObject) -> Track {
        let track = Track(
            trackId: nextTrackId,
            initialBBox: detection.bbox,
            embedding: detection.embedding,
            dogId: detection.dogId,
            dogName: detection.dogName
        )
        tracks.append(track)
        nextTrackId += 1
        return track
    }
    
    // Greedy Matching
    private func match(tracks: [Track], detections: [DetectedObject]) -> ([(Int, Int)], [Int], [Int]) {
        var matches: [(Int, Int)] = []
        var unmatchedTracks = Set(0..<tracks.count)
        var unmatchedDetections = Set(0..<detections.count)
        
        if tracks.isEmpty || detections.isEmpty {
            return ([], Array(unmatchedTracks), Array(unmatchedDetections))
        }
        
        // Calculate Cost Matrix
        // Rows: Tracks, Cols: Detections
        var costs: [(trackIdx: Int, detIdx: Int, cost: Float)] = []
        
        for (tIdx, track) in tracks.enumerated() {
            for (dIdx, det) in detections.enumerated() {
                let cost = calculateCost(track: track, detection: det)
                if cost < 1.0 { // Threshold
                    costs.append((tIdx, dIdx, cost))
                }
            }
        }
        
        // Sort by cost ascending
        costs.sort { $0.cost < $1.cost }
        
        // Greedy assignment
        for (tIdx, dIdx, _) in costs {
            if unmatchedTracks.contains(tIdx) && unmatchedDetections.contains(dIdx) {
                matches.append((tIdx, dIdx))
                unmatchedTracks.remove(tIdx)
                unmatchedDetections.remove(dIdx)
            }
        }
        
        return (matches, Array(unmatchedTracks), Array(unmatchedDetections))
    }
    
    // IoU-only matching (for Phase 1)
    private func matchIoUOnly(tracks: [Track], detections: [DetectedObject]) -> ([(Int, Int)], [Int], [Int]) {
        var matches: [(Int, Int)] = []
        var unmatchedTracks = Set(0..<tracks.count)
        var unmatchedDetections = Set(0..<detections.count)
        
        if tracks.isEmpty || detections.isEmpty {
            return ([], Array(unmatchedTracks), Array(unmatchedDetections))
        }
        
        // Calculate IoU costs only
        var costs: [(trackIdx: Int, detIdx: Int, cost: Float)] = []
        
        for (tIdx, track) in tracks.enumerated() {
            for (dIdx, det) in detections.enumerated() {
                let iou = calculateIoU(track.currentBBox, det.bbox)
                if iou > 0.1 {  // Minimum IoU threshold
                    costs.append((tIdx, dIdx, 1.0 - iou))
                }
            }
        }
        
        // Sort by cost ascending
        costs.sort { $0.cost < $1.cost }
        
        // Greedy assignment
        for (tIdx, dIdx, _) in costs {
            if unmatchedTracks.contains(tIdx) && unmatchedDetections.contains(dIdx) {
                matches.append((tIdx, dIdx))
                unmatchedTracks.remove(tIdx)
                unmatchedDetections.remove(dIdx)
            }
        }
        
        return (matches, Array(unmatchedTracks), Array(unmatchedDetections))
    }
    
    private func calculateCost(track: Track, detection: DetectedObject) -> Float {
        // 1. IoU Cost (0.0 to 1.0)
        let iou = calculateIoU(track.currentBBox, detection.bbox)
        let iouCost = 1.0 - iou
        
        // 2. Appearance Cost (Cosine Distance)
        var appearanceCost: Float = 0.0
        if let trackEmb = track.lastEmbedding, let detEmb = detection.embedding {
            appearanceCost = 1.0 - cosineSimilarity(trackEmb, detEmb)
        } else {
            // If no embedding, rely solely on IoU (set appearance cost to neutral or ignore)
            appearanceCost = 0.0 
        }
        
        // Gate: If IoU is too low, reject (Cost = infinity)
        if iou < 0.1 { return 100.0 }
        
        // Weighted Sum
        // If we have embeddings, weight them. Otherwise just IoU.
        if track.lastEmbedding != nil && detection.embedding != nil {
            return 0.5 * iouCost + 0.5 * appearanceCost
        } else {
            return iouCost
        }
    }
    
    private func calculateIoU(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        let union = a.union(b)
        
        if union.width == 0 || union.height == 0 { return 0 }
        
        let iArea = intersection.width * intersection.height
        let uArea = a.width * a.height + b.width * b.height - iArea
        
        return Float(iArea / uArea)
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        // Assuming normalized vectors for speed, but let's compute dot product
        // ReIDTracker already returns normalized? Let's assume standard dot/norm.
        // Copying helper from ReIDTracker or just simple implementation
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<min(a.count, b.count) {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        if normA == 0 || normB == 0 { return 0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }
}
