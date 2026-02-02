import SwiftData
import Foundation

@Model
final class Tag: @unchecked Sendable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    // Many-to-many with notes
    var notes: [Note]? = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
}
