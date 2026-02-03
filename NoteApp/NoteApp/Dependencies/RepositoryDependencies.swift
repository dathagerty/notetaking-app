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
        // Use in-memory SwiftData context from ModelContextKey.testValue
        @Dependency(\.modelContext) var modelContext
        return SwiftDataNoteRepository(modelContext: modelContext)
    }
}

enum NotebookRepositoryKey: DependencyKey {
    static var liveValue: any NotebookRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataNotebookRepository(modelContext: modelContext)
    }

    static var testValue: any NotebookRepository {
        // Use in-memory SwiftData context from ModelContextKey.testValue
        @Dependency(\.modelContext) var modelContext
        return SwiftDataNotebookRepository(modelContext: modelContext)
    }
}

enum TagRepositoryKey: DependencyKey {
    static var liveValue: any TagRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataTagRepository(modelContext: modelContext)
    }

    static var testValue: any TagRepository {
        // Use in-memory SwiftData context from ModelContextKey.testValue
        @Dependency(\.modelContext) var modelContext
        return SwiftDataTagRepository(modelContext: modelContext)
    }
}

// MARK: - ModelContext Dependency

/// A sendable wrapper for ModelContext to use with Composable Architecture
struct SendableModelContext: @unchecked Sendable {
    let context: ModelContext

    init(_ context: ModelContext) {
        self.context = context
    }
}

enum ModelContextKey: DependencyKey {
    static var liveValue: SendableModelContext {
        fatalError("ModelContext must be provided by app initialization")
    }

    static var testValue: SendableModelContext {
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
            return SendableModelContext(ModelContext(container))
        } catch {
            fatalError("Failed to create test ModelContainer: \(error)")
        }
    }
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    var modelContext: ModelContext {
        get { self[ModelContextKey.self].context }
        set { self[ModelContextKey.self] = SendableModelContext(newValue) }
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
