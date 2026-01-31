import XCTest
import SwiftData
@testable import NoteApp

final class RepositoryTests: XCTestCase {
    var modelContext: ModelContext!
    var notebookRepo: SwiftDataNotebookRepository!
    var noteRepo: SwiftDataNoteRepository!
    var tagRepo: SwiftDataTagRepository!

    override func setUp() {
        super.setUp()

        // Create in-memory test container
        let schema = Schema([Notebook.self, Note.self, Tag.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try! ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        modelContext = ModelContext(container)

        // Initialize repositories
        notebookRepo = SwiftDataNotebookRepository(modelContext: modelContext)
        noteRepo = SwiftDataNoteRepository(modelContext: modelContext)
        tagRepo = SwiftDataTagRepository(modelContext: modelContext)
    }

    override func tearDown() {
        super.tearDown()
        modelContext = nil
        notebookRepo = nil
        noteRepo = nil
        tagRepo = nil
    }

    // MARK: - Notebook Repository Tests

    func testCreateNotebook() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "Test Notebook", parent: nil)

        XCTAssertEqual(notebook.name, "Test Notebook")
        XCTAssertNil(notebook.parent)
    }

    func testCreateNotebookWithEmptyName() async throws {
        do {
            _ = try await notebookRepo.createNotebook(name: "", parent: nil)
            XCTFail("Expected invalidName error")
        } catch NotebookRepositoryError.invalidName {
            // Expected
        }
    }

    func testCreateNotebookWithWhitespaceName() async throws {
        do {
            _ = try await notebookRepo.createNotebook(name: "   ", parent: nil)
            XCTFail("Expected invalidName error")
        } catch NotebookRepositoryError.invalidName {
            // Expected
        }
    }

    func testFetchAllNotebooks() async throws {
        let notebook1 = try await notebookRepo.createNotebook(name: "Notebook 1", parent: nil)
        let notebook2 = try await notebookRepo.createNotebook(name: "Notebook 2", parent: nil)

        let notebooks = try await notebookRepo.fetchAllNotebooks()

        XCTAssertEqual(notebooks.count, 2)
        XCTAssertTrue(notebooks.contains { $0.id == notebook1.id })
        XCTAssertTrue(notebooks.contains { $0.id == notebook2.id })
    }

    func testFetchNotebookById() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "Test Notebook", parent: nil)

        let fetched = try await notebookRepo.fetchNotebook(id: notebook.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, notebook.id)
        XCTAssertEqual(fetched?.name, "Test Notebook")
    }

    func testFetchRootNotebooks() async throws {
        let root = try await notebookRepo.createNotebook(name: "Root", parent: nil)
        let child = try await notebookRepo.createNotebook(name: "Child", parent: root)

        let rootNotebooks = try await notebookRepo.fetchRootNotebooks()

        XCTAssertEqual(rootNotebooks.count, 1)
        XCTAssertEqual(rootNotebooks.first?.id, root.id)
    }

    func testFetchChildrenOfNotebook() async throws {
        let parent = try await notebookRepo.createNotebook(name: "Parent", parent: nil)
        let child1 = try await notebookRepo.createNotebook(name: "Child 1", parent: parent)
        let child2 = try await notebookRepo.createNotebook(name: "Child 2", parent: parent)

        let children = try await notebookRepo.fetchChildren(of: parent)

        XCTAssertEqual(children.count, 2)
        XCTAssertTrue(children.contains { $0.id == child1.id })
        XCTAssertTrue(children.contains { $0.id == child2.id })
    }

    func testUpdateNotebook() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "Original", parent: nil)
        let originalUpdatedAt = notebook.updatedAt

        // Add a small delay to ensure timestamps differ
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        notebook.name = "Updated"
        try await notebookRepo.updateNotebook(notebook)

        let fetched = try await notebookRepo.fetchNotebook(id: notebook.id)
        XCTAssertEqual(fetched?.name, "Updated")
        XCTAssertTrue(fetched!.updatedAt > originalUpdatedAt)
    }

    func testDeleteNotebook() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "To Delete", parent: nil)

        try await notebookRepo.deleteNotebook(id: notebook.id)

        let fetched = try await notebookRepo.fetchNotebook(id: notebook.id)
        XCTAssertNil(fetched)
    }

    // MARK: - Note Repository Tests

    func testCreateNote() async throws {
        let note = try await noteRepo.createNote(title: "Test Note", content: "Content", notebook: nil)

        XCTAssertEqual(note.title, "Test Note")
        XCTAssertEqual(note.content, "Content")
        XCTAssertNil(note.notebook)
    }

    func testCreateNoteWithEmptyTitle() async throws {
        do {
            _ = try await noteRepo.createNote(title: "", content: "Content", notebook: nil)
            XCTFail("Expected invalidTitle error")
        } catch NoteRepositoryError.invalidTitle {
            // Expected
        }
    }

    func testCreateNoteWithWhitespaceTitle() async throws {
        do {
            _ = try await noteRepo.createNote(title: "   ", content: "Content", notebook: nil)
            XCTFail("Expected invalidTitle error")
        } catch NoteRepositoryError.invalidTitle {
            // Expected
        }
    }

    func testCreateNoteInNotebook() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "Test", parent: nil)
        let note = try await noteRepo.createNote(title: "Note", content: "Content", notebook: notebook)

        XCTAssertEqual(note.notebook?.id, notebook.id)
    }

    func testFetchAllNotes() async throws {
        let note1 = try await noteRepo.createNote(title: "Note 1", content: "C1", notebook: nil)
        let note2 = try await noteRepo.createNote(title: "Note 2", content: "C2", notebook: nil)

        let notes = try await noteRepo.fetchAllNotes()

        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.contains { $0.id == note1.id })
        XCTAssertTrue(notes.contains { $0.id == note2.id })
    }

    func testFetchNoteById() async throws {
        let note = try await noteRepo.createNote(title: "Test Note", content: "Content", notebook: nil)

        let fetched = try await noteRepo.fetchNote(id: note.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, note.id)
        XCTAssertEqual(fetched?.title, "Test Note")
    }

    func testFetchNotesInNotebook() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "Test", parent: nil)
        let note1 = try await noteRepo.createNote(title: "Note 1", content: "C1", notebook: notebook)
        let note2 = try await noteRepo.createNote(title: "Note 2", content: "C2", notebook: notebook)
        let otherNote = try await noteRepo.createNote(title: "Other", content: "C3", notebook: nil)

        let notes = try await noteRepo.fetchNotes(in: notebook)

        XCTAssertEqual(notes.count, 2)
        XCTAssertTrue(notes.contains { $0.id == note1.id })
        XCTAssertTrue(notes.contains { $0.id == note2.id })
        XCTAssertFalse(notes.contains { $0.id == otherNote.id })
    }

    func testSearchNotes() async throws {
        let note1 = try await noteRepo.createNote(title: "Swift Tutorial", content: "Learn Swift", notebook: nil)
        let note2 = try await noteRepo.createNote(title: "Python Guide", content: "Learn Swift too", notebook: nil)
        let note3 = try await noteRepo.createNote(title: "Ruby Basics", content: "Different topic", notebook: nil)

        let results = try await noteRepo.searchNotes(query: "Swift")

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.id == note1.id })
        XCTAssertTrue(results.contains { $0.id == note2.id })
        XCTAssertFalse(results.contains { $0.id == note3.id })
    }

    func testUpdateNote() async throws {
        let note = try await noteRepo.createNote(title: "Original", content: "Content", notebook: nil)
        let originalUpdatedAt = note.updatedAt

        // Add a small delay to ensure timestamps differ
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        note.title = "Updated"
        try await noteRepo.updateNote(note)

        let fetched = try await noteRepo.fetchNote(id: note.id)
        XCTAssertEqual(fetched?.title, "Updated")
        XCTAssertTrue(fetched!.updatedAt > originalUpdatedAt)
    }

    func testDeleteNote() async throws {
        let note = try await noteRepo.createNote(title: "To Delete", content: "Content", notebook: nil)

        try await noteRepo.deleteNote(id: note.id)

        let fetched = try await noteRepo.fetchNote(id: note.id)
        XCTAssertNil(fetched)
    }

    // MARK: - Cascade Delete Tests

    func testCascadeDeleteNotebook() async throws {
        let notebook = try await notebookRepo.createNotebook(name: "Parent", parent: nil)
        _ = try await notebookRepo.createNotebook(name: "Child", parent: notebook)
        _ = try await noteRepo.createNote(title: "Note", content: "Content", notebook: notebook)

        try await notebookRepo.deleteNotebook(id: notebook.id)

        // After deleting parent, children and notes should be deleted (cascade rule)
        let fetchedNotebook = try await notebookRepo.fetchNotebook(id: notebook.id)
        XCTAssertNil(fetchedNotebook)
    }
}
