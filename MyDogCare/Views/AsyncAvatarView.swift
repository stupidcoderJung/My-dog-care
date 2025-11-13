import SwiftUI

struct AsyncAvatarView: View {
    let imageURL: URL?

    var body: some View {
        Group {
            if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Image(systemName: "pawprint.fill")
            .resizable()
            .scaledToFit()
            .padding(16)
            .foregroundStyle(.accentColor)
    }
}

#Preview {
    AsyncAvatarView(imageURL: nil)
        .frame(width: 72, height: 72)
}
