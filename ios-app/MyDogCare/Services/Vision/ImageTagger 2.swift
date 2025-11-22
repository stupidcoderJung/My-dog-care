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
                // Use red for unknown, green for known
                let isKnown = detection.dogName != nil
                let color = isKnown ? UIColor.green : UIColor.red
                
                cgContext.setStrokeColor(color.cgColor)
                cgContext.setLineWidth(3.0)
                cgContext.stroke(detection.bbox)
                
                // 3. Draw dog name
                if let dogName = detection.dogName {
                    let text = "\(dogName) (\(Int(detection.confidence * 100))%)"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: color.withAlphaComponent(0.7)
                    ]
                    
                    let textPoint = CGPoint(
                        x: detection.bbox.minX,
                        y: max(0, detection.bbox.minY - 30) // Ensure text doesn't go off-screen
                    )
                    
                    (text as NSString).draw(at: textPoint, withAttributes: attributes)
                } else {
                    // Unknown dog
                    let text = "Unknown Dog"
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 24),
                        .foregroundColor: UIColor.white,
                        .backgroundColor: color.withAlphaComponent(0.7)
                    ]
                    
                    let textPoint = CGPoint(
                        x: detection.bbox.minX,
                        y: max(0, detection.bbox.minY - 30)
                    )
                    
                    (text as NSString).draw(at: textPoint, withAttributes: attributes)
                }
            }
        }
        
        return taggedImage
    }
}
