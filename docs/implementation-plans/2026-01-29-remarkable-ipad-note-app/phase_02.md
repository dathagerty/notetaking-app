# reMarkable iPad Note App Implementation Plan - Phase 2

**Goal:** Define SwiftData models and establish local persistence with iCloud sync

**Architecture:** SwiftData models with NSPersistentCloudKitContainer for automatic CloudKit sync, repository pattern to keep TCA reducers pure

**Tech Stack:**
- SwiftData (iOS 17+)
- CloudKit (Private Database)
- NSPersistentCloudKitContainer
- Repository pattern for data access abstraction

**Scope:** Phase 2 of 8 from original design

**Codebase verified:** 2026-01-29 (Phase 1 must complete first - creates project structure)

---

## Phase 2: Data Models & SwiftData Persistence

### Critical iOS 18 Gotchas (Must Address)

From research, iOS 18 introduced breaking changes:
- Memory explosion on `.count` (use `fetchCount` instead)
- One-to-many relationship setting from child side broken (append from parent)
- External storage loaded unnecessarily (use sparingly)
- ModelActor changes don't refresh views (use @Query in views)

**These will be addressed in implementation tasks.**

---

<!-- START_TASK_1 -->
### Task 1: Enable iCloud Capability

**Files:**
- Modify: `NoteApp.xcodeproj` (via Xcode UI)

**Step 1: Add iCloud capability**

In Xcode:
1. Select NoteApp target
2. Signing & Capabilities tab
3. Click "+ Capability"
4. Select "iCloud"
5. Check "CloudKit"
6. Click "+" next to Containers
7. Create new container: `iCloud.com.remarkable.NoteApp` (or your identifier)

Expected: iCloud capability added, CloudKit container created

**Step 2: Enable Background Modes**

1. Click "+ Capability" again
2. Select "Background Modes"
3. Check "Remote notifications" (required for CloudKit sync)

Expected: Background Modes capability added

**Step 3: Commit capability configuration**

```bash
git add NoteApp.xcodeproj/project.pbxproj NoteApp/NoteApp.entitlements
git commit -m "feat: enable iCloud and Background Modes for CloudKit sync

- Add iCloud capability with CloudKit
- Create CloudKit container iCloud.com.remarkable.NoteApp
- Enable Background Modes for remote notifications
- Required for SwiftData automatic sync

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_1 -->

<!-- START_SUBCOMPONENT_A (tasks 2-4) -->
<!-- START_TASK_2 -->
### Task 2: Create SwiftData Models

**Files:**
- Create: `NoteApp/Models/Notebook.swift`
- Create: `NoteApp/Models/Note.swift`
- Create: `NoteApp/Models/Tag.swift`

**Step 1: Create Notebook model**

Create `NoteApp/Models/Notebook.swift`:

```swift
import SwiftData
import Foundation

@Model
final class Notebook {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Hierarchical relationships (parent/children)
    var parent: Notebook? = nil
    @Relationship(deleteRule: .cascade, inverse: \Notebook.parent)
    var children: [Notebook]? = []

    // One-to-many with notes
    @Relationship(deleteRule: .cascade, inverse: \Note.notebook)
    var notes: [Note]? = []

    init(name: String, parent: Notebook? = nil) {
        self.name = name
        self.parent = parent
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

**Step 2: Create Note model**

Create `NoteApp/Models/Note.swift`:

```swift
import SwiftData
import Foundation

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""

    // PKDrawing serialized as binary Data
    // External storage prevents memory bloat (iOS 18 issue)
    @Attribute(.externalStorage)
    var drawingData: Data? = nil

    // Searchable text from handwriting recognition (Phase 6+)
    var searchableText: String? = nil

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Relationships
    var notebook: Notebook? = nil

    // Many-to-many with tags
    @Relationship(deleteRule: .nullify, inverse: \Tag.notes)
    var tags: [Tag]? = []

    init(title: String = "", content: String = "", notebook: Notebook? = nil) {
        self.title = title
        self.content = content
        self.notebook = notebook
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

**Step 3: Create Tag model**

Create `NoteApp/Models/Tag.swift`:

```swift
import SwiftData
import Foundation

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    // Many-to-many with notes
    var notes: [Note]? = []

    init(name: String) {
        self.name = name
        self.createdAt = Date()
    }
}
```

**Step 4: Build to verify models compile**

Run: Product → Build (Cmd+B)

Expected: Build succeeds, SwiftData macros process correctly

**Step 5: Commit models**

```bash
git add NoteApp/Models/Notebook.swift NoteApp/Models/Note.swift NoteApp/Models/Tag.swift
git commit -m "feat: create SwiftData models with CloudKit-compatible design

- Add Notebook model with hierarchical parent/children relationships
- Add Note model with external storage for drawing data
- Add Tag model for many-to-many note categorization
- All properties have default values (CloudKit requirement)
- All relationships are optional (CloudKit requirement)
- Use @Attribute(.externalStorage) for large binary data

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create View Models for TCA State

**Files:**
- Create: `NoteApp/Models/ViewModels.swift`

**Step 1: Create ViewModels file**

Create `NoteApp/Models/ViewModels.swift`:

```swift
import Foundation

/// Lightweight value type for displaying notebooks in lists
/// Required because SwiftData @Model classes don't conform to Equatable
struct NotebookViewModel: Equatable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let childCount: Int
    let noteCount: Int

    init(from notebook: Notebook) {
        self.id = notebook.id
        self.name = notebook.name
        self.createdAt = notebook.createdAt
        self.updatedAt = notebook.updatedAt
        self.childCount = notebook.children?.count ?? 0
        self.noteCount = notebook.notes?.count ?? 0
    }
}

/// Lightweight value type for displaying notes in lists
/// Required because SwiftData @Model classes don't conform to Equatable
struct NoteViewModel: Equatable, Identifiable {
    let id: UUID
    let title: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let hasDrawing: Bool
    let tagNames: [String]

    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.hasDrawing = note.drawingData != nil
        self.tagNames = note.tags?.map { $0.name } ?? []
    }
}

/// Lightweight value type for displaying tags
struct TagViewModel: Equatable, Identifiable {
    let id: UUID
    let name: String

    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
    }
}
```

**Step 2: Build to verify view models compile**

Run: Product → Build (Cmd+B)

Expected: Build succeeds, view models available for TCA features

**Step 3: Commit view models**

```bash
git add NoteApp/Models/ViewModels.swift
git commit -m "feat: create value-type view models for TCA state

- Add NotebookViewModel as Equatable wrapper for Notebook
- Add NoteViewModel as Equatable wrapper for Note
- Add TagViewModel as Equatable wrapper for Tag
- Enables using models in TCA State which requires Equatable
- View models are lightweight value types safe for TCA

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Configure ModelContainer with CloudKit

**Files:**
- Modify: `NoteApp/NoteAppApp.swift`

**Step 1: Update app entry point with ModelContainer**

Replace contents of `NoteApp/NoteAppApp.swift`:

```swift
import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct NoteAppApp: App {
    let modelContainer: ModelContainer
    let store: StoreOf<AppFeature>

    init() {
        // Configure SwiftData with CloudKit sync
        do {
            let schema = Schema([
                Notebook.self,
                Note.self,
                Tag.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private // Private database for user's personal notes
            )

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Initialize TCA store
            self.store = Store(
                initialState: AppFeature.State(),
                reducer: { AppFeature() }
            )
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .modelContainer(modelContainer)
    }
}
```

**Step 2: Build and run on simulator**

1. Select iPad simulator
2. Product → Run (Cmd+R)

Expected: App launches, ModelContainer initializes successfully

**Step 3: Commit ModelContainer configuration**

```bash
git add NoteApp/NoteAppApp.swift
git commit -m "feat: configure ModelContainer with CloudKit private database

- Initialize SwiftData schema with Notebook, Note, Tag models
- Enable CloudKit sync to private database
- Integrate ModelContainer with SwiftUI app lifecycle
- Maintain TCA Store initialization alongside SwiftData

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_4 -->
<!-- END_SUBCOMPONENT_A -->

<!-- START_SUBCOMPONENT_B (tasks 5-7) -->
<!-- START_TASK_5 -->
### Task 5: Create Repository Protocols

**Files:**
- Create: `NoteApp/Repositories/NoteRepository.swift`
- Create: `NoteApp/Repositories/NotebookRepository.swift`
- Create: `NoteApp/Repositories/TagRepository.swift`

**Step 1: Create NoteRepository protocol**

Create `NoteApp/Repositories/NoteRepository.swift`:

```swift
import Foundation
import SwiftData

protocol NoteRepository: Sendable {
    func fetchAllNotes() async throws -> [Note]
    func fetchNote(id: UUID) async throws -> Note?
    func fetchNotes(in notebook: Notebook) async throws -> [Note]
    func createNote(title: String, content: String, notebook: Notebook?) async throws -> Note
    func updateNote(_ note: Note) async throws
    func deleteNote(id: UUID) async throws
    func searchNotes(query: String) async throws -> [Note]
}

actor SwiftDataNoteRepository: NoteRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllNotes() async throws -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchNote(id: UUID) async throws -> Note? {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchNotes(in notebook: Notebook) async throws -> [Note] {
        let notebookId = notebook.id
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.notebook?.id == notebookId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createNote(title: String, content: String, notebook: Notebook?) async throws -> Note {
        let note = Note(title: title, content: content, notebook: notebook)
        modelContext.insert(note)
        try modelContext.save()
        return note
    }

    func updateNote(_ note: Note) async throws {
        note.updatedAt = Date()
        try modelContext.save()
    }

    func deleteNote(id: UUID) async throws {
        if let note = try await fetchNote(id: id) {
            modelContext.delete(note)
            try modelContext.save()
        }
    }

    func searchNotes(query: String) async throws -> [Note] {
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.title.contains(query) ||
                (note.content.contains(query)) ||
                (note.searchableText?.contains(query) ?? false)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
}
```

**Step 2: Create NotebookRepository protocol**

Create `NoteApp/Repositories/NotebookRepository.swift`:

```swift
import Foundation
import SwiftData

protocol NotebookRepository: Sendable {
    func fetchAllNotebooks() async throws -> [Notebook]
    func fetchNotebook(id: UUID) async throws -> Notebook?
    func fetchRootNotebooks() async throws -> [Notebook]
    func fetchChildren(of notebook: Notebook) async throws -> [Notebook]
    func createNotebook(name: String, parent: Notebook?) async throws -> Notebook
    func updateNotebook(_ notebook: Notebook) async throws
    func deleteNotebook(id: UUID) async throws
}

actor SwiftDataNotebookRepository: NotebookRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllNotebooks() async throws -> [Notebook] {
        let descriptor = FetchDescriptor<Notebook>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchNotebook(id: UUID) async throws -> Notebook? {
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchRootNotebooks() async throws -> [Notebook] {
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.parent == nil },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchChildren(of notebook: Notebook) async throws -> [Notebook] {
        let parentId = notebook.id
        let descriptor = FetchDescriptor<Notebook>(
            predicate: #Predicate { $0.parent?.id == parentId },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func createNotebook(name: String, parent: Notebook?) async throws -> Notebook {
        let notebook = Notebook(name: name, parent: parent)
        modelContext.insert(notebook)

        // iOS 18 workaround: Append from parent side instead of setting child.parent
        if let parent = parent {
            if #available(iOS 18.0, *) {
                parent.children?.append(notebook)
            }
        }

        try modelContext.save()
        return notebook
    }

    func updateNotebook(_ notebook: Notebook) async throws {
        notebook.updatedAt = Date()
        try modelContext.save()
    }

    func deleteNotebook(id: UUID) async throws {
        if let notebook = try await fetchNotebook(id: id) {
            modelContext.delete(notebook)
            try modelContext.save()
        }
    }
}
```

**Step 3: Create TagRepository protocol**

Create `NoteApp/Repositories/TagRepository.swift`:

```swift
import Foundation
import SwiftData

protocol TagRepository: Sendable {
    func fetchAllTags() async throws -> [Tag]
    func fetchTag(name: String) async throws -> Tag?
    func fetchOrCreateTag(name: String) async throws -> Tag
    func fetchNotes(withTag tag: Tag) async throws -> [Note]
    func deleteTag(name: String) async throws
}

actor SwiftDataTagRepository: TagRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAllTags() async throws -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchTag(name: String) async throws -> Tag? {
        let descriptor = FetchDescriptor<Tag>(
            predicate: #Predicate { $0.name == name }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchOrCreateTag(name: String) async throws -> Tag {
        if let existing = try await fetchTag(name: name) {
            return existing
        }

        let tag = Tag(name: name)
        modelContext.insert(tag)
        try modelContext.save()
        return tag
    }

    func fetchNotes(withTag tag: Tag) async throws -> [Note] {
        let tagName = tag.name
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.tags?.contains { $0.name == tagName } ?? false
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func deleteTag(name: String) async throws {
        if let tag = try await fetchTag(name: name) {
            modelContext.delete(tag)
            try modelContext.save()
        }
    }
}
```

**Step 4: Build to verify repositories compile**

Run: Product → Build (Cmd+B)

Expected: Build succeeds

**Step 5: Commit repository protocols**

```bash
git add NoteApp/Repositories/
git commit -m "feat: create repository protocols for data access abstraction

- Add NoteRepository with CRUD and search operations
- Add NotebookRepository with hierarchical query support
- Add TagRepository with fetch-or-create pattern
- Use actor for thread-safe SwiftData access
- Include iOS 18 workaround for parent/child relationships
- Enable TCA reducers to remain pure (no direct ModelContext)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_5 -->

<!-- START_TASK_6 -->
### Task 6: Register Repositories as TCA Dependencies

**Files:**
- Create: `NoteApp/Dependencies/RepositoryDependencies.swift`

**Step 1: Create dependency registration file**

Create `NoteApp/Dependencies/RepositoryDependencies.swift`:

```swift
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
        unimplemented("NoteRepository not implemented for tests")
    }
}

enum NotebookRepositoryKey: DependencyKey {
    static var liveValue: any NotebookRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataNotebookRepository(modelContext: modelContext)
    }

    static var testValue: any NotebookRepository {
        unimplemented("NotebookRepository not implemented for tests")
    }
}

enum TagRepositoryKey: DependencyKey {
    static var liveValue: any TagRepository {
        @Dependency(\.modelContext) var modelContext
        return SwiftDataTagRepository(modelContext: modelContext)
    }

    static var testValue: any TagRepository {
        unimplemented("TagRepository not implemented for tests")
    }
}

// MARK: - ModelContext Dependency

enum ModelContextKey: DependencyKey {
    static var liveValue: ModelContext {
        fatalError("ModelContext must be provided by app initialization")
    }

    static var testValue: ModelContext {
        let schema = Schema([Notebook.self, Note.self, Tag.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try! ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        return ModelContext(container)
    }
}

// MARK: - Dependency Values Extension

extension DependencyValues {
    var modelContext: ModelContext {
        get { self[ModelContextKey.self] }
        set { self[ModelContextKey.self] = newValue }
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
```

**Step 2: Update app initialization to provide ModelContext**

Modify `NoteApp/NoteAppApp.swift` to inject ModelContext:

```swift
import SwiftUI
import SwiftData
import ComposableArchitecture

@main
struct NoteAppApp: App {
    let modelContainer: ModelContainer
    let store: StoreOf<AppFeature>

    init() {
        do {
            let schema = Schema([
                Notebook.self,
                Note.self,
                Tag.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private
            )

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Provide ModelContext to TCA dependency system
            let modelContext = ModelContext(modelContainer)

            self.store = Store(
                initialState: AppFeature.State(),
                reducer: { AppFeature() }
            ) {
                $0.modelContext = modelContext
            }
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .modelContainer(modelContainer)
    }
}
```

**Step 3: Build to verify dependencies resolve**

Run: Product → Build (Cmd+B)

Expected: Build succeeds, dependencies registered

**Step 4: Commit dependency configuration**

```bash
git add NoteApp/Dependencies/RepositoryDependencies.swift NoteApp/NoteAppApp.swift
git commit -m "feat: register repositories as TCA dependencies

- Create dependency keys for all repositories
- Provide ModelContext via TCA dependency system
- Enable test mode with in-memory ModelContainer
- Wire dependencies into Store initialization
- Reducers can now access repositories without direct SwiftData coupling

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_6 -->

<!-- START_TASK_7 -->
### Task 7: Verify Persistence and CloudKit Sync

**Files:**
- No file changes (manual testing)

**Step 1: Create test data on first simulator**

1. Run app on iPad simulator (Simulator A)
2. Manually create test data using SwiftData Preview or debug code:
   - Add temporary button in `AppView.swift` body:

```swift
Button("Create Test Data") {
    Task {
        @Dependency(\.notebookRepository) var notebookRepo
        @Dependency(\.noteRepository) var noteRepo

        let notebook = try await notebookRepo.createNotebook(name: "Test Notebook", parent: nil)
        let note = try await noteRepo.createNote(
            title: "Test Note",
            content: "Testing persistence",
            notebook: notebook
        )
        print("Created notebook: \(notebook.id), note: \(note.id)")
    }
}
```

3. Tap "Create Test Data" button
4. Verify in console: UUID printed for notebook and note

**Step 2: Verify local persistence**

1. Kill app (Cmd+Q in simulator)
2. Relaunch app
3. Add temporary fetch button:

```swift
Button("Fetch Data") {
    Task {
        @Dependency(\.notebookRepository) var notebookRepo
        @Dependency(\.noteRepository) var noteRepo

        let notebooks = try await notebookRepo.fetchAllNotebooks()
        let notes = try await noteRepo.fetchAllNotes()
        print("Fetched \(notebooks.count) notebooks, \(notes.count) notes")
    }
}
```

4. Tap "Fetch Data"

Expected: Console shows same count (data persisted locally)

**Step 3: Test CloudKit sync (requires second simulator or device)**

**NOTE:** CloudKit sync in simulator is unreliable. Real device testing recommended.

If testing on simulators:
1. Ensure both simulators signed into same iCloud account (Settings → iCloud)
2. Simulator A: Create data (already done)
3. Wait 30-60 seconds for sync
4. Simulator B: Launch app, fetch data

Expected: Data appears on Simulator B after CloudKit sync completes

**Alternative verification (CloudKit Dashboard):**
1. Visit https://icloud.developer.apple.com/dashboard
2. Select your app's CloudKit container
3. Navigate to Data → RecordType
4. Verify `CD_Notebook`, `CD_Note`, `CD_Tag` records exist

**Step 4: Remove test buttons from AppView**

Remove temporary "Create Test Data" and "Fetch Data" buttons from `AppView.swift`

**Step 5: Commit Phase 2 completion**

```bash
git add NoteApp/App/AppView.swift
git commit -m "feat: verify Phase 2 data persistence and CloudKit sync

- Tested SwiftData local persistence (data survives app restart)
- Verified CloudKit sync configuration (requires real device for reliable testing)
- Models, repositories, and dependencies fully functional
- Phase 2 complete: ready for Phase 3 (Library UI)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_7 -->
<!-- END_SUBCOMPONENT_B -->

---

## Phase 2 Complete

**Verification Checklist:**
- ✓ iCloud capability enabled with CloudKit container
- ✓ SwiftData models defined (Notebook, Note, Tag)
- ✓ ModelContainer configured with CloudKit private database
- ✓ Repository protocols abstract SwiftData queries
- ✓ Repositories registered as TCA dependencies
- ✓ Local persistence verified (data survives restart)
- ✓ CloudKit sync configuration active (test on real devices)

**Next Phase:** Phase 3 - Library Feature with Navigation (UI for browsing notebooks/notes)
