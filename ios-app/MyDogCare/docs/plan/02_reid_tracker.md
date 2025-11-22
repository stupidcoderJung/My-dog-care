# 🆔 Task 2: ReIDTracker Implementation

## 🎯 Objective
Create a `ReIDTracker` class that uses `ResNet50_ReID.mlmodel` to extract embeddings and match them against registered dogs.

## 📋 Detailed Steps
1.  **Create File**: `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift`.
2.  **Load Model**: Load `ResNet50_ReID`.
3.  **Embedding**: Implement `extractEmbedding(image: CIImage) -> [Float]`.
    *   Resize image to 224x224 (model input size).
4.  **Matching**: Implement `identifyDog(embedding: [Float], candidates: [Dog]) -> Dog?`.
    *   Calculate Cosine Similarity.
    *   Return match if similarity > 0.7.

## 🤖 AI Execution Prompt
(Copy this to the AI Agent)

```text
@ios-app/MyDogCare/Services/Vision/

I need you to execute **Task 2: ReIDTracker Implementation**.

**Instructions**:
1.  Create a new file `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift`.
2.  Implement `class ReIDTracker`:
    *   **Init**: Load `ResNet50_ReID` model.
    *   **Method**: `func extractEmbedding(from image: CIImage) async throws -> [Float]`
        *   Resize `CIImage` to 224x224.
        *   Run inference.
        *   Return the output tensor as `[Float]`.
    *   **Method**: `func identify(embedding: [Float], knownDogs: [Dog]) -> Dog?`
        *   Iterate through `knownDogs`.
        *   Calculate Cosine Similarity between input embedding and `dog.embedding`.
        *   Return the dog with highest similarity if > 0.7.
    *   **Helper**: `func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float`

**Deliverable**:
*   `ReIDTracker.swift` file.
```
