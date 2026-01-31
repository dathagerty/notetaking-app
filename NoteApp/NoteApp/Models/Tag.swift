import SwiftData
import Foundation

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    // Many-to-many with notes
    var notes: [Note]? = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
