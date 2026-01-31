//
//  LibraryFeatureTests.swift
//  NoteAppTests
//

import Testing
import ComposableArchitecture
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

    private struct MockNoteRepository: NoteRepository {
        var mockNotes: [Note] = []
        var shouldThrowError = false

        func fetchNotes(in notebook: Notebook) async throws -> [Note] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes
        }

        func fetchNote(id: UUID) async throws -> Note? {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes.first(where: { $0.id == id })
        }

        func createNote(title: String, content: String, notebook: Notebook) async throws -> Note {
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

        func deleteNote(id: UUID) async throws {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
        }
    }

    @Test func onAppear_loadsRootNotebooks() async {
        let notebook = Notebook(name: "Test Notebook")
        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
        }

        await store.send(.onAppear)
        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded) { notebooks in
            #expect(notebooks.count == 1)
            #expect(notebooks.first?.name == "Test Notebook")
        }
    }

    @Test func notebookSelected_loadsNotesAndBreadcrumb() async {
        let parentNotebook = Notebook(name: "Parent")
        let childNotebook = Notebook(name: "Child", parent: parentNotebook)
        let note = Note(title: "Test Note", content: "Content", notebook: childNotebook)

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [parentNotebook, childNotebook])
        let mockNoteRepo = MockNoteRepository(mockNotes: [note])

        let store = TestStore(
            initialState: LibraryFeature.State(notebooks: [
                NotebookViewModel(from: parentNotebook),
                NotebookViewModel(from: childNotebook)
            ]),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
        }

        let childId = childNotebook.id
        await store.send(.notebookSelected(childId)) { state in
            state.selectedNotebookId = childId
            state.selectedNoteId = nil
        }

        // Should receive breadcrumb path update and notes loaded
        await store.receive(\.breadcrumbPathUpdated) { path in
            #expect(path.count == 2)
        }

        await store.receive(\.notesLoaded) { notes in
            #expect(notes.count == 1)
            #expect(notes.first?.title == "Test Note")
        }
    }

    @Test func noteSelected_updatesSelectedNoteId() async {
        let note = Note(title: "Test Note", content: "Content", notebook: Notebook())
        let noteId = note.id

        let store = TestStore(
            initialState: LibraryFeature.State(
                notes: [NotebookViewModel(from: Notebook())]
            ),
            reducer: { LibraryFeature() }
        )

        await store.send(.noteSelected(noteId)) { state in
            state.selectedNoteId = noteId
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

        let store = TestStore(
            initialState: LibraryFeature.State(
                createNotebookSheet: LibraryFeature.CreateNotebookSheetState(
                    notebookName: "New Notebook",
                    parentId: nil
                )
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
        }

        await store.send(.createNotebookSheet(.presented(.createButtonTapped))) { state in
            state.createNotebookSheet = nil
        }

        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func createNotebookSheet_rejectsEmptyName() async {
        let store = TestStore(
            initialState: LibraryFeature.State(
                createNotebookSheet: LibraryFeature.CreateNotebookSheetState(
                    notebookName: "   ",
                    parentId: nil
                )
            ),
            reducer: { LibraryFeature() }
        )

        await store.send(.createNotebookSheet(.presented(.createButtonTapped))) { state in
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
        let notebookId = UUID()
        let notebook = Notebook(name: "Test")
        notebook.id = notebookId

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                selectedNotebookId: notebookId,
                createNoteSheet: LibraryFeature.CreateNoteSheetState(noteTitle: "New Note")
            ),
            reducer: { LibraryFeature() }
        ) {
            $0.notebookRepository = mockNotebookRepo
            $0.noteRepository = mockNoteRepo
        }

        await store.send(.createNoteSheet(.presented(.createButtonTapped))) { state in
            state.createNoteSheet = nil
        }

        await store.receive(\.refreshData)
        await store.receive(\.notebooksLoaded)
    }

    @Test func deleteConfirmation_deletesNotebook() async {
        let notebookId = UUID()
        let notebook = Notebook(name: "To Delete")
        notebook.id = notebookId

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository()

        let store = TestStore(
            initialState: LibraryFeature.State(
                notebooks: [NotebookViewModel(from: notebook)],
                itemPendingDeletion: .notebook(notebookId),
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
        let noteId = UUID()
        let notebook = Notebook(name: "Test")
        let note = Note(title: "To Delete", content: "", notebook: notebook)
        note.id = noteId

        let mockNotebookRepo = MockNotebookRepository(mockNotebooks: [notebook])
        let mockNoteRepo = MockNoteRepository(mockNotes: [note])

        let store = TestStore(
            initialState: LibraryFeature.State(
                notes: [NotebookViewModel(from: Notebook())],
                itemPendingDeletion: .note(noteId),
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
}
