import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""

    // PKDrawing serialized as binary Data
    // External storage prevents memory bloat (iOS 18 issue)
    @Attribute(.externalStorage)
    var drawingData: Data? = nil

    // Searchable text from handwriting recognition (Phase 6+)
    var searchableText: String? = nil

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationships
    var notebook: Notebook? = nil

    // Many-to-many with tags
    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    var tags: [Tag]? = []

    init(title: String = "", content: String = "", notebook: Notebook? = nil) {
        self.title = title
        self.content = content
        self.notebook = notebook
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
