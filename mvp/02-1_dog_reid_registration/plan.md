# Step 02-1: Dog 등록 시 ReID Embedding 저장

## 목표
AddDogView에서 강아지를 등록할 때, ReID 모델을 사용하여 reference embeddings를 추출하고 저장합니다. 이를 통해 On-Air에서 ReID 식별이 가능해집니다.

**Output**: Dog 엔티티에 `referenceEmbeddings: [[Float]]` 저장 (3-5장 권장)

---

## 📋 체크리스트

### 2-1-1. Dog 모델에 referenceEmbeddings 필드 추가
- [ ] **Dog.swift 또는 Core Data 모델 확인**
  - 파일: `ios-app/MyDogCare/Models/Dog.swift` or Core Data
  - 필드 추가: `var referenceEmbeddings: [[Float]]`
  - 필드가 없으면 추가 필요

### 2-1-2. AddDogView에서 ReID Embedding 추출
- [ ] **ReIDTracker 활용**
  - 기존: `Services/Vision/ReIDTracker.swift` 사용
  - 메서드: `extractEmbedding(from image: UIImage) -> [Float]?`
  
- [ ] **여러 장 등록 UI 추가**
  - "AI 인식용 사진 등록 (3-5장)" 섹션 추가
  - 사진 선택/촬영 → embedding 추출 → 배열에 추가

### 2-1-3. 저장 로직 구현
- [ ] **Save 버튼 클릭 시**
  - referenceEmbeddings 배열을 Dog 엔티티에 저장
  - Core Data 또는 로컬 DB에 persist

---

## 🔧 구현 가이드

### Dog 모델 확장

**Option 1: SwiftData/Core Data 사용 시**
```swift
// Core Data Entity에 Transformable 속성 추가
@NSManaged var referenceEmbeddings: [[Float]]?

// 또는 JSON으로 저장
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

**Option 2: Codable Struct 사용 시**
```swift
struct Dog: Codable, Identifiable {
    let id: UUID
    var name: String
    var breed: String?
    var birthdate: Date?
    var sex: String?
    var profilePhotoURL: URL?
    
    var referenceEmbeddings: [[Float]] = []  // 추가
}
```

### AddDogView 확장

```swift
import SwiftUI
import PhotosUI

struct AddDogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var name = ""
    @State private var breed = ""
    @State private var birthdate = Date()
    @State private var profileImage: UIImage?
    
    // NEW: ReID References
    @State private var referenceImages: [UIImage] = []
    @State private var referenceEmbeddings: [[Float]] = []
    @State private var showingReferenceImagePicker = false
    @State private var isExtractingEmbedding = false
    
    private let reidTracker = ReIDTracker()
    
    var body: some View {
        NavigationView {
            Form {
                // 기존 섹션들 (이름, 프로필 사진 등)
                Section("기본 정보") {
                    TextField("이름", text: $name)
                    TextField("품종", text: $breed)
                    DatePicker("생일", selection: $birthdate, displayedComponents: .date)
                }
                
                Section("프로필 사진") {
                    // ... 기존 프로필 사진 로직
                }
                
                // NEW: ReID Reference 섹션
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI 인식용 사진 등록")
                            .font(.headline)
                        
                        Text("강아지를 자동으로 식별하기 위해 3-5장의 사진을 등록해주세요.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 등록된 사진들
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(referenceImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        // 삭제 버튼
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
                                
                                // 추가 버튼
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
            }
            .navigationTitle("강아지 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveDog()
                    }
                    .disabled(name.isEmpty || referenceImages.count < 3)
                }
            }
            .photosPicker(
                isPresented: $showingReferenceImagePicker,
                selection: Binding(
                    get: { nil },
                    set: { selection in
                        Task {
                            if let data = try? await selection?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                await addReferenceImage(image)
                            }
                        }
                    }
                ),
                matching: .images
            )
        }
    }
    
    // NEW: Reference Image 추가
    private func addReferenceImage(_ image: UIImage) async {
        isExtractingEmbedding = true
        defer { isExtractingEmbedding = false }
        
        // 1. 이미지를 CIImage로 변환
        guard let ciImage = CIImage(image: image) else {
            print("❌ Failed to convert to CIImage")
            return
        }
        
        // 2. ReID Embedding 추출
        do {
            let embedding = try await reidTracker.extractEmbedding(from: ciImage)
            
            // 3. 성공 시 저장
            await MainActor.run {
                referenceImages.append(image)
                referenceEmbeddings.append(embedding)
                print("✅ Embedding extracted: \(embedding.count)d")
            }
        } catch {
            print("❌ Embedding extraction failed: \(error)")
        }
    }
    
    // NEW: Reference Image 삭제
    private func removeReferenceImage(at index: Int) {
        referenceImages.remove(at: index)
        referenceEmbeddings.remove(at: index)
    }
    
    // 저장
    private func saveDog() {
        let dog = Dog(
            id: UUID(),
            name: name,
            breed: breed.isEmpty ? nil : breed,
            birthdate: birthdate,
            sex: nil,
            profilePhotoURL: nil  // TODO: 프로필 사진 저장
        )
        
        // NEW: referenceEmbeddings 설정
        dog.referenceEmbeddings = referenceEmbeddings
        
        // Core Data 또는 SwiftData에 저장
        context.insert(dog)
        try? context.save()
        
        print("✅ Dog saved with \(referenceEmbeddings.count) reference embeddings")
        
        dismiss()
    }
}
```

### ReIDTracker에 extractEmbedding 메서드 추가

**File**: `ios-app/MyDogCare/Services/Vision/ReIDTracker.swift`

```swift
import Vision
import CoreML
import UIKit

class ReIDTracker {
    private let model: VNCoreMLModel
    
    init() {
        // ResNet50_ReID 모델 로드
        guard let mlModel = try? ResNet50_ReID(configuration: MLModelConfiguration()).model,
              let visionModel = try? VNCoreMLModel(for: mlModel) else {
            fatalError("Failed to load ReID model")
        }
        self.model = visionModel
    }
    
    // NEW: CIImage에서 embedding 추출
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
                
                // MLMultiArray → [Float] 변환
                let floatArray = (0..<embedding.count).map { 
                    embedding[$0].floatValue 
                }
                
                continuation.resume(returning: floatArray)
            }
            
            // 224x224로 리사이징 (ReID 모델 입력 크기)
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // NEW: UIImage에서 embedding 추출 (편의 메서드)
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
    
    // 기존 identify 메서드는 그대로 유지
    func identify(embedding: [Float], knownDogs: [Dog], threshold: Float = 0.7) -> UUID? {
        // ... 기존 로직
    }
}
```

---

## 📚 참고 문서

### 기존 코드
- [AddDogView.swift](../../ios-app/MyDogCare/Views/AddDogView.swift)
- [ReIDTracker.swift](../../ios-app/MyDogCare/Services/Vision/ReIDTracker.swift)
- [Dog.swift](../../ios-app/MyDogCare/Models/Dog.swift)

### 관련 로드맵
- [Dog 엔티티 확장](../../docs/project_roadmap_new.md#1-2-dog-profile-엔티티-확장)
- [Reference Data Management](../../docs/project_roadmap_new.md#2-3-reference-data-management)

### ReID 모델
- Model: `ResNet50_ReID.mlmodel` (Step 01에서 준비됨)
- Input: 224x224 RGB image
- Output: 512d or 128d embedding vector

---

## ✅ 완료 조건

### 단위 테스트
- [ ] ReIDTracker.extractEmbedding() 호출 시 [Float] 배열 반환
- [ ] Embedding 크기가 512 또는 128 (모델에 따라)
- [ ] Dog.referenceEmbeddings 배열에 저장됨

### 통합 테스트
- [ ] AddDogView에서 사진 추가 → embedding 자동 추출
- [ ] 3-5장 등록 → Dog 저장
- [ ] Core Data에서 불러올 때 referenceEmbeddings 정상 로드

### UI 테스트
1. AddDogView 진입
2. "AI 인식용 사진 등록" 섹션 확인
3. "사진 추가" 버튼 클릭 → 사진 선택
4. ProgressView 표시 → embedding 추출 중
5. 사진 썸네일 추가됨
6. 3장 이상 등록 후 "저장" 버튼 활성화
7. 저장 → Console 확인:
   ```
   ✅ Embedding extracted: 512d
   ✅ Embedding extracted: 512d
   ✅ Embedding extracted: 512d
   ✅ Dog saved with 3 reference embeddings
   ```

### On-Air 연동 테스트
- [ ] Dog 등록 후 On-Air 화면 진입
- [ ] 카메라로 강아지 비춤
- [ ] ReID가 등록된 강아지 식별 → dogId 설정됨
- [ ] 이름이 바운딩 박스에 표시됨

---

## 🚨 중요 사항

### Embedding 추출 시간
- ReID 모델 추론: ~100-200ms (디바이스 성능에 따라)
- UI 블록 방지: `async/await` 사용하여 백그라운드 처리
- ProgressView로 사용자에게 진행 상황 표시

### 최소 등록 장수
- 권장: 3-5장
- 최소: 3장 (다양한 각도/조명)
- UI에서 3장 미만 시 "저장" 버튼 비활성화

### 데이터 크기
- 1개 embedding: 512 floats × 4 bytes = 2KB
- 5개 embeddings: ~10KB
- Core Data/SwiftData에 저장 가능

---

## 🎯 다음 단계

이 단계 완료 후:
- ✅ Dog 등록 시 ReID reference embeddings 저장
- ✅ On-Air에서 ReID 식별 작동
- **→ Step 03으로 진행 가능** (VLM → DogState 매핑)
