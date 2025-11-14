import Foundation
import UIKit

enum DogPhotoStore {
    private static let fileManager = FileManager.default
    private static let directoryName = "DogPhotos"
    private static let fileExtension = "jpg"

    private static var directoryURL: URL {
        let baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = baseURL.appendingPathComponent(directoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func saveImage(data: Data, id: String? = nil) throws -> String {
        let filename = (id ?? UUID().uuidString) + "." + fileExtension
        let url = directoryURL.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return filename
    }

    static func loadImage(id: String?) -> UIImage? {
        guard let id, !id.isEmpty else { return nil }
        let url = directoryURL.appendingPathComponent(id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func deleteImage(id: String?) {
        guard let id else { return }
        let url = directoryURL.appendingPathComponent(id)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }
}
