import SwiftUI

struct DetectionOverlay: View {
    let detectedDogs: [DogState]
    let imageSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(detectedDogs) { dog in
                let _ = print("DetectionOverlay: Rendering dog \(dog.name) at \(dog.bounds)")
                
                // Determine if this is an identified dog or generic detection
                let isIdentified = !dog.name.lowercased().contains("dog") && !dog.name.lowercased().contains("unknown")
                let boxColor: Color = isIdentified ? .green : .red
                let labelColor: Color = isIdentified ? .green : .orange
                
                // Bounding Box
                Path { path in
                    let rect = denormalize(rect: dog.bounds, in: geometry.size)
                    path.addRect(rect)
                }
                .stroke(boxColor, lineWidth: 2)
                
                // Label
                let rect = denormalize(rect: dog.bounds, in: geometry.size)
                Text("\(dog.name) \(Int(dog.confidence * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(4)
                    .background(labelColor.opacity(0.8))
                    .cornerRadius(4)
                    .position(x: rect.midX, y: max(rect.minY - 15, 15))
            }
        }
    }
    
    private func denormalize(rect: CGRect, in viewSize: CGSize) -> CGRect {
        // Calculate the actual frame of the image inside the view when using .scaledToFill
        let widthRatio = viewSize.width / imageSize.width
        let heightRatio = viewSize.height / imageSize.height
        let scale = max(widthRatio, heightRatio)
        
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let xOffset = (viewSize.width - scaledWidth) / 2
        let yOffset = (viewSize.height - scaledHeight) / 2
        
        // Vision coordinates: origin bottom-left, normalized [0,1]
        // SwiftUI coordinates: origin top-left
        
        // 1. Convert normalized Vision rect to normalized SwiftUI rect (flip Y)
        // Vision: (x, y, w, h) where y is from bottom
        // SwiftUI: y' = 1 - y - h
        let normX = rect.origin.x
        let normY = 1.0 - rect.origin.y - rect.height
        let normW = rect.width
        let normH = rect.height
        
        // 2. Scale to actual rendered image size
        let pixelX = normX * scaledWidth
        let pixelY = normY * scaledHeight
        let pixelW = normW * scaledWidth
        let pixelH = normH * scaledHeight
        
        // 3. Apply offset (centering)
        let finalX = pixelX + xOffset
        let finalY = pixelY + yOffset
        
        return CGRect(x: finalX, y: finalY, width: pixelW, height: pixelH)
    }
}
