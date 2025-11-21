import Foundation
import UIKit
import SwiftUI

@MainActor
final class VisionClient: ObservableObject {
    private let baseURL = URL(string: "http://192.168.0.77:8080/v1/chat/completions")!
    
    func analyzeImage(image: UIImage, name: String, breed: String) async throws -> String {
        // 이미지 리사이징 및 압축 (너무 크면 전송 실패 가능성)
        let maxDimension: CGFloat = 1024
        let resizedImage = image.resizedToFit(maxDimension: maxDimension) ?? image
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "VisionClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "이미지 데이터 변환 실패"])
        }
        
        let base64Image = imageData.base64EncodedString()
        let imageURL = "data:image/jpeg;base64,\(base64Image)"
        
        let systemPrompt = """
        You describe only the dog's visible appearance in Korean: color, size, fur, ears, eyes, markings, tail. Ignore pose, action, location, background, objects, people. Write 2-3 short sentences, under 100 characters total. Mention the dog's name in quotes and the breed in its own sentence.
        """
        
        let userPrompt = "Describe the dog named '\(name)'. State the breed '\(breed)' in its own sentence. Appearance only (no pose/action/location/background/objects/people), under 100 characters total."
        
        let requestBody: [String: Any] = [
            "model": "qwen3-vl-2b-instruct",
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userPrompt],
                        ["type": "image_url", "image_url": ["url": imageURL]]
                    ]
                ]
            ],
            "max_tokens": 3000,
            "temperature": 0.7
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer lm-studio", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 180
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "VisionClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "서버 에러: \(statusCode) - \(errorBody)"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        } else {
            throw NSError(domain: "VisionClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "응답 파싱 실패"])
        }
    }
}

// UIImage Extension for Resizing (AddDogView에 있는 것과 중복될 수 있으나, VisionClient가 독립적으로 동작하도록 포함하거나 AddDogView의 것을 사용해야 함. 여기서는 안전하게 private extension으로 추가하거나, AddDogView의 것을 public으로 변경해야 함. AddDogView의 것은 private이므로 여기에 private으로 복사함)
private extension UIImage {
    func resizedToFit(maxDimension: CGFloat) -> UIImage? {
        guard maxDimension > 0 else { return nil }
        let longerSide = max(size.width, size.height)
        guard longerSide > maxDimension else { return self }
        let scale = maxDimension / longerSide
        return resized(by: scale)
    }

    func resized(by scale: CGFloat) -> UIImage? {
        let safeScale = max(min(scale, 1.0), 0.01)
        let newSize = CGSize(
            width: max(1, size.width * safeScale),
            height: max(1, size.height * safeScale)
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
