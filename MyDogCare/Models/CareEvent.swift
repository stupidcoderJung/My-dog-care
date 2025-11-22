import Foundation
import SwiftData

enum CareCategory: String, Codable, CaseIterable, Identifiable {
    case vet
    case vaccine
    case weight
    case grooming
    case medication
    case symptom
    case other

    var id: String { rawValue }
}

@Model
final class CareEvent {
    var id: UUID
    var dogId: UUID
    var date: Date
    var category: CareCategory
    var title: String
    var value: Double?
    var notes: String?
    var isSynced: Bool
    var createdAt: Date

    init(id: UUID = UUID(), dogId: UUID, date: Date = Date(), category: CareCategory, title: String, value: Double? = nil, notes: String? = nil, isSynced: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.dogId = dogId
        self.date = date
        self.category = category
        self.title = title
        self.value = value
        self.notes = notes
        self.isSynced = isSynced
        self.createdAt = createdAt
    }
}
