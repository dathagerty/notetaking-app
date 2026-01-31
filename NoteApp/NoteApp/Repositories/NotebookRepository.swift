import Foundation
import SwiftData

protocol NotebookRepository: Sendable {
    func fetchAllNotebooks() async throws -> [Notebook]
    func fetchNotebook(id: UUID) async throws -> Notebook?
    func fetchRootNotebooks() async throws -> [Notebook]
    func fetchChildren(of notebook: Notebook) async throws -> [Notebook]
    func createNotebook(name: String, parent: Notebook?) async throws -> Notebook
    func updateNotebook(_ notebook: Notebook) async throws
    func deleteNotebook(id: UUID) async throws
}

actor SwiftDataNotebookRepository: NotebookRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllNotebooks() async throws -> [Notebook] {
        let descriptor = FetchDescriptor<Notebook>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchNotebook(id: UUID) async throws -> Notebook? {
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchRootNotebooks() async throws -> [Notebook] {
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.parent == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchChildren(of notebook: Notebook) async throws -> [Notebook] {
        let parentId = notebook.id
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.parent?.id == parentId },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createNotebook(name: String, parent: Notebook?) async throws -> Notebook {
        let notebook = Notebook(name: name, parent: parent)
        modelContext.insert(notebook)

        // iOS 18 workaround: Append from parent side instead of setting child.parent
        if let parent = parent {
            if #available(iOS 18.0, *) {
                parent.children?.append(notebook)
            }
        }

        try modelContext.save()
        return notebook
    }

    func updateNotebook(_ notebook: Notebook) async throws {
        notebook.updatedAt = Date()
        try modelContext.save()
    }

    func deleteNotebook(id: UUID) async throws {
        if let notebook = try await fetchNotebook(id: id) {
            modelContext.delete(notebook)
            try modelContext.save()
        }
    }
}
