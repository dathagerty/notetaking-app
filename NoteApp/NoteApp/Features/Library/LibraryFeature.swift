import ComposableArchitecture
import Foundation

@Reducer
struct LibraryFeature {
    @ObservableState
    struct State: Equatable {
        var notebooks: [NotebookViewModel] = []
        var selectedNotebookId: UUID? = nil
        var notes: [NoteViewModel] = []
        var selectedNoteId: UUID? = nil
        var notebookPath: [NotebookViewModel] = []  // For breadcrumb navigation
        var isLoading: Bool = false
        var errorMessage: String? = nil

        // Delete tracking
        var itemPendingDeletion: DeletableItem? = nil

        // Create/edit state
        @Presents var createNotebookAlert: AlertState<Action.CreateNotebookAlert>?
        @Presents var createNoteAlert: AlertState<Action.CreateNoteAlert>?
        @Presents var deleteConfirmation: ConfirmationDialogState<Action.DeleteConfirmation>?

        // Computed properties
        var selectedNotebook: NotebookViewModel? {
            notebooks.first { $0.id == selectedNotebookId }
        }

        var selectedNote: NoteViewModel? {
            notes.first { $0.id == selectedNoteId }
        }
    }

    enum Action: Equatable {
        case onAppear
        case refreshData
        case notebooksLoaded([NotebookViewModel])
        case notesLoaded([NoteViewModel])

        // Navigation
        case notebookSelected(UUID?)
        case noteSelected(UUID?)
        case navigateToBreadcrumb(UUID?)

        // Create
        case showCreateNotebook(parentId: UUID?)
        case showCreateNote
        case createNotebookAlert(PresentationAction<CreateNotebookAlert>)
        case createNoteAlert(PresentationAction<CreateNoteAlert>)

        // Delete
        case showDeleteConfirmation(item: DeletableItem)
        case deleteConfirmation(PresentationAction<DeleteConfirmation>)
        case deleteCompleted

        case errorOccurred(String)

        enum CreateNotebookAlert: Equatable {
            case create(name: String, parentId: UUID?)
        }

        enum CreateNoteAlert: Equatable {
            case create(title: String)
        }

        enum DeleteConfirmation: Equatable {
            case confirmDelete
        }
    }

    enum DeletableItem: Equatable {
        case notebook(UUID)
        case note(UUID)
    }

    @Dependency(\.notebookRepository) var notebookRepo
    @Dependency(\.noteRepository) var noteRepo

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.refreshData)
                }

            case .refreshData:
                state.isLoading = true
                return .run { [selectedNotebookId = state.selectedNotebookId] send in
                    do {
                        let notebooks = try await notebookRepo.fetchRootNotebooks()
                        let viewModels = notebooks.map { NotebookViewModel(from: $0) }
                        await send(.notebooksLoaded(viewModels))

                        if let notebookId = selectedNotebookId,
                           let notebook = notebooks.first(where: { $0.id == notebookId }) {
                            let notes = try await noteRepo.fetchNotes(in: notebook)
                            let noteViewModels = notes.map { NoteViewModel(from: $0) }
                            await send(.notesLoaded(noteViewModels))
                        }
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .notebooksLoaded(let viewModels):
                state.notebooks = viewModels
                state.isLoading = false
                return .none

            case .notesLoaded(let viewModels):
                state.notes = viewModels
                state.isLoading = false
                return .none

            case .notebookSelected(let notebookId):
                state.selectedNotebookId = notebookId
                state.selectedNoteId = nil
                if let notebookId = notebookId {
                    return .run { send in
                        do {
                            let notebook = try await notebookRepo.fetchNotebook(id: notebookId)
                            guard let notebook = notebook else { return }

                            let notes = try await noteRepo.fetchNotes(in: notebook)
                            let viewModels = notes.map { NoteViewModel(from: $0) }
                            await send(.notesLoaded(viewModels))
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }
                }
                return .none

            case .noteSelected(let noteId):
                state.selectedNoteId = noteId
                // Phase 4 will handle navigation to editor
                return .none

            case .navigateToBreadcrumb(let notebookId):
                return .send(.notebookSelected(notebookId))

            case .showCreateNotebook(let parentId):
                state.createNotebookAlert = AlertState {
                    TextState("New Notebook")
                } actions: {
                    ButtonState(action: .create(name: "", parentId: parentId)) {
                        TextState("Create")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Enter notebook name")
                }
                return .none

            case .showCreateNote:
                guard state.selectedNotebookId != nil else {
                    state.errorMessage = "Select a notebook first"
                    return .none
                }
                state.createNoteAlert = AlertState {
                    TextState("New Note")
                } actions: {
                    ButtonState(action: .create(title: "")) {
                        TextState("Create")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Enter note title")
                }
                return .none

            case .createNotebookAlert(.presented(.create(let name, let parentId))):
                guard !name.isEmpty else { return .none }
                return .run { send in
                    do {
                        let parent = if let parentId = parentId {
                            try await notebookRepo.fetchNotebook(id: parentId)
                        } else {
                            nil
                        }
                        _ = try await notebookRepo.createNotebook(name: name, parent: parent)
                        await send(.refreshData)
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .createNoteAlert(.presented(.create(let title))):
                guard let notebookId = state.selectedNotebookId else { return .none }
                return .run { send in
                    do {
                        let notebook = try await notebookRepo.fetchNotebook(id: notebookId)
                        guard let notebook = notebook else { return }

                        _ = try await noteRepo.createNote(
                            title: title.isEmpty ? "Untitled" : title,
                            content: "",
                            notebook: notebook
                        )
                        await send(.refreshData)
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .createNotebookAlert, .createNoteAlert:
                return .none

            case .showDeleteConfirmation(let item):
                state.itemPendingDeletion = item
                state.deleteConfirmation = ConfirmationDialogState {
                    TextState("Delete?")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("Delete")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    switch item {
                    case .notebook(let notebookId):
                        if let notebook = state.notebooks.first(where: { $0.id == notebookId }) {
                            TextState("Delete '\(notebook.name)' and all its contents?")
                        } else {
                            TextState("Delete this notebook and all its contents?")
                        }
                    case .note(let noteId):
                        if let note = state.notes.first(where: { $0.id == noteId }) {
                            TextState("Delete '\(note.title)'?")
                        } else {
                            TextState("Delete this note?")
                        }
                    }
                }
                return .none

            case .deleteConfirmation(.presented(.confirmDelete)):
                guard let itemToDelete = state.itemPendingDeletion else { return .none }

                return .run { send in
                    do {
                        switch itemToDelete {
                        case .notebook(let notebookId):
                            try await notebookRepo.deleteNotebook(id: notebookId)
                        case .note(let noteId):
                            try await noteRepo.deleteNote(id: noteId)
                        }
                        await send(.deleteCompleted)
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .deleteConfirmation:
                return .none

            case .deleteCompleted:
                state.itemPendingDeletion = nil
                return .run { send in
                    await send(.refreshData)
                }

            case .errorOccurred(let message):
                state.errorMessage = message
                state.isLoading = false
                return .none
            }
        }
        .ifLet(\.$createNotebookAlert, action: \.createNotebookAlert)
        .ifLet(\.$createNoteAlert, action: \.createNoteAlert)
        .ifLet(\.$deleteConfirmation, action: \.deleteConfirmation)
    }
}
