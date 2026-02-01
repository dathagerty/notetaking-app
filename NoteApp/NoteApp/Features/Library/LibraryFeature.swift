import ComposableArchitecture
import Foundation
import PencilKit

// FCIS: Functional Core (TCA state management) for notebooks and notes navigation
struct LibraryFeature: Reducer {
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

        // Create/edit state - use sheets for text input instead of alerts
        var createNotebookSheet: CreateNotebookSheetState?
        var createNoteSheet: CreateNoteSheetState?
        var deleteConfirmation: ConfirmationDialogState<DeleteConfirmationAction>?

        // Note editor state
        @Presents var noteEditor: NoteEditorFeature.State?

        // Computed properties
        var selectedNotebook: NotebookViewModel? {
            notebooks.first { $0.id == selectedNotebookId }
        }

        var selectedNote: NoteViewModel? {
            notes.first { $0.id == selectedNoteId }
        }
    }

    struct CreateNotebookSheetState: Equatable {
        var notebookName: String = ""
        var parentId: UUID?
    }

    struct CreateNoteSheetState: Equatable {
        var noteTitle: String = ""
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
        case breadcrumbPathUpdated([NotebookViewModel])

        // Create
        case showCreateNotebook(parentId: UUID?)
        case showCreateNote
        case createNotebookSheet(PresentationAction<CreateNotebookSheetAction>)
        case createNoteSheet(PresentationAction<CreateNoteSheetAction>)

        // Delete
        case showDeleteConfirmation(item: DeletableItem)
        case deleteConfirmation(PresentationAction<DeleteConfirmationAction>)
        case deleteCompleted

        // Note editor
        case noteEditor(PresentationAction<NoteEditorFeature.Action>)
        case editorStateCreated(NoteEditorFeature.State)

        case errorOccurred(String)
    }

    enum CreateNotebookSheetAction: Equatable {
        case createButtonTapped
        case notebookNameChanged(String)
    }

    enum CreateNoteSheetAction: Equatable {
        case createButtonTapped
        case noteTitleChanged(String)
    }

    enum DeleteConfirmationAction: Equatable {
        case confirmDelete
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

                            // Build breadcrumb path by traversing parent relationships
                            var path: [Notebook] = [notebook]
                            var current = notebook
                            while let parent = current.parent {
                                path.insert(parent, at: 0)
                                current = parent
                            }
                            let pathViewModels = path.map { NotebookViewModel(from: $0) }

                            let notes = try await noteRepo.fetchNotes(in: notebook)
                            let noteViewModels = notes.map { NoteViewModel(from: $0) }

                            // Send both breadcrumb path and notes
                            await send(.breadcrumbPathUpdated(pathViewModels))
                            await send(.notesLoaded(noteViewModels))
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }
                } else {
                    // When deselecting, clear the breadcrumb path
                    state.notebookPath = []
                    return .none
                }

            case .noteSelected(let noteId):
                state.selectedNoteId = noteId
                state.noteEditor = nil // Clear previous editor state
                if let noteId = noteId {
                    return .run { send in
                        do {
                            let note = try await noteRepo.fetchNote(id: noteId)
                            guard let note = note else { return }
                            // Create editor state and send it
                            let editorState = NoteEditorFeature.State(
                                note: note,
                                drawing: PKDrawing()
                            )
                            await send(.editorStateCreated(editorState))
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }
                }
                return .none

            case .editorStateCreated(let editorState):
                state.noteEditor = editorState
                return .none

            case .navigateToBreadcrumb(let notebookId):
                return .send(.notebookSelected(notebookId))

            case .breadcrumbPathUpdated(let path):
                state.notebookPath = path
                return .none

            case .showCreateNotebook(let parentId):
                state.createNotebookSheet = CreateNotebookSheetState(parentId: parentId)
                return .none

            case .showCreateNote:
                guard state.selectedNotebookId != nil else {
                    state.errorMessage = "Select a notebook first"
                    return .none
                }
                state.createNoteSheet = CreateNoteSheetState()
                return .none

            case .createNotebookSheet(.presented(.createButtonTapped)):
                guard let sheet = state.createNotebookSheet else { return .none }
                let name = sheet.notebookName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else {
                    state.errorMessage = "Notebook name cannot be empty"
                    return .none
                }
                let parentId = sheet.parentId
                state.createNotebookSheet = nil
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

            case .createNotebookSheet(.presented(.notebookNameChanged(let name))):
                state.createNotebookSheet?.notebookName = name
                return .none

            case .createNoteSheet(.presented(.createButtonTapped)):
                guard let sheet = state.createNoteSheet else { return .none }
                let title = sheet.noteTitle.trimmingCharacters(in: .whitespaces)
                guard let notebookId = state.selectedNotebookId else { return .none }
                state.createNoteSheet = nil
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

            case .createNoteSheet(.presented(.noteTitleChanged(let title))):
                state.createNoteSheet?.noteTitle = title
                return .none

            case .createNotebookSheet, .createNoteSheet:
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

            case .noteEditor:
                return .none
            }
        }
        .ifLet(\.$noteEditor, action: \.noteEditor) {
            NoteEditorFeature()
        }
    }
}
