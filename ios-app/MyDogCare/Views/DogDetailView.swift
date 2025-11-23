import SwiftUI
import UIKit

struct DogDetailView: View {
    @ObservedObject var dog: Dog
    @State private var photo: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                dogPhotoSection
                infoCard
                aiInsightsCard
                aiDataCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(dog.name ?? "강아지 정보")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: dog.objectID) {
            photo = DogPhotoStore.loadImage(id: dog.photoId)
        }
    }

    private var dogPhotoSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 220)

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "pawprint")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("등록된 사진이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var infoCard: some View {
        detailCard(title: "기본 정보") {
            DetailRow(title: "이름", value: dog.name ?? "이름 없음")
            DetailRow(title: "견종", value: dog.breed ?? "견종 정보 없음")
            DetailRow(title: "등록일", value: createdAtDisplayText)
        }
    }

    private var aiInsightsCard: some View {
        detailCard(title: "AI 분석") {
            if let description = dog.aiDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("AI 설명이 아직 없어요")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }


        }
    }
    
    private var aiDataCard: some View {
        detailCard(title: "AI 인식 데이터") {
            if dog.referenceImageIdList.isEmpty {
                Text("등록된 참조 데이터가 없습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("참조 이미지 (\(dog.referenceImageIdList.count)장)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(dog.referenceImageIdList, id: \.self) { imageId in
                                if let image = DogPhotoStore.loadImage(id: imageId) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    if let firstEmbedding = dog.referenceEmbeddingsList.first {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("참조 벡터 (총 \(dog.referenceEmbeddingsList.count)개)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(vectorString(from: firstEmbedding))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
    }
    
    private func vectorString(from embedding: [Float]) -> String {
        let count = embedding.count
        let prefix = embedding.prefix(10).map { String(format: "%.2f", $0) }.joined(separator: ", ")
        return "[\(prefix)...] (\(count)d)"
    }

    private func detailCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var createdAtDisplayText: String {
        guard let createdAt = dog.createdAt else {
            return "등록일 정보 없음"
        }
        return DateFormatter.dogDetailFormatter.string(from: createdAt)
    }


}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension DateFormatter {
    static let dogDetailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    let controller = PersistenceController.preview
    let context = controller.container.viewContext
    let previewDog: Dog = {
        let dog = Dog(context: context)
        dog.name = "Preview"
        dog.breed = "Retriever"
        dog.createdAt = Date()
        dog.aiDescription = "밝은 갈색 털에 부드러운 눈을 가진 친구예요."
        dog.aiEmbedding = Data(repeating: 1, count: 32)
        return dog
    }()

    return NavigationStack {
        DogDetailView(dog: previewDog)
    }
    .environment(\.managedObjectContext, context)
}
