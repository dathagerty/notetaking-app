import ComposableArchitecture
import Foundation
import PencilKit

// Types used by LibraryFeature - defined outside to avoid circular references
struct CreateNotebookSheetState: Equatable, Identifiable {
    var id: UUID = UUID()
    var notebookName: String = ""
    var parentId: UUID?
}

struct CreateNoteSheetState: Equatable, Identifiable {
    var id: UUID = UUID()
    var noteTitle: String = ""
}

enum DeletableItem: Equatable, Sendable {
    case notebook(UUID)
    case note(UUID)
}

@CasePathable
enum LibraryDeleteAlert: Equatable, Sendable {
    case confirmDelete
}

@CasePathable
enum CreateNotebookSheetAction: Equatable, Sendable {
    case createButtonTapped
    case notebookNameChanged(String)
}

@CasePathable
enum CreateNoteSheetAction: Equatable, Sendable {
    case createButtonTapped
    case noteTitleChanged(String)
}

// FCIS: Functional Core (TCA state management) for notebooks and notes navigation
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

        // Create/edit state - use sheets for text input instead of alerts
        var createNotebookSheet: CreateNotebookSheetState?
        var createNoteSheet: CreateNoteSheetState?
        @Presents var deleteConfirmation: ConfirmationDialogState<LibraryDeleteAlert>?

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

    @CasePathable
    enum Action {
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
        case createNotebookSheet(CreateNotebookSheetAction)
        case createNoteSheet(CreateNoteSheetAction)

        // Delete
        case showDeleteConfirmation(item: DeletableItem)
        case deleteConfirmation(PresentationAction<LibraryDeleteAlert>)
        case deleteCompleted

        // Note editor
        case noteEditor(PresentationAction<NoteEditorFeature.Action>)

        case errorOccurred(String)
    }

    @Dependency(\.notebookRepository) var notebookRepo
    @Dependency(\.noteRepository) var noteRepo

    var body: some Reducer<State, Action> {
        Reduce { state, action -> Effect<Action> in
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
                if let noteId = noteId,
                   let note = state.notes.first(where: { $0.id == noteId }) {
                    state.noteEditor = NoteEditorFeature.State(
                        noteId: noteId,
                        noteTitle: note.title,
                        drawing: PKDrawing()
                    )
                } else {
                    state.noteEditor = nil
                }
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

            case .createNotebookSheet(.createButtonTapped):
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
                        var parent: Notebook? = nil
                        if let parentId = parentId {
                            parent = try await notebookRepo.fetchNotebook(id: parentId)
                        }
                        _ = try await notebookRepo.createNotebook(name: name, parent: parent)
                        await send(.refreshData)
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .createNotebookSheet(.notebookNameChanged(let name)):
                state.createNotebookSheet?.notebookName = name
                return .none

            case .createNoteSheet(.createButtonTapped):
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

            case .createNoteSheet(.noteTitleChanged(let title)):
                state.createNoteSheet?.noteTitle = title
                return .none

            case .showDeleteConfirmation(let item):
                state.itemPendingDeletion = item
                let messageText: String
                switch item {
                case .notebook(let notebookId):
                    if let notebook = state.notebooks.first(where: { $0.id == notebookId }) {
                        messageText = "Delete '\(notebook.name)' and all its contents?"
                    } else {
                        messageText = "Delete this notebook and all its contents?"
                    }
                case .note(let noteId):
                    if let note = state.notes.first(where: { $0.id == noteId }) {
                        messageText = "Delete '\(note.title)'?"
                    } else {
                        messageText = "Delete this note?"
                    }
                }
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
                    TextState(messageText)
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

            case .deleteConfirmation(.dismiss):
                state.itemPendingDeletion = nil
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

            case .noteEditor(.presented(.delegate(.closeRequested))):
                state.noteEditor = nil
                state.selectedNoteId = nil
                return .none

            case .noteEditor:
                return .none
            }
        }
        .ifLet(\.$deleteConfirmation, action: \.deleteConfirmation)
        .ifLet(\.$noteEditor, action: \.noteEditor) {
            NoteEditorFeature()
        }
    }
}
