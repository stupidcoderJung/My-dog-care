import Foundation
import CoreData
import CryptoKit

extension Dog {
    
    // MARK: - Embeddings
    
    /// Single embedding for the dog (legacy/primary)
    var embedding: [Float]? {
        get {
            guard let data = aiEmbedding else { return nil }
            return try? data.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }
        set {
            guard let newValue else {
                aiEmbedding = nil
                return
            }
            aiEmbedding = Data(bytes: newValue, count: newValue.count * MemoryLayout<Float>.stride)
        }
    }
    
    /// Multiple reference embeddings for better ReID accuracy
    /// Multiple reference embeddings for better ReID accuracy
    /// Renamed to referenceEmbeddingsList to avoid conflict with Core Data 'referenceEmbeddings' attribute
    var referenceEmbeddingsList: [[Float]] {
        get {
            guard let data = primitiveValue(forKey: "referenceEmbeddings") as? Data else { return [] }
            do {
                return try JSONDecoder().decode([[Float]].self, from: data)
            } catch {
                print("Error decoding referenceEmbeddings: \(error)")
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                setPrimitiveValue(data, forKey: "referenceEmbeddings")
            } catch {
                print("Error encoding referenceEmbeddings: \(error)")
            }
        }
    }
    
    /// Filenames of reference images stored in disk
    var referenceImageIdList: [String] {
        get {
            guard let data = primitiveValue(forKey: "referenceImageIds") as? Data else { return [] }
            do {
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                print("Error decoding referenceImageIds: \(error)")
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                setPrimitiveValue(data, forKey: "referenceImageIds")
            } catch {
                print("Error encoding referenceImageIds: \(error)")
            }
        }
    }
    
    // Helper to add a new embedding to references
    func addReferenceEmbedding(_ newEmbedding: [Float]) {
        var current = referenceEmbeddingsList
        current.append(newEmbedding)
        // Limit to 5 embeddings to save space/time
        if current.count > 5 {
            current.removeFirst(current.count - 5)
        }
        referenceEmbeddingsList = current
    }
    
    // Deterministic UUID based on objectID
    var uuid: UUID {
        let uriString = objectID.uriRepresentation().absoluteString
        let hash = SHA256.hash(data: Data(uriString.utf8))
        var bytes = Array(hash.prefix(16))

        if bytes.count < 16 {
            bytes.append(contentsOf: Array(repeating: 0, count: 16 - bytes.count))
        }

        return bytes.withUnsafeBytes { rawBuffer in
            let buffer = rawBuffer.bindMemory(to: UInt8.self)
            return UUID(uuid: (
                buffer[0], buffer[1], buffer[2], buffer[3],
                buffer[4], buffer[5], buffer[6], buffer[7],
                buffer[8], buffer[9], buffer[10], buffer[11],
                buffer[12], buffer[13], buffer[14], buffer[15]
            ))
        }
    }
}
