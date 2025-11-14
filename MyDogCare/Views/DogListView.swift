import CoreData
import SwiftUI
import UIKit

struct DogListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Dog.createdAt, ascending: false)],
        animation: .default
    )
    private var dogs: FetchedResults<Dog>

    @State private var isPresentingAddDog = false

    var body: some View {
        List {
            if dogs.isEmpty {
                ContentUnavailableView("등록된 강아지가 없어요", systemImage: "pawprint", description: Text("오른쪽 위의 추가 버튼을 눌러 새 강아지를 등록하세요."))
            } else {
                ForEach(dogs) { dog in
                    DogRowView(dog: dog)
                }
                .onDelete(perform: deleteDogs)
            }
        }
        .navigationTitle("내 강아지")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !dogs.isEmpty {
                    EditButton()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPresentingAddDog = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("강아지 추가")
            }
        }
        .sheet(isPresented: $isPresentingAddDog) {
            NavigationStack {
                AddDogView()
            }
        }
    }

    private func deleteDogs(at offsets: IndexSet) {
        offsets.map { dogs[$0] }.forEach { dog in
            DogPhotoStore.deleteImage(id: dog.photoId)
            viewContext.delete(dog)
        }

        do {
            try viewContext.save()
        } catch {
            // TODO: Surface error to the user if needed.
        }
    }
}

private struct DogRowView: View {
    @ObservedObject var dog: Dog
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemGray5))
                    Image(systemName: "pawprint")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 56, height: 56)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(dog.name ?? "이름 없음")
                    .font(.headline)
                Text(dog.breed ?? "견종 정보 없음")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: dog.objectID) {
            thumbnail = DogPhotoStore.loadImage(id: dog.photoId)
        }
    }
}

#Preview {
    NavigationStack {
        DogListView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
