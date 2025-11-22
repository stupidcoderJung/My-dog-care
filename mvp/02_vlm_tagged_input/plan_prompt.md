# AI Assistant Prompt: VLM Tagged Input

## Task Overview
Create an ImageTagger utility to overlay dog names on images, then send these tagged images to VLM for behavior analysis.

## Context
- **Prerequisites**: Step 01 completed (VisionService returns DetectedObject with dogId/dogName)
- **Existing Code**:
  - `Services/ModelRegistry.swift` - VisionClient with `analyzeStream()` method
  - `Services/Vision/VisionService.swift` - From Step 01

## Your Task

### 1. Create ImageTagger
**File**: `ios-app/MyDogCare/Services/Vision/ImageTagger.swift`

```swift
import UIKit
import CoreGraphics

class ImageTagger {
    func tagImage(_ image: UIImage, 
                  detections: [DetectedObject]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        
        let taggedImage = renderer.image { context in
            // 1. Draw original image
            image.draw(at: .zero)
            
            let cgContext = context.cgContext
            
            for detection in detections {
                // 2. Draw bbox
                cgContext.setStrokeColor(UIColor.green.cgColor)
                cgContext.setLineWidth(3.0)
                cgContext.stroke(detection.bbox)
                
                // 3. Draw dog name
                if let dogName = detection.dogName {
                    let text = "\(dogName) (\(Int(detection.confidence * 100))%)"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.green.withAlphaComponent(0.7)
                    ]
                    
                    let textPoint = CGPoint(
                        x: detection.bbox.minX,
                        y: detection.bbox.minY - 30
                    )
                    
                    (text as NSString).draw(at: textPoint, withAttributes: attributes)
                } else {
                    // Unknown dog
                    let text = "Unknown Dog"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: UIColor.red.withAlphaComponent(0.7)
                    ]
                    
                    let textPoint = CGPoint(
                        x: detection.bbox.minX,
                        y: detection.bbox.minY - 30
                    )
                    
                    (text as NSString).draw(at: textPoint, withAttributes: attributes)
                }
            }
        }
        
        return taggedImage
    }
}
```

### 2. Update VisionClient Prompt
**File**: `ios-app/MyDogCare/Services/ModelRegistry.swift`

In `analyzeStream()` method (around line 156), update the prompt:
```swift
let finalUserPrompt = """
Analyze the attached sequence of images.

**IMPORTANT**: Each detected dog has its NAME labeled above the bounding box.
Please use these EXACT NAMES in your response.

Context: Known dogs are: \(dogNamesString).

For each dog visible in the images:
1. Use the NAME shown on the image (in the green or red box)
2. Analyze posture, action, emotion, health_signals

Output Format: (same JSON schema as before)
...
"""
```

### 3. Add VLM Method to VisionService
**File**: `ios-app/MyDogCare/Services/Vision/VisionService.swift`

Add these properties and method:
```swift
class VisionService: ObservableObject {
    // ... existing code ...
    private let visionClient: VisionClient
    private let imageTagger: ImageTagger
    
    init() {
        // ... existing init ...
        self.visionClient = VisionClient()
        self.imageTagger = ImageTagger()
    }
    
    func analyzeWithVLM(
        frameHistory: [UIImage],
        detections: [DetectedObject],
        knownDogs: [Dog]
    ) async throws -> VisionResponse {
        // 1. Take last 5 frames
        let recentFrames = Array(frameHistory.suffix(5))
        
        // 2. Tag each frame with detection info
        let taggedFrames = recentFrames.map { frame in
            imageTagger.tagImage(frame, detections: detections)
        }
        
        // 3. Call VLM
        let (response, _) = try await visionClient.analyzeStream(
            images: taggedFrames,
            dogs: knownDogs
        )
        
        return response
    }
}
```

## Acceptance Criteria

1. **ImageTagger.tagImage()** returns image with:
   - Green boxes + dog names for identified dogs
   - Red boxes + "Unknown Dog" for unidentified dogs
2. **VisionService.analyzeWithVLM()** returns `VisionResponse`
3. **VLM prompt** instructs to use labeled names from images
4. **Test**: Tagged images are sent to VLM and response contains matching names

## Testing
```swift
// In OnAirView or test
let taggedImage = imageTagger.tagImage(frameImage, detections: detections)

// Save for inspection
if let data = taggedImage.pngData() {
    let url = FileManager.default.temporaryDirectory
               .appendingPathComponent("tagged_test.png")
    try? data.write(to: url)
    print("Tagged image saved: \(url)")
}

// Call VLM
let response = try await visionService.analyzeWithVLM(
    frameHistory: frameHistory,
    detections: detections,
    knownDogs: knownDogs
)

print("VLM Response:")
for dog in response.dogs {
    print("  - \(dog.name): \(dog.action), \(dog.emotion)")
}
```

## Files to Create/Modify
- ✏️ `ios-app/MyDogCare/Services/Vision/ImageTagger.swift` (create)
- ✏️ `ios-app/MyDogCare/Services/Vision/VisionService.swift` (add analyzeWithVLM)
- ✏️ `ios-app/MyDogCare/Services/ModelRegistry.swift` (update prompt)

## References
- See `mvp/02_vlm_tagged_input/plan.md` for full details
- VisionClient at `Services/ModelRegistry.swift` lines 100-292
