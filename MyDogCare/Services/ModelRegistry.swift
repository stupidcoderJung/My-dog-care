import Foundation
import UIKit
import SwiftUI

struct DebugTurn: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let images: [UIImage]
}

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
    
    func analyzeStream(images: [UIImage], dogs: [Dog]) async throws -> (response: String, debugTurns: [DebugTurn]) {
        // 1. System Prompt
        let systemPrompt = "You are an intelligent video analysis assistant designed to process multiple sequential image frames and output a consolidated decision in strictly valid JSON format without any markdown or prose."
        
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        var debugTurns: [DebugTurn] = [
            DebugTurn(role: "System", content: systemPrompt, images: [])
        ]
        
        // 2. Build History (Multi-turn)
        print("DEBUG: Starting to process \(dogs.count) dogs for history.")
        for dog in dogs {
            let name = dog.name ?? "Unknown"
            let breed = dog.breed ?? "Unknown"
            let photoId = dog.photoId
            let aiDescription = dog.aiDescription ?? "Analysis: This is \(name), a \(breed)."
            
            print("DEBUG: Processing dog: \(name), PhotoID: \(String(describing: photoId))")
            
            // Load dog image
            if let dogImage = DogPhotoStore.loadImage(id: dog.photoId) {
                print("DEBUG: Successfully loaded image for \(name)")
                let maxDimension: CGFloat = 512
                let resized = dogImage.resizedToFit(maxDimension: maxDimension) ?? dogImage
                if let data = resized.jpegData(compressionQuality: 0.5) {
                    let base64 = data.base64EncodedString()
                    
                    // User Turn: Image FIRST, then Text
                    let userText = "Describe the dog named '\(name)'. State the breed '\(breed)' in its own sentence."
                    let userTurnContent: [[String: Any]] = [
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
                        ["type": "text", "text": userText]
                    ]
                    
                    messages.append(["role": "user", "content": userTurnContent])
                    debugTurns.append(DebugTurn(role: "User", content: userText, images: [dogImage]))
                    
                    // Assistant Turn
                    messages.append(["role": "assistant", "content": aiDescription])
                    debugTurns.append(DebugTurn(role: "Assistant", content: aiDescription, images: []))
                }
            } else {
                print("DEBUG: Failed to load image for \(name) with ID: \(String(describing: photoId))")
            }
        }
        
        // 3. Current Request (Camera Stream)
        let maxDimension: CGFloat = 512
        var currentImageContent: [[String: Any]] = []
        
        let dogNamesString = dogs.compactMap { $0.name }.joined(separator: " | ")
        
        let finalUserPrompt = """
        You will see multiple images that provide temporal context.
        Your task is to produce exactly one consolidated decision - return it as a single
        JSON object on one line.
        Do not include any explanation or text outside the JSON.
        JSON schema:
        {
        "which": "\(dogNamesString)",
        "action": "one of allowed labels",
        "conf_which": 0.0,
        "conf_action": 0.0,
        "notes": "very brief cues (e.g., cone, curled tail, bowl, tongue, lying)"
        }
        Rules:
        - There are \(images.count) images in total.
        - Use all images only to improve confidence; do not return an array.
        - Allowed action labels:
        ["drink", "eat", "gait", "rest", "active_low", "active_high", "social", "grooming", "alert", "vocalizing", "other"]
        """
        
        // Images FIRST for current request too? The user didn't explicitly say for the final turn, but consistency is good.
        // However, usually for "analyze these images", images come first or last.
        // The user said "user에서 콘텐츠를 전달 할 땐, 이미지들이 앞에오게 합니다." which implies generally.
        // Let's put images first.
        
        for image in images {
            let resized = image.resizedToFit(maxDimension: maxDimension) ?? image
            if let data = resized.jpegData(compressionQuality: 0.5) {
                let base64 = data.base64EncodedString()
                currentImageContent.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]])
            }
        }
        currentImageContent.append(["type": "text", "text": finalUserPrompt])
        
        messages.append(["role": "user", "content": currentImageContent])
        debugTurns.append(DebugTurn(role: "User (Current)", content: finalUserPrompt, images: images))
        
        // 4. Build Request
        let requestBody: [String: Any] = [
            "model": "qwen3-vl-2b-instruct",
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.1,
            "response_format": ["type": "json_object"]
        ]
        
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer lm-studio", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 180
        
        // 5. Send Request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "VisionClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Server Error: \(statusCode) - \(errorBody)"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            return (content, debugTurns)
        } else {
            throw NSError(domain: "VisionClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Response parsing failed"])
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
