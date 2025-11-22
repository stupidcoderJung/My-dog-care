import CoreData
import CoreImage
import CoreML
import CoreVideo
import Foundation
import ImageIO

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

    private let model: MLModel
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let processingQueue = DispatchQueue(label: Constants.queueLabel, qos: .userInitiated)

    init(configuration: MLModelConfiguration? = nil, ciContext: CIContext = CIContext()) throws {
        guard let modelURL = Bundle.main.url(forResource: "ResNet50_ReID", withExtension: "mlmodelc") else {
            print("--------------------------------------------------")
            print("CRITICAL ERROR: ReID Model resource not found.")
            print("PLEASE ENSURE 'ResNet50_ReID.mlmodel' IS ADDED TO THE XCODE PROJECT TARGET.")
            print("Location: ios-app/MyDogCare/Resources/Models/ResNet50_ReID.mlmodel")
            print("--------------------------------------------------")
            throw ReIDTrackerError.modelResourceMissing
        }
        
        // Enable Metal/GPU acceleration by default
        let config = configuration ?? {
            let c = MLModelConfiguration()
            c.computeUnits = .all  // Use CPU, GPU, and Neural Engine
            return c
        }()
        
        self.model = try MLModel(contentsOf: modelURL, configuration: config)
        self.ciContext = ciContext
    }

    func extractEmbedding(from image: CIImage) async throws -> [Float] {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ReIDTrackerError.embeddingConversionFailed)
                    return
                }

                do {
                    let pixelBuffer = try self.makePixelBuffer(from: image, targetSize: Constants.inputSize)
                    
                    // Create input feature provider
                    let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: pixelBuffer)])
                    
                    // Predict
                    let output = try self.model.prediction(from: input)
                    
                    // Get embedding
                    guard let embeddingFeature = output.featureValue(for: "embedding")?.multiArrayValue else {
                        throw ReIDTrackerError.embeddingConversionFailed
                    }
                    
                    let vector = try Self.vector(from: embeddingFeature)
                    continuation.resume(returning: vector)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func identify(embedding: [Float], knownDogs: [Dog], threshold: Float = Constants.similarityThreshold) -> UUID? {
        guard !embedding.isEmpty else {
            print("🔍 ReID identify: Empty embedding provided")
            return nil
        }
        
        print("🔍 ReID identify: Comparing against \(knownDogs.count) dogs with threshold \(threshold)")

        var bestMatch: (dog: Dog, similarity: Float)?

        for dog in knownDogs {
            guard let candidate = dog.embedding, candidate.count == embedding.count else {
                let dogName = dog.name ?? "unnamed"
                if dog.embedding == nil {
                    print("  ⚠️ Dog '\(dogName)' has no embedding - skipped")
                } else {
                    print("  ⚠️ Dog '\(dogName)' embedding size mismatch - skipped")
                }
                continue
            }

            let similarity = cosineSimilarity(embedding, candidate)
            let dogName = dog.name ?? "unnamed"
            print("  📐 Dog '\(dogName)': similarity = \(String(format: "%.3f", similarity))")
            
            guard similarity >= threshold else {
                print("    ❌ Below threshold (\(threshold))")
                continue
            }

            if bestMatch == nil || similarity > bestMatch!.similarity {
                bestMatch = (dog, similarity)
                print("    ✓ New best match!")
            }
        }
        
        if let match = bestMatch {
            let matchName = match.dog.name ?? "unnamed"
            print("🎯 Best match: '\(matchName)' with similarity \(String(format: "%.3f", match.similarity))")
        } else {
            print("💔 No match found above threshold")
        }

        return bestMatch?.dog.uuid
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
    func makePixelBuffer(from image: CIImage, targetSize: CGSize) throws -> CVPixelBuffer {
        let width = image.extent.width
        let height = image.extent.height
        guard width > 0, height > 0 else {
            throw ReIDTrackerError.invalidImageExtent
        }

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(targetSize.width),
            Int(targetSize.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw ReIDTrackerError.pixelBufferCreationFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        let oriented = image.oriented(.up)
        let normalized = oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y
        ))

        let scaleX = targetSize.width / max(normalized.extent.width, 1)
        let scaleY = targetSize.height / max(normalized.extent.height, 1)
        let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let bounds = CGRect(origin: .zero, size: targetSize)
        ciContext.render(scaled, to: pixelBuffer, bounds: bounds, colorSpace: colorSpace)

        return pixelBuffer
    }

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
