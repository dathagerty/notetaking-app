//
//  LibraryFeatureTests.swift
//  NoteAppTests
//

import Testing
import ComposableArchitecture
import Foundation
import PencilKit
@testable import NoteApp

struct LibraryFeatureTests {
    // Mock repositories for testing
    private struct MockNotebookRepository: NotebookRepository {
        var mockNotebooks: [Notebook] = []
        var mockNotes: [Note] = []
        var shouldThrowError = false

        func fetchAllNotebooks() async throws -> [Notebook] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotebooks
        }

        func fetchNotebook(id: UUID) async throws -> Notebook? {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotebooks.first(where: { $0.id == id })
        }

        func fetchRootNotebooks() async throws -> [Notebook] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotebooks.filter { $0.parent == nil }
        }

        func fetchChildren(of notebook: Notebook) async throws -> [Notebook] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotebooks.filter { $0.parent?.id == notebook.id }
        }

        func createNotebook(name: String, parent: Notebook?) async throws -> Notebook {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            let notebook = Notebook(name: name, parent: parent)
            return notebook
        }

        func updateNotebook(_ notebook: Notebook) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }

        func deleteNotebook(id: UUID) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }
    }

    private struct MockTagRepository: TagRepository {
        var mockTags: [NoteApp.Tag] = []
        var shouldThrowError = false

        func fetchAllTags() async throws -> [NoteApp.Tag] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockTags
        }

        func fetchTag(name: String) async throws -> NoteApp.Tag? {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockTags.first(where: { $0.name == name })
        }

        func fetchOrCreateTag(name: String) async throws -> NoteApp.Tag {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            if let tag = mockTags.first(where: { $0.name == name }) {
                return tag
            }
            let tag = NoteApp.Tag(name: name)
            return tag
        }

        func fetchNotes(withTag tag: NoteApp.Tag) async throws -> [NoteApp.Note] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return []
        }

        func deleteTag(name: String) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }
    }

    private struct MockNoteRepository: NoteRepository {
        var mockNotes: [Note] = []
        var shouldThrowError = false

        func fetchAllNotes() async throws -> [Note] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes
        }

        func fetchNotes(in notebook: Notebook) async throws -> [Note] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes.filter { $0.notebook?.id == notebook.id }
        }

        func fetchNote(id: UUID) async throws -> Note? {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes.first(where: { $0.id == id })
        }

        func createNote(title: String, content: String, notebook: Notebook?) async throws -> Note {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            let note = Note(title: title, content: content, notebook: notebook)
            return note
        }

        func updateNote(_ note: Note) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }

        func updateDrawingData(noteId: UUID, drawingData: Data) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }

        func deleteNote(id: UUID) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }

        func searchNotes(query: String) async throws -> [Note] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes.filter { note in
                note.title.contains(query) || note.content.contains(query)
            }
        }

        mutating func markNoteAsUpdated(_ note: Note) {
            if let index = mockNotes.firstIndex(where: { $0.id == note.id }) {
                mockNotes[index] = note
            }
        }
    }

    @Test func onAppear_loadsRootNotebooks() async {
        let notebook = Notebook(name: "Test Notebook")
        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository()
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.onAppear)
        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded) { state in
            #expect(state.notebooks.count == 1)
            #expect(state.notebooks.first?.name == "Test Notebook")
        }
    }

    @Test func notebookSelected_loadsNotesAndBreadcrumb() async {
        let parentNotebook = Notebook(name: "Parent")
        let childNotebook = Notebook(name: "Child", parent: parentNotebook)
        let note = Note(title: "Test Note", content: "Content", notebook: childNotebook)

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [parentNotebook, childNotebook])
        let mockNoteRepo = MockNoteRepository(mockNotes: [note])
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(notebooks: [
                NotebookViewModel(from: parentNotebook),
                NotebookViewModel(from: childNotebook)
            ]),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        let childId = childNotebook.id
        await store.send(.notebookSelected(childId)) { state in
            state.selectedNotebookId = childId
            state.selectedNoteId = nil
        }

        // Should receive breadcrumb path update and notes loaded
        await store.receive(\.breadcrumbPathUpdated) { state in
            #expect(state.notebookPath.count == 2)
        }

        await store.receive(\.notesLoaded) { state in
            #expect(state.notes.count == 1)
            #expect(state.notes.first?.title == "Test Note")
        }
    }

    @Test func noteSelected_updatesSelectedNoteId() async {
        let note = Note(title: "Test Note", content: "Content", notebook: Notebook(name: "Test"))
        let noteId = note.id

        let store = TestStore(
            initialState: LibraryFeature.State(
                notes: [NoteViewModel(from: note)]
            ),
            reducer: { LibraryFeature() }
        )

        await store.send(.noteSelected(noteId)) { state in
            state.selectedNoteId = noteId
            // Verify noteEditor state is properly initialized when note is selected
            #expect(state.noteEditor != nil)
            #expect(state.noteEditor?.noteId == noteId)
            #expect(state.noteEditor?.noteTitle == "Test Note")
        }
    }

    @Test func showCreateNotebook_presentsSheet() async {
        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        )

        let parentId = UUID()
        await store.send(.showCreateNotebook(parentId: parentId)) { state in
            #expect(state.createNotebookSheet != nil)
            #expect(state.createNotebookSheet?.parentId == parentId)
        }
    }

    @Test func createNotebookSheet_createsNotebookWithName() async {
        let mockNotebookRepo = MockNotebookRepository()
        let mockNoteRepo = MockNoteRepository()
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                createNotebookSheet: CreateNotebookSheetState(
                    notebookName: "New Notebook",
                    parentId: nil
                )
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.createNotebookSheet(.createButtonTapped)) { state in
            state.createNotebookSheet = nil
        }

        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func createNotebookSheet_rejectsEmptyName() async {
        let store = TestStore(
            initialState: LibraryFeature.State(
                createNotebookSheet: CreateNotebookSheetState(
                    notebookName: "   ",
                    parentId: nil
                )
            ),
            reducer: { LibraryFeature() }
        )

        await store.send(.createNotebookSheet(.createButtonTapped)) { state in
            #expect(state.errorMessage == "Notebook name cannot be empty")
        }
    }

    @Test func showCreateNote_requiresNotebookSelection() async {
        let store = TestStore(
            initialState: LibraryFeature.State(selectedNotebookId: nil),
            reducer: { LibraryFeature() }
        )

        await store.send(.showCreateNote) { state in
            #expect(state.errorMessage == "Select a notebook first")
            #expect(state.createNoteSheet == nil)
        }
    }

    @Test func showCreateNote_presentsSheetWithSelectedNotebook() async {
        let notebookId = UUID()
        let store = TestStore(
            initialState: LibraryFeature.State(selectedNotebookId: notebookId),
            reducer: { LibraryFeature() }
        )

        await store.send(.showCreateNote) { state in
            #expect(state.createNoteSheet != nil)
        }
    }

    @Test func createNoteSheet_createsNoteWithTitle() async {
        let notebook = Notebook(name: "Test")
        let notebookId = notebook.id

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository()
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                selectedNotebookId: notebookId,
                createNoteSheet: CreateNoteSheetState(noteTitle: "New Note")
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.createNoteSheet(.createButtonTapped)) { state in
            state.createNoteSheet = nil
        }

        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func deleteConfirmation_deletesNotebook() async {
        let notebook = Notebook(name: "To Delete")
        let notebookId = notebook.id

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository()
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                notebooks: [NotebookViewModel(from: notebook)],
                itemPendingDeletion: DeletableItem.notebook(notebookId),
                deleteConfirmation: ConfirmationDialogState(
                    title: { TextState("Delete?") },
                    actions: {
                        ButtonState(role: .destructive, action: .confirmDelete) {
                            TextState("Delete")
                        }
                    },
                    message: { TextState("Delete this notebook?") }
                )
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.deleteConfirmation(.presented(.confirmDelete))) { state in
            // State updates happen in refresh
        }

        await store.receive(\.deleteCompleted) { state in
            state.itemPendingDeletion = nil
        }

        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func deleteConfirmation_deletesNote() async {
        let notebook = Notebook(name: "Test")
        let note = Note(title: "To Delete", content: "", notebook: notebook)
        let noteId = note.id

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository(mockNotes: [note])
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                notes: [NoteViewModel(from: note)],
                itemPendingDeletion: DeletableItem.note(noteId),
                deleteConfirmation: ConfirmationDialogState(
                    title: { TextState("Delete?") },
                    actions: {
                        ButtonState(role: .destructive, action: .confirmDelete) {
                            TextState("Delete")
                        }
                    },
                    message: { TextState("Delete this note?") }
                )
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.deleteConfirmation(.presented(.confirmDelete))) { state in
            // State updates happen in refresh
        }

        await store.receive(\.deleteCompleted) { state in
            state.itemPendingDeletion = nil
        }

        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func errorOccurred_setsErrorMessage() async {
        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        )

        let errorMessage = "Test error"
        await store.send(.errorOccurred(errorMessage)) { state in
            state.errorMessage = errorMessage
            state.isLoading = false
        }
    }

    @Test func navigationToBreadcrumb_selectsNotebook() async {
        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        )

        let notebookId = UUID()
        await store.send(.navigateToBreadcrumb(notebookId))
        await store.receive(\.notebookSelected)
    }

    @Test func convertHandwriting_extractsTextAndUpdatesNote() async {
        let notebook = Notebook(name: "Test")
        let note = Note(title: "Test Note", content: "", notebook: notebook)

        // Create a simple drawing for testing
        let drawing = PKDrawing()
        note.drawingData = drawing.dataRepresentation()
        let noteId = note.id

        var mockNoteRepo = MockNoteRepository(mockNotes: [note])
        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                notes: [NoteViewModel(from: note)]
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.convertHandwriting(noteId: noteId)) { state in
            state.convertingNoteId = noteId
        }

        // Handwriting conversion completes (may be empty for blank drawing)
        await store.receive(\.handwritingConverted) { state in
            state.convertingNoteId = nil
        }

        // After conversion, refreshData is sent
        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func convertHandwriting_failsWhenNoteNotFound() async {
        let mockNoteRepo = MockNoteRepository(mockNotes: [])
        let mockNotebookRepo = MockNotebookRepository()
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        let missingNoteId = UUID()
        await store.send(.convertHandwriting(noteId: missingNoteId)) { state in
            state.convertingNoteId = missingNoteId
        }

        await store.receive(\.conversionFailed) { state in
            state.convertingNoteId = nil
            #expect(state.errorMessage?.contains("Note not found") ?? false)
        }
    }

    @Test func convertHandwriting_failsWhenNoteHasNoDrawing() async {
        let notebook = Notebook(name: "Test")
        let note = Note(title: "Test Note", content: "", notebook: notebook)
        let noteId = note.id

        let mockNoteRepo = MockNoteRepository(mockNotes: [note])
        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.convertHandwriting(noteId: noteId)) { state in
            state.convertingNoteId = noteId
        }

        await store.receive(\.conversionFailed) { state in
            state.convertingNoteId = nil
            #expect(state.errorMessage?.contains("no drawing") ?? false)
        }
    }
}
