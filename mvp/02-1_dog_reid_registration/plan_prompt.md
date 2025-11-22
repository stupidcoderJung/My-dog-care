# AI Assistant Prompt: Dog Registration with ReID Embeddings

## Task Overview
Extend AddDogView to extract and store ReID reference embeddings when registering a dog. This enables On-Air ReID identification to work.

## Context
- **Current Issue**: On-Air ReID identification fails because no reference embeddings are stored
- **Solution**: Extract embeddings from 3-5 reference photos during dog registration
- **Existing Code**:
  - `Views/AddDogView.swift` - Current dog registration UI
  - `Services/Vision/ReIDTracker.swift` - ReID model (needs extractEmbedding method)
  - `Models/Dog.swift` - Dog entity (needs referenceEmbeddings field)

## Your Task

### 1. Add referenceEmbeddings to Dog Model
**File**: `ios-app/MyDogCare/Models/Dog.swift`

**Option A: If using Core Data**
```swift
// Add Transformable attribute or store as JSON Data
@NSManaged var referenceEmbeddingsData: Data?

var referenceEmbeddings: [[Float]] {
    get {
        guard let data = referenceEmbeddingsData else { return [] }
        return (try? JSONDecoder().decode([[Float]].self, from: data)) ?? []
    }
    set {
        referenceEmbeddingsData = try? JSONEncoder().encode(newValue)
    }
}
```

**Option B: If using Codable Struct**
```swift
struct Dog: Codable, Identifiable {
    // ... existing fields ...
    var referenceEmbeddings: [[Float]] = []  // ADD THIS
}
```

### 2. Add extractEmbedding Method to ReIDTracker
**File**: `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift`

Add these methods:
```swift
import Vision
import CoreML
import UIKit

class ReIDTracker {
    // ... existing code ...
    
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
            
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try? handler.perform([request])
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
}
```

### 3. Update AddDogView
**File**: `ios-app/MyDogCare/Views/AddDogView.swift`

Add these @State variables:
```swift
// NEW: ReID References
@State private var referenceImages: [UIImage] = []
@State private var referenceEmbeddings: [[Float]] = []
@State private var showingReferenceImagePicker = false
@State private var isExtractingEmbedding = false

private let reidTracker = ReIDTracker()
```

Add new section in Form:
```swift
Section {
    VStack(alignment: .leading, spacing: 8) {
        Text("AI 인식용 사진 등록")
            .font(.headline)
        
        Text("강아지를 자동으로 식별하기 위해 3-5장의 사진을 등록해주세요.")
            .font(.caption)
            .foregroundColor(.secondary)
        
        // Reference images horizontal scroll
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Display existing images
                ForEach(Array(referenceImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Delete button
                        Button {
                            removeReferenceImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .background(Color.white.clipShape(Circle()))
                        }
                        .offset(x: 5, y: -5)
                    }
                }
                
                // Add button (max 5 images)
                if referenceImages.count < 5 {
                    Button {
                        showingReferenceImagePicker = true
                    } label: {
                        VStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                            Text("사진 추가")
                                .font(.caption)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        
        Text("\(referenceImages.count)/5장 등록됨")
            .font(.caption)
            .foregroundColor(referenceImages.count >= 3 ? .green : .orange)
    }
} header: {
    HStack {
        Text("AI 인식 설정")
        if isExtractingEmbedding {
            ProgressView()
                .scaleEffect(0.8)
        }
    }
}
```

Add helper methods:
```swift
private func addReferenceImage(_ image: UIImage) async {
    isExtractingEmbedding = true
    defer { isExtractingEmbedding = false }
    
    guard let ciImage = CIImage(image: image) else {
        print("❌ Failed to convert to CIImage")
        return
    }
    
    do {
        let embedding = try await reidTracker.extractEmbedding(from: ciImage)
        
        await MainActor.run {
            referenceImages.append(image)
            referenceEmbeddings.append(embedding)
            print("✅ Embedding extracted: \(embedding.count)d")
        }
    } catch {
        print("❌ Embedding extraction failed: \(error)")
    }
}

private func removeReferenceImage(at index: Int) {
    referenceImages.remove(at: index)
    referenceEmbeddings.remove(at: index)
}
```

Update saveDog() method:
```swift
private func saveDog() {
    let dog = Dog(
        id: UUID(),
        name: name,
        breed: breed.isEmpty ? nil : breed,
        birthdate: birthdate,
        // ... other fields
    )
    
    // NEW: Set reference embeddings
    dog.referenceEmbeddings = referenceEmbeddings
    
    // Save to Core Data/SwiftData
    context.insert(dog)
    try? context.save()
    
    print("✅ Dog saved with \(referenceEmbeddings.count) reference embeddings")
    
    dismiss()
}
```

Update "저장" button to require 3+ images:
```swift
ToolbarItem(placement: .confirmationAction) {
    Button("저장") {
        saveDog()
    }
    .disabled(name.isEmpty || referenceImages.count < 3)
}
```

## Acceptance Criteria

1. **Dog model** has `referenceEmbeddings: [[Float]]` field
2. **ReIDTracker.extractEmbedding()** returns 512d or 128d float array
3. **AddDogView** shows "AI 인식용 사진 등록" section
4. **Photo selection** extracts embedding automatically
5. **Minimum 3 photos** required to save
6. **Maximum 5 photos** can be registered
7. **Save** stores embeddings in Dog entity

## Testing

### Unit Test
```swift
let reidTracker = ReIDTracker()
let testImage = UIImage(named: "test_dog")!

let embedding = try await reidTracker.extractEmbedding(from: testImage)
print("Embedding size: \(embedding.count)")  // Should be 512 or 128
```

### UI Test
1. Open AddDogView
2. Enter name: "Buddy"
3. Click "사진 추가" in AI section
4. Select 3 dog photos
5. Progress indicators should show during extraction
6. Verify "\(3)/5장 등록됨" shows
7. "저장" button becomes enabled
8. Click "저장"
9. Check console:
   ```
   ✅ Embedding extracted: 512d
   ✅ Embedding extracted: 512d
   ✅ Embedding extracted: 512d
   ✅ Dog saved with 3 reference embeddings
   ```

### On-Air Integration Test
1. Register dog "Buddy" with 3 reference photos
2. Go to On-Air screen
3. Point camera at Buddy
4. After YOLO detection, ReID should identify as "Buddy"
5. Green bounding box with name should appear

## Performance Notes
- Embedding extraction: ~100-200ms per image
- Uses `async/await` to avoid UI blocking
- ProgressView indicates processing
- All 5 images: ~1 second total

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Models/Dog.swift` (add referenceEmbeddings)
- ✏️ `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift` (add extractEmbedding methods)
- ✏️ `ios-app/MyDogCare/Views/AddDogView.swift` (major update)

## References
- See `mvp/02-1_dog_reid_registration/plan.md` for full details
- ReID model at `Resources/Models/ResNet50_ReID.mlmodel`
