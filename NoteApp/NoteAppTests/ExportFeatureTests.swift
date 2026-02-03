//
//  ExportFeatureTests.swift
//  NoteAppTests
//

import Testing
import ComposableArchitecture
import Foundation
import PencilKit
@testable import NoteApp

struct ExportFeatureTests {
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
            return mockNotes
        }

        func fetchNote(id: UUID) async throws -> Note? {
            if shouldThrowError {
                throw NSError(domain: "", code: -1)
            }
            return mockNotes.first(where: { $0.id == id })
        }

        func createNote(title: String, content: String, notebook: Notebook?) async throws -> Note {
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

    @Test func exportButtonTapped_withValidNote_returnsExportURL() async {
        // Create a note with drawing data
        let drawing = PKDrawing()
        let drawingData = drawing.dataRepresentation()
        let note = Note(title: "Test Note")
        note.drawingData = drawingData

        var mockRepo = MockNoteRepository(mockNotes: [note])
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [note.id],
                exportFormat: .pdf,
                isExporting: false
            ),
            reducer: { ExportFeature() }
        ) {
            $0.noteRepository = mockRepo
        }

        await store.send(.exportButtonTapped) { state in
            state.isExporting = true
        }

        // Receive the export completed action
        await store.receive(\.exportCompleted) { state in
            state.isExporting = false
            #expect(state.shareSheet != nil)
        }
    }

    @Test func exportButtonTapped_withMissingDrawing_returnsFailed() async {
        // Create a note without drawing data
        let note = Note(title: "Test Note without Drawing")
        note.drawingData = nil

        let mockRepo = MockNoteRepository(mockNotes: [note])
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [note.id],
                exportFormat: .pdf,
                isExporting: false
            ),
            reducer: { ExportFeature() }
        ) {
            $0.noteRepository = mockRepo
        }

        await store.send(.exportButtonTapped) { state in
            state.isExporting = true
        }

        // Receive the export failed action
        await store.receive(\.exportFailed) { state in
            state.isExporting = false
        }
    }

    @Test func exportButtonTapped_withMissingNote_returnsFailed() async {
        let nonexistentNoteId = UUID()
        let mockRepo = MockNoteRepository(mockNotes: [])
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [nonexistentNoteId],
                exportFormat: .pdf,
                isExporting: false
            ),
            reducer: { ExportFeature() }
        ) {
            $0.noteRepository = mockRepo
        }

        await store.send(.exportButtonTapped) { state in
            state.isExporting = true
        }

        // Receive the export failed action
        await store.receive(\.exportFailed) { state in
            state.isExporting = false
        }
    }

    @Test func exportCompleted_showsShareSheet() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [UUID()],
                exportFormat: .pdf,
                isExporting: true
            ),
            reducer: { ExportFeature() }
        )

        await store.send(.exportCompleted(tempURL)) { state in
            state.isExporting = false
            #expect(state.shareSheet?.url == tempURL)
        }
    }

    @Test func exportFailed_setsIsExportingToFalse() async {
        let errorMessage = "Export failed due to error"
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [UUID()],
                exportFormat: .pdf,
                isExporting: true
            ),
            reducer: { ExportFeature() }
        )

        await store.send(.exportFailed(errorMessage)) { state in
            state.isExporting = false
        }
    }

    @Test func imageExportFormat_returnsImageFile() async {
        // Create a note with drawing data
        let drawing = PKDrawing()
        let drawingData = drawing.dataRepresentation()
        let note = Note(title: "Image Export Test")
        note.drawingData = drawingData

        let mockRepo = MockNoteRepository(mockNotes: [note])
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [note.id],
                exportFormat: .image,
                isExporting: false
            ),
            reducer: { ExportFeature() }
        ) {
            $0.noteRepository = mockRepo
        }

        await store.send(.exportButtonTapped) { state in
            state.isExporting = true
        }

        await store.receive(\.exportCompleted) { state in
            state.isExporting = false
            #expect(state.shareSheet?.url.lastPathComponent.hasSuffix(".png") ?? false)
        }
    }

    @Test func multipleNotesExport_returnsFolder() async {
        // Create multiple notes with drawing data
        let drawing = PKDrawing()
        let drawingData = drawing.dataRepresentation()

        let note1 = Note(title: "Note 1")
        note1.drawingData = drawingData

        let note2 = Note(title: "Note 2")
        note2.drawingData = drawingData

        let mockRepo = MockNoteRepository(mockNotes: [note1, note2])
        let store = TestStore(
            initialState: ExportFeature.State(
                noteIds: [note1.id, note2.id],
                exportFormat: .pdf,
                isExporting: false
            ),
            reducer: { ExportFeature() }
        ) {
            $0.noteRepository = mockRepo
        }

        await store.send(.exportButtonTapped) { state in
            state.isExporting = true
        }

        await store.receive(\.exportCompleted) { state in
            state.isExporting = false
            #expect(state.shareSheet != nil)
        }
    }
}
