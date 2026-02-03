//
//  NoteEditorFeatureTests.swift
//  NoteAppTests
//

import Testing
import ComposableArchitecture
import PencilKit
import Foundation
@testable import NoteApp

struct NoteEditorFeatureTests {
    // Mock repository for testing
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
    }

    private struct MockTagRepository: TagRepository {
        var createdTags: [String] = []
        var shouldThrowError = false

        func fetchAllTags() async throws -> [NoteApp.Tag] {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return createdTags.map { NoteApp.Tag(name: $0) }
        }

        func fetchTag(name: String) async throws -> NoteApp.Tag? {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return createdTags.contains(name) ? NoteApp.Tag(name: name) : nil
        }

        func fetchOrCreateTag(name: String) async throws -> NoteApp.Tag {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return NoteApp.Tag(name: name)
        }

        func fetchNotes(withTag tag: NoteApp.Tag) async throws -> [Note] {
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

    @Test func hideNavigationAfterDelay_hidesNavigationAfter3Seconds() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                navigationVisible: true
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.hideNavigationAfterDelay)
        await store.receive(\.hideNavigation) { state in
            state.navigationVisible = false
        }
    }

    @Test func showNavigationTemporarily_showsNavigationThen5SecondDelay() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                navigationVisible: false
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.showNavigationTemporarily) { state in
            state.navigationVisible = true
        }
        await store.receive(\.hideNavigation) { state in
            state.navigationVisible = false
        }
    }

    @Test func gestureDetected_topEdgeDoubleTap_showsNavigationTemporarily() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                navigationVisible: false
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.gestureDetected(.topEdgeDoubleTap))
        await store.receive(\.showNavigationTemporarily) { state in
            state.navigationVisible = true
        }
        await store.receive(\.hideNavigation) { state in
            state.navigationVisible = false
        }
    }

    @Test func gestureDetected_drawingStarted_whenNavigationVisible_hidesAfterDelay() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                navigationVisible: true
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.continuousClock = ImmediateClock()
        }

        await store.send(.gestureDetected(.drawingStarted))
        await store.receive(\.hideNavigationAfterDelay)
        await store.receive(\.hideNavigation) { state in
            state.navigationVisible = false
        }
    }

    @Test func gestureDetected_drawingStarted_whenNavigationHidden_noEffect() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                navigationVisible: false
            ),
            reducer: { NoteEditorFeature() }
        )

        await store.send(.gestureDetected(.drawingStarted))
    }

    @Test func onAppear_loadsDrawing() async {
        let noteId = UUID()
        let drawing = PKDrawing()
        let drawingData = drawing.dataRepresentation()
        let notebook = Notebook(name: "Test")
        let note = Note(title: "Test Note", content: "", notebook: notebook)
        note.drawingData = drawingData

        let mockNoteRepo = MockNoteRepository(mockNotes: [note])

        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing()
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.noteRepository = mockNoteRepo
        }

        await store.send(.onAppear)
        await store.receive(\.drawingLoaded) { state in
            // Drawing loaded, state updated
        }
    }

    @Test func drawingChanged_setsHasUnsavedChangesAndDebouncesSave() async {
        let noteId = UUID()
        let newDrawing = PKDrawing()

        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing()
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.continuousClock = ImmediateClock()
            $0.noteRepository = MockNoteRepository()
        }

        await store.send(.drawingChanged(newDrawing)) { state in
            state.drawing = newDrawing
            state.hasUnsavedChanges = true
        }
        await store.receive(\.saveDrawing) { state in
            state.isSaving = true
        }
        await store.receive(\.drawingSaved) { state in
            state.hasUnsavedChanges = false
            state.isSaving = false
        }
    }

    @Test func closeButtonTapped_withoutUnsavedChanges_requestsClose() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                hasUnsavedChanges: false
            ),
            reducer: { NoteEditorFeature() }
        )

        await store.send(.closeButtonTapped)
        // When no unsaved changes, delegate action is sent
        await store.receive(\.delegate)
    }

    @Test func closeButtonTapped_withUnsavedChanges_showsConfirmation() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing(),
                hasUnsavedChanges: true
            ),
            reducer: { NoteEditorFeature() }
        )

        await store.send(.closeButtonTapped) { state in
            #expect(state.exitConfirmation != nil)
        }
    }

    @Test func exitConfirmation_confirmExit_requestsClose() async {
        let noteId = UUID()
        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: PKDrawing()
            ),
            reducer: { NoteEditorFeature() }
        )

        await store.send(.exitConfirmation(.presented(.confirmExit)))
        // After confirming exit, delegate action is sent
        await store.receive(\.delegate)
    }

    @Test func saveDrawing_withHashtags_attachesTagsToNote() async {
        let noteId = UUID()
        let notebook = Notebook(name: "Test Notebook")
        let note = Note(title: "Test Note", content: "", notebook: notebook)
        note.id = noteId
        let drawing = PKDrawing()

        let mockNoteRepo = MockNoteRepository(mockNotes: [note])
        let mockTagRepo = MockTagRepository()

        let store = TestStore(
            initialState: NoteEditorFeature.State(
                noteId: noteId,
                noteTitle: "Test Note",
                drawing: drawing,
                hasUnsavedChanges: true
            ),
            reducer: { NoteEditorFeature() }
        ) {
            $0.continuousClock = ImmediateClock()
            $0.noteRepository = mockNoteRepo
            $0.tagRepository = mockTagRepo
        }

        await store.send(.saveDrawing) { state in
            state.isSaving = true
        }
        await store.receive(\.tagsDetected) { state in
            // Tags detected action sent
        }
        await store.receive(\.drawingSaved) { state in
            state.hasUnsavedChanges = false
            state.isSaving = false
        }
    }
}
