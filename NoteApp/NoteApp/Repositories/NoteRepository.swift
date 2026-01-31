import Foundation
import SwiftData

protocol NoteRepository: Sendable {
    func fetchAllNotes() async throws -> [Note]
    func fetchNote(id: UUID) async throws -> Note?
    func fetchNotes(in notebook: Notebook) async throws -> [Note]
    func createNote(title: String, content: String, notebook: Notebook?) async throws -> Note
    func updateNote(_ note: Note) async throws
    func deleteNote(id: UUID) async throws
    func searchNotes(query: String) async throws -> [Note]
}

actor SwiftDataNoteRepository: NoteRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllNotes() async throws -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchNote(id: UUID) async throws -> Note? {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchNotes(in notebook: Notebook) async throws -> [Note] {
        let notebookId = notebook.id
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.notebook?.id == notebookId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createNote(title: String, content: String, notebook: Notebook?) async throws -> Note {
        let note = Note(title: title, content: content, notebook: notebook)
        modelContext.insert(note)
        try modelContext.save()
        return note
    }

    func updateNote(_ note: Note) async throws {
        note.updatedAt = Date()
        try modelContext.save()
    }

    func deleteNote(id: UUID) async throws {
        if let note = try await fetchNote(id: id) {
            modelContext.delete(note)
            try modelContext.save()
        }
    }

    func searchNotes(query: String) async throws -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.title.contains(query) ||
                (note.content.contains(query)) ||
                (note.searchableText?.contains(query) ?? false)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
