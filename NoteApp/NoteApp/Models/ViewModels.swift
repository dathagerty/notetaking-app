import Foundation

/// Lightweight value type for displaying notebooks in lists
/// Required because SwiftData @Model classes don't conform to Equatable
struct NotebookViewModel: Equatable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let childCount: Int
    let noteCount: Int

    init(from notebook: Notebook) {
        self.id = notebook.id
        self.name = notebook.name
        self.createdAt = notebook.createdAt
        self.updatedAt = notebook.updatedAt
        self.childCount = notebook.children?.count ?? 0
        self.noteCount = notebook.notes?.count ?? 0
    }
}

/// Lightweight value type for displaying notes in lists
/// Required because SwiftData @Model classes don't conform to Equatable
struct NoteViewModel: Equatable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let hasDrawing: Bool
    let tagNames: [String]

    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.hasDrawing = note.drawingData != nil
        self.tagNames = note.tags?.map { $0.name } ?? []
    }
}

/// Lightweight value type for displaying tags
struct TagViewModel: Equatable, Identifiable {
    let id: UUID
    let name: String

    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
    }
}
