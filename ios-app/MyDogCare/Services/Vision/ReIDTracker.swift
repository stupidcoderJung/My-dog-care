import CoreData
import CoreImage
import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision
import UIKit

enum ReIDTrackerError: Error, LocalizedError {
    case invalidImageExtent
    case pixelBufferCreationFailed
    case embeddingConversionFailed
    case modelResourceMissing

    var errorDescription: String? {
        switch self {
        case .invalidImageExtent:
            return "The provided image has invalid dimensions."
        case .pixelBufferCreationFailed:
            return "Unable to create a Core Video pixel buffer for the model input."
        case .embeddingConversionFailed:
            return "Failed to convert the model output into a float vector."
        case .modelResourceMissing:
            return "Unable to locate or load the ReID model resource."
        }
    }
}

final class ReIDTracker {
    private enum Constants {
        static let inputSize = CGSize(width: 224, height: 224)
        static let similarityThreshold: Float = 0.7
        static let queueLabel = "com.mydogcare.reidtracker"
    }

    private let model: VNCoreMLModel
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let processingQueue = DispatchQueue(label: Constants.queueLabel, qos: .userInitiated)

    init(configuration: MLModelConfiguration? = nil, ciContext: CIContext = CIContext()) throws {
        guard let modelURL = Bundle.main.url(forResource: "ResNet50_ReID_Int8", withExtension: "mlmodelc") else {
            print("--------------------------------------------------")
            print("CRITICAL ERROR: ReID Model resource not found.")
            print("PLEASE ENSURE 'ResNet50_ReID_Int8.mlmodel' IS ADDED TO THE XCODE PROJECT TARGET.")
            print("Location: ios-app/MyDogCare/Resources/Models/ResNet50_ReID_Int8.mlmodel")
            print("--------------------------------------------------")
            throw ReIDTrackerError.modelResourceMissing
        }
        
        // Enable Metal/GPU acceleration by default
        let config = configuration ?? {
            let c = MLModelConfiguration()
            c.computeUnits = .all  // Use CPU, GPU, and Neural Engine
            return c
        }()
        
        let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
        self.model = try VNCoreMLModel(for: mlModel)
        self.ciContext = ciContext
    }

    // NEW: Extract embedding from CIImage
    func extractEmbedding(from ciImage: CIImage) async throws -> [Float] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNCoreMLFeatureValueObservation],
                      let embedding = results.first?.featureValue.multiArrayValue else {
                    continuation.resume(throwing: NSError(
                        domain: "ReIDTracker",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to extract embedding"]
                    ))
                    return
                }
                
                // Convert MLMultiArray → [Float]
                let floatArray = (0..<embedding.count).map { 
                    embedding[$0].floatValue 
                }
                
                continuation.resume(returning: floatArray)
            }
            
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // NEW: Convenience method for UIImage
    func extractEmbedding(from uiImage: UIImage) async throws -> [Float] {
        guard let ciImage = CIImage(image: uiImage) else {
            throw NSError(
                domain: "ReIDTracker",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to CIImage"]
            )
        }
        return try await extractEmbedding(from: ciImage)
    }

    /// Robust identification using Voting and Margin Check
    /// - Parameters:
    ///   - embedding: The vector to identify
    ///   - knownDogs: List of candidate dogs
    ///   - threshold: Minimum similarity to consider a match (default 0.7)
    ///   - margin: Minimum difference between 1st and 2nd best match to confirm (default 0.05)
    /// - Returns: UUID of the identified dog, or nil if ambiguous/unknown
    func identifyRobust(
        embedding: [Float],
        knownDogs: [Dog],
        threshold: Float = Constants.similarityThreshold,
        margin: Float = 0.05
    ) -> UUID? {
        guard !embedding.isEmpty else { return nil }
        
        // 1. Collect all candidate vectors with their Dog ID
        // Structure: (Dog, Similarity)
        var allCandidates: [(dog: Dog, similarity: Float)] = []
        
        for dog in knownDogs {
            let references = dog.referenceEmbeddingsList.isEmpty ? (dog.embedding.map { [$0] } ?? []) : dog.referenceEmbeddingsList
            for refVector in references {
                let sim = cosineSimilarity(embedding, refVector)
                if sim >= threshold {
                    allCandidates.append((dog, sim))
                }
            }
        }
        
        // 2. Sort by similarity descending
        allCandidates.sort { $0.similarity > $1.similarity }
        
        guard let bestMatch = allCandidates.first else {
            print("💔 ReID: No match found above threshold \(threshold)")
            return nil
        }
        
        // 3. Margin Check (Ambiguity Check)
        // If there is a runner-up from a DIFFERENT dog, check the gap.
        if let runnerUp = allCandidates.first(where: { $0.dog.uuid != bestMatch.dog.uuid }) {
            let gap = bestMatch.similarity - runnerUp.similarity
            if gap < margin {
                print("⚠️ ReID: Ambiguous! Best: \(bestMatch.dog.name ?? "?") (\(bestMatch.similarity)), 2nd: \(runnerUp.dog.name ?? "?") (\(runnerUp.similarity)). Gap \(gap) < \(margin)")
                return nil // Too close to call
            }
        }
        
        // 4. Voting (Top-3 Consensus) - Optional but good for stability
        // Look at top 3 candidates. If the best match dog appears at least twice, it's a strong match.
        // For small galleries, Margin Check is usually enough, but let's log voting for now.
        let top3 = allCandidates.prefix(3)
        let voteCount = top3.filter { $0.dog.uuid == bestMatch.dog.uuid }.count
        
        print("🎯 ReID: Match '\(bestMatch.dog.name ?? "Unknown")' (Sim: \(String(format: "%.3f", bestMatch.similarity)), Votes: \(voteCount)/\(top3.count))")
        
        return bestMatch.dog.uuid
    }

    func identify(embedding: [Float], knownDogs: [Dog], threshold: Float = Constants.similarityThreshold) -> UUID? {
        // Forward to robust method with default margin
        return identifyRobust(embedding: embedding, knownDogs: knownDogs, threshold: threshold, margin: 0.05)
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for index in 0..<a.count {
            let x = a[index]
            let y = b[index]
            dot += x * y
            normA += x * x
            normB += y * y
        }

        guard normA > 0, normB > 0 else { return 0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }
}

private extension ReIDTracker {
    static func vector(from multiArray: MLMultiArray) throws -> [Float] {
        let count = multiArray.count
        guard count > 0 else {
            throw ReIDTrackerError.embeddingConversionFailed
        }

        switch multiArray.dataType {
        case .float32:
            let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: pointer, count: count)
            return Array(buffer)
        case .double:
            let pointer = multiArray.dataPointer.bindMemory(to: Double.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: pointer, count: count)
            return buffer.map { Float($0) }
        default:
            throw ReIDTrackerError.embeddingConversionFailed
        }
    }
}

// Dog extension moved to Models/Dog.swift
