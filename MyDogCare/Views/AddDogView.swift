import CoreData
import PhotosUI
import SwiftUI
import UIKit

struct AddDogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var modelRegistry: ModelRegistry
    @State private var name: String = ""
    @State private var breed: String = ""
    @State private var selectedImage: UIImage?
    @State private var compressedImageData: Data?
    @State private var isPhotoOptionsPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isProcessingImage = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isCameraUnavailableAlertPresented = false
    @State private var saveErrorMessage: String?
    @State private var isShowingSaveError = false
    @State private var aiResponse: String?
    @State private var aiErrorMessage: String?
    @State private var isSendingToAI = false
    @State private var aiEmbedding: Data?
    private let aiImageMaxDimension: CGFloat = 256
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name
        case breed
    }

    var body: some View {
        Form {
            Section(header: Text("기본 정보")) {
                TextField("이름", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .breed }

                TextField("견종", text: $breed)
                    .focused($focusedField, equals: .breed)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
            }

            Section(header: Text("사진 등록")) {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Text("AI용 \(Int(aiImageMaxDimension))px로 압축됨")
                                    .font(.caption2)
                                    .padding(6)
                                    .background(.thinMaterial, in: Capsule())
                                    .padding(8)
                            }
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundStyle(.tertiary)
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("사진을 등록해 주세요")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    }

                    if isProcessingImage {
                        ProgressView("이미지 처리 중…")
                            .progressViewStyle(.circular)
                    }

                    Button {
                        isPhotoOptionsPresented = true
                    } label: {
                        Label("사진 등록", systemImage: "plus.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessingImage)

                    Button {
                        sendImageToAI()
                    } label: {
                        Label("AI에게 전달하기", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canSendToAI)

                    if !modelRegistry.isVisionPipelineReady {
                        Label("로컬 AI 모델을 준비하는 중이에요.", systemImage: "hourglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isSendingToAI {
                        ProgressView("AI 분석 중…")
                    } else if let aiResponse {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AI 응답")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(aiResponse)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    } else if let aiErrorMessage {
                        Text(aiErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("강아지 등록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("저장", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog("사진 등록", isPresented: $isPhotoOptionsPresented, titleVisibility: .visible) {
            Button("앨범에서 선택") {
                isPhotoPickerPresented = true
            }
            Button("카메라로 촬영") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    isCameraPresented = true
                } else {
                    isCameraUnavailableAlertPresented = true
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("사진을 가져올 방법을 선택하세요.")
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $photoPickerItem, matching: .images)
        .sheet(isPresented: $isCameraPresented) {
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await MainActor.run {
                        applyImage(image)
                    }
                }
            }
        }
        .alert("카메라를 사용할 수 없습니다", isPresented: $isCameraUnavailableAlertPresented) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("이 기기에서는 카메라를 사용할 수 없어요. 다른 방법을 선택해 주세요.")
        }
        .alert("저장할 수 없습니다", isPresented: $isShowingSaveError) {
            Button("확인", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .onChange(of: photoPickerItem) { newValue in
            guard let newValue else { return }
            Task { await loadImage(from: newValue) }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        compressedImageData != nil &&
        !isProcessingImage
    }

    private var canSendToAI: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        return modelRegistry.isVisionPipelineReady &&
        !trimmedName.isEmpty &&
        !trimmedBreed.isEmpty &&
        compressedImageData != nil &&
        !isProcessingImage &&
        !isSendingToAI
    }

    private func save() {
        guard selectedImage != nil,
              let imageData = compressedImageData else { return }

        do {
            let filename = try DogPhotoStore.saveImage(data: imageData)
            let dog = Dog(context: viewContext)
            dog.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            dog.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
            dog.photoId = filename
            dog.createdAt = Date()
            if let aiResponse {
                dog.aiDescription = aiResponse.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let aiEmbedding {
                dog.aiEmbedding = aiEmbedding
            } else {
                dog.aiEmbedding = imageData
            }

            try viewContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "강아지 정보를 저장하는 중 문제가 발생했습니다. 다시 시도해 주세요."
            isShowingSaveError = true
        }
    }

    private func sendImageToAI() {
        guard let imageData = compressedImageData else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedBreed.isEmpty else {
            aiErrorMessage = "이름과 견종을 입력해 주세요."
            return
        }

        guard let resources = modelRegistry.visionResources() else {
            aiErrorMessage = "AI 모델이 아직 준비되지 않았어요."
            return
        }

        let prompt = """
        <|im_start|>system
        You are a helpful assistant who only describes the dog's visual appearance in natural Korean sentences, using at most 50 English words.
        <|im_end|>
        <|im_start|>user
        this is my dog \(trimmedName) (\(trimmedBreed)). Based on the images, describe my dog's appearance in 50 words, mention \(trimmedName) exactly once, and do not invent unseen facts.
        <__media__>
        <|im_end|>
        <|im_start|>assistant
        """

        #if DEBUG
        print("[AI Prompt] \(prompt)")
        #endif

        isSendingToAI = true
        aiResponse = nil
        aiErrorMessage = nil
        aiEmbedding = nil

        Task {
            do {
                let response = try await resources.context.generateVisionResponse(
                    prompt: prompt,
                    imageData: [imageData],
                    projector: resources.projector,
                    maxTokens: 160
                )
                await MainActor.run {
                    aiResponse = response.text
                    aiEmbedding = response.embedding
                    isSendingToAI = false
                }
            } catch {
                await MainActor.run {
                    aiErrorMessage = error.localizedDescription
                    isSendingToAI = false
                }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem) async {
        await MainActor.run { isProcessingImage = true }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    applyImage(uiImage)
                    photoPickerItem = nil
                }
            }
        } catch {
            // 무시하고 재시도 가능
        }
        await MainActor.run { isProcessingImage = false }
    }

    private func applyImage(_ image: UIImage) {
        let resized = image.resizedToFit(maxDimension: aiImageMaxDimension) ?? image
        selectedImage = resized
        compressedImageData = resized.jpegData(compressionQuality: 0.4)
        aiResponse = nil
        aiErrorMessage = nil
        aiEmbedding = nil
    }
}

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
