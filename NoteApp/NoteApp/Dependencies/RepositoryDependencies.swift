import Foundation
import SwiftData
import ComposableArchitecture

// MARK: - Dependency Keys

enum NoteRepositoryKey: DependencyKey {
    static var liveValue: any NoteRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataNoteRepository(modelContext: modelContext)
    }

    static var testValue: any NoteRepository {
        fatalError("NoteRepository not implemented for tests")
    }
}

enum NotebookRepositoryKey: DependencyKey {
    static var liveValue: any NotebookRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataNotebookRepository(modelContext: modelContext)
    }

    static var testValue: any NotebookRepository {
        fatalError("NotebookRepository not implemented for tests")
    }
}

enum TagRepositoryKey: DependencyKey {
    static var liveValue: any TagRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataTagRepository(modelContext: modelContext)
    }

    static var testValue: any TagRepository {
        fatalError("TagRepository not implemented for tests")
    }
}

// MARK: - ModelContext Dependency

enum ModelContextKey: DependencyKey {
    static var liveValue: ModelContext {
        fatalError("ModelContext must be provided by app initialization")
    }

    static var testValue: ModelContext {
        let schema = Schema([Notebook.self, Note.self, Tag.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            return ModelContext(container)
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    var modelContext: ModelContext {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
    }

    var noteRepository: any NoteRepository {
        get { self[NoteRepositoryKey.self] }
        set { self[NoteRepositoryKey.self] = newValue }
    }

    var notebookRepository: any NotebookRepository {
        get { self[NotebookRepositoryKey.self] }
        set { self[NotebookRepositoryKey.self] = newValue }
    }

    var tagRepository: any TagRepository {
        get { self[TagRepositoryKey.self] }
        set { self[TagRepositoryKey.self] = newValue }
    }
}
