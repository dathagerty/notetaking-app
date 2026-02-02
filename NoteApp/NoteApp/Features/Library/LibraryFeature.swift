import ComposableArchitecture
import Foundation
import PencilKit
import Vision

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

        // Search and filtering
        var searchQuery: String = ""
        var selectedTags: Set<TagViewModel> = []
        var allTags: [TagViewModel] = []
        var filteredNotes: [NoteViewModel] = []

        // Handwriting conversion progress
        var convertingNoteId: UUID? = nil

        // Export feature
        @Presents var exportFeature: ExportFeature.State?

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

        // Search and filtering
        case searchQueryChanged(String)
        case tagToggled(TagViewModel)
        case tagsLoaded([TagViewModel])
        case applyFilters

        // Manual tag management
        case showManageTagsSheet(noteId: UUID)
        case addTagToNote(noteId: UUID, tagName: String)
        case removeTagFromNote(noteId: UUID, tagName: String)

        // Handwriting conversion
        case convertHandwriting(noteId: UUID)
        case handwritingConverted(noteId: UUID, text: String)
        case conversionFailed(String)

        // Export
        case exportNote(noteId: UUID)
        case exportFeature(PresentationAction<ExportFeature.Action>)

        case errorOccurred(String)
    }

    @Dependency(\.notebookRepository) var notebookRepo
    @Dependency(\.noteRepository) var noteRepo
    @Dependency(\.tagRepository) var tagRepo

    var body: some Reducer<State, Action> {
        Reduce { state, action -> Effect<Action> in
            switch action {
            case .onAppear:
                return .run { send in
                    await send(.refreshData)
                }

            case .refreshData:
                state.isLoading = true
                return .run { send in
                    do {
                        let notebooks = try await notebookRepo.fetchRootNotebooks()
                        let viewModels = notebooks.map { NotebookViewModel(from: $0) }
                        await send(.notebooksLoaded(viewModels))

                        let tags = try await tagRepo.fetchAllTags()
                        let tagViewModels = tags.map { TagViewModel(from: $0) }
                        await send(.tagsLoaded(tagViewModels))

                        await send(.applyFilters)
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
                state.filteredNotes = viewModels
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

                            // Send breadcrumb path and apply filters
                            await send(.breadcrumbPathUpdated(pathViewModels))
                            await send(.applyFilters)
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

            case .searchQueryChanged(let query):
                state.searchQuery = query
                return .send(.applyFilters)

            case .tagToggled(let tag):
                if state.selectedTags.contains(tag) {
                    state.selectedTags.remove(tag)
                } else {
                    state.selectedTags.insert(tag)
                }
                return .send(.applyFilters)

            case .tagsLoaded(let tags):
                state.allTags = tags
                return .none

            case .applyFilters:
                // Extract tag IDs before entering the run effect to avoid actor isolation issues
                let selectedTagIds = Set(state.selectedTags.map { $0.id })
                return .run { [query = state.searchQuery, selectedTagIds, selectedNotebookId = state.selectedNotebookId] send in
                    do {
                        var notes: [Note] = []

                        // Fetch base notes from selected notebook
                        if let notebookId = selectedNotebookId,
                           let notebook = try await notebookRepo.fetchNotebook(id: notebookId) {
                            notes = try await noteRepo.fetchNotes(in: notebook)
                        } else {
                            notes = try await noteRepo.fetchAllNotes()
                        }

                        // Apply search filter
                        if !query.isEmpty {
                            notes = notes.filter { note in
                                note.title.localizedCaseInsensitiveContains(query) ||
                                note.content.localizedCaseInsensitiveContains(query) ||
                                (note.searchableText?.localizedCaseInsensitiveContains(query) ?? false)
                            }
                        }

                        // Apply tag filter (AND logic)
                        if !selectedTagIds.isEmpty {
                            notes = notes.filter { note in
                                guard let noteTags = note.tags else { return false }
                                let noteTagIds = Set(noteTags.map { $0.id })
                                return selectedTagIds.isSubset(of: noteTagIds)
                            }
                        }

                        let viewModels = notes.map { NoteViewModel(from: $0) }
                        await send(.notesLoaded(viewModels))
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .showManageTagsSheet:
                // In a full implementation, this would show a sheet with tag management UI
                // For now, just prepare the UI state (sheet implementation deferred to future PR)
                return .none

            case .addTagToNote(let noteId, let tagName):
                return .run { send in
                    do {
                        if let note = try await noteRepo.fetchNote(id: noteId) {
                            let tag = try await tagRepo.fetchOrCreateTag(name: tagName)
                            if note.tags == nil {
                                note.tags = [tag]
                            } else {
                                note.tags?.append(tag)
                            }
                            try await noteRepo.updateNote(note)
                            await send(.refreshData)
                        }
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .removeTagFromNote(let noteId, let tagName):
                return .run { send in
                    do {
                        if let note = try await noteRepo.fetchNote(id: noteId) {
                            note.tags?.removeAll { $0.name == tagName }
                            try await noteRepo.updateNote(note)
                            await send(.refreshData)
                        }
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .convertHandwriting(let noteId):
                state.convertingNoteId = noteId
                return .run { [noteId] send in
                    do {
                        guard let note = try await noteRepo.fetchNote(id: noteId) else {
                            await send(.conversionFailed("Note not found"))
                            return
                        }

                        guard let drawingData = note.drawingData else {
                            await send(.conversionFailed("Note has no drawing"))
                            return
                        }

                        // Use PKDrawing's native deserialization
                        let drawing = try PKDrawing(data: drawingData)

                        let recognitionService = HandwritingRecognitionService()
                        let text = try await recognitionService.recognizeText(from: drawing)

                        note.searchableText = text
                        try await noteRepo.updateNote(note)

                        await send(.handwritingConverted(noteId: noteId, text: text))
                    } catch {
                        await send(.conversionFailed(error.localizedDescription))
                    }
                }

            case .handwritingConverted:
                state.convertingNoteId = nil
                return .send(.refreshData)

            case .conversionFailed(let error):
                state.convertingNoteId = nil
                state.errorMessage = "Conversion failed: \(error)"
                return .none

            case .exportNote(let noteId):
                state.exportFeature = ExportFeature.State(
                    noteIds: [noteId],
                    exportFormat: .pdf,
                    isExporting: false
                )
                return .none

            case .exportFeature(.presented(.shareSheet(.dismiss))):
                state.exportFeature = nil
                return .none

            case .exportFeature:
                return .none

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
        .ifLet(\.$exportFeature, action: \.exportFeature) {
            ExportFeature()
        }
    }
}
