import CoreData
import PhotosUI
import SwiftUI
import UIKit

struct AddDogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var visionClient: VisionClient
    @State private var name: String = ""
    @State private var breed: String = ""
    @State private var selectedImage: UIImage?
    @State private var compressedImageData: Data?
    @State private var isPhotoOptionsPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var isProcessingImage = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var referencePickerItems: [PhotosPickerItem] = []
    @State private var isCameraUnavailableAlertPresented = false
    @State private var saveErrorMessage: String?
    @State private var isShowingSaveError = false
    @State private var aiResponse: String?
    @State private var aiErrorMessage: String?
    @State private var isSendingToAI = false
    
    // NEW: ReID References
    @State private var referenceImages: [UIImage] = []
    @State private var referenceEmbeddings: [[Float]] = []
    @State private var showingReferenceImagePicker = false
    @State private var showingReferenceImageOptions = false
    @State private var showingReferenceCamera = false
    @State private var isExtractingEmbedding = false
    private let reidTracker = try? ReIDTracker()

//    private let aiImageMaxDimension: CGFloat = 256
    private let aiImageDimension: CGFloat = 112
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name
        case breed
    }

    var body: some View {
        Form {
            basicInfoSection
            photoRegistrationSection
            aiReferenceSection
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
        .sheet(isPresented: $isCameraPresented) {
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await MainActor.run {
                        applyImage(image)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingReferenceCamera) {
            MultiCameraView { images in
                Task {
                    for image in images {
                        await addReferenceImage(image)
                    }
                }
            }
        }
        .photosPicker(isPresented: $isPhotoPickerPresented, selection: $photoPickerItem, matching: .images)
        .photosPicker(isPresented: $showingReferenceImagePicker, selection: $referencePickerItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: referencePickerItems) { newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await addReferenceImage(image)
                    }
                }
                referencePickerItems = []
            }
        }
        .onChange(of: photoPickerItem) { newValue in
            guard let newValue else { return }
            Task { await loadImage(from: newValue) }
        }
        .confirmationDialog("사진 등록", isPresented: $isPhotoOptionsPresented, titleVisibility: .visible) {
            Button("앨범에서 선택") { isPhotoPickerPresented = true }
            Button("카메라로 촬영") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    isCameraPresented = true
                } else {
                    isCameraUnavailableAlertPresented = true
                }
            }
            Button("취소", role: .cancel) { }
        } message: { Text("사진을 가져올 방법을 선택하세요.") }
        .confirmationDialog("참조 사진 등록", isPresented: $showingReferenceImageOptions, titleVisibility: .visible) {
            Button("앨범에서 선택") { showingReferenceImagePicker = true }
            Button("카메라로 촬영") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showingReferenceCamera = true
                } else {
                    isCameraUnavailableAlertPresented = true
                }
            }
            Button("취소", role: .cancel) { }
        } message: { Text("사진을 가져올 방법을 선택하세요.") }
        .alert("카메라를 사용할 수 없습니다", isPresented: $isCameraUnavailableAlertPresented) {
            Button("확인", role: .cancel) { }
        } message: { Text("이 기기에서는 카메라를 사용할 수 없어요. 다른 방법을 선택해 주세요.") }
        .alert("저장할 수 없습니다", isPresented: $isShowingSaveError) {
            Button("확인", role: .cancel) { saveErrorMessage = nil }
        } message: { Text(saveErrorMessage ?? "") }
    }
    
    private var basicInfoSection: some View {
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
    }
    
    private var photoRegistrationSection: some View {
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
                            Text("112px AI 최적화 완료")
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
    
    private var aiReferenceSection: some View {
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
                                showingReferenceImageOptions = true
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
                .padding(.vertical, 4)
                
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

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        compressedImageData != nil &&
        !isProcessingImage &&
        referenceImages.count >= 3
    }

    private var canSendToAI: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty &&
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
            
            // NEW: Set reference embeddings
            dog.referenceEmbeddingsList = referenceEmbeddings
            
            // NEW: Save reference images to disk
            var savedImageIds: [String] = []
            for (index, image) in referenceImages.enumerated() {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    do {
                        let filename = try DogPhotoStore.saveImage(data: data)
                        savedImageIds.append(filename)
                    } catch {
                        print("Failed to save reference image \(index): \(error)")
                    }
                }
            }
            dog.referenceImageIdList = savedImageIds


            try viewContext.save()
            dismiss()
        } catch {
            saveErrorMessage = "강아지 정보를 저장하는 중 문제가 발생했습니다. 다시 시도해 주세요."
            isShowingSaveError = true
        }
    }

    private func sendImageToAI() {
        guard let imageData = selectedImage else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBreed = breed.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedBreed.isEmpty else {
            aiErrorMessage = "이름과 견종을 입력해 주세요."
            return
        }

        isSendingToAI = true
        aiResponse = nil
        aiErrorMessage = nil

        Task {
            do {
                let response = try await visionClient.analyzeImage(image: imageData, name: trimmedName, breed: trimmedBreed)
                await MainActor.run {
                    aiResponse = response
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
        // 1. 정사각형 크롭
        guard let cropped = image.cropToCenterSquare() else { return }
        
        // 2. 112x112 리사이징
        let targetSize = CGSize(width: aiImageDimension, height: aiImageDimension)
        let resized = cropped.resize(to: targetSize) ?? cropped
        
        selectedImage = resized
        // 이미지가 작으므로 압축률을 높여도 용량이 작음 (0.8 정도)
        compressedImageData = resized.jpegData(compressionQuality: 0.8)
        
        aiResponse = nil
        aiErrorMessage = nil
    }

    
    private func addReferenceImage(_ image: UIImage) async {
        isExtractingEmbedding = true
        defer { isExtractingEmbedding = false }
        
        guard let tracker = reidTracker else {
            print("❌ ReIDTracker not available")
            return
        }
        
        guard let ciImage = CIImage(image: image) else {
            print("❌ Failed to convert to CIImage")
            return
        }
        
        do {
            let embedding = try await tracker.extractEmbedding(from: ciImage)
            
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
}

private extension UIImage {
    func cropToCenterSquare() -> UIImage? {
        let originalWidth = size.width
        let originalHeight = size.height
        let edge = min(originalWidth, originalHeight)
        
        let posX = (originalWidth - edge) / 2.0
        let posY = (originalHeight - edge) / 2.0
        
        // cgImage는 픽셀 단위 좌표계를 사용하므로 scale을 고려해야 함
        let cropRect = CGRect(
            x: posX * scale,
            y: posY * scale,
            width: edge * scale,
            height: edge * scale
        )
        
        guard let cgImage = cgImage?.cropping(to: cropRect) else { return nil }
        
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }

    func resize(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            context.cgContext.interpolationQuality = .high
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

struct MultiCameraView: View {
    @Environment(\.dismiss) private var dismiss
    var onImagesCaptured: ([UIImage]) -> Void
    
    @StateObject private var model = CameraModel()
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(session: model.session)
                .ignoresSafeArea()
                .onAppear {
                    model.checkPermissions()
                }
            
            VStack {
                // Top Bar
                HStack {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    Spacer()
                    
                    Text("\(model.capturedImages.count)장 촬영됨")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                    
                    Spacer()
                    
                    Button("완료") {
                        onImagesCaptured(model.capturedImages)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(.blue, in: Capsule())
                    .disabled(model.capturedImages.isEmpty)
                }
                .padding()
                
                Spacer()
                
                // Bottom Bar
                HStack(alignment: .center, spacing: 30) {
                    // Thumbnail of last captured image
                    if let lastImage = model.capturedImages.last {
                        Image(uiImage: lastImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 2))
                    } else {
                        Color.clear.frame(width: 60, height: 60)
                    }
                    
                    // Shutter Button
                    Button {
                        model.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: 70, height: 70)
                        }
                    }
                    
                    // Spacer to balance layout
                    Color.clear.frame(width: 60, height: 60)
                }
                .padding(.bottom, 30)
            }
        }
        .background(.black)
    }
}

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var capturedImages: [UIImage] = []
    @Published var alert: AlertError?
    
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera_queue")
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setup()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] status in
                if status {
                    self?.setup()
                }
            }
        case .denied:
            alert = AlertError(title: "카메라 권한 없음", message: "설정에서 카메라 접근을 허용해주세요.")
        default:
            return
        }
    }
    
    func setup() {
        do {
            session.beginConfiguration()
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            session.commitConfiguration()
            
            queue.async {
                self.session.startRunning()
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        DispatchQueue.main.async {
            self.capturedImages.append(image)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.frame
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct AlertError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
