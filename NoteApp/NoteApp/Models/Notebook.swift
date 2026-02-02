import SwiftData
import Foundation

@Model
final class Notebook: @unchecked Sendable {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Hierarchical relationships (parent/children)
    var parent: Notebook? = nil
    @Relationship(deleteRule: .cascade, inverse: \Notebook.parent)
    var children: [Notebook]? = []

    // One-to-many with notes
    @Relationship(deleteRule: .cascade, inverse: \Note.notebook)
    var notes: [Note]? = []

    init(name: String, parent: Notebook? = nil) {
        self.name = name
        self.parent = parent
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
