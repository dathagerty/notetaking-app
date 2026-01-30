# reMarkable iPad Note App Implementation Plan - Phase 3

**Goal:** Implement notebook/note browsing with hierarchical structure and TCA-driven navigation

**Architecture:** LibraryFeature in TCA managing notebook/note state, NavigationSplitView for iPad-optimized three-column layout, repository integration via dependencies

**Tech Stack:** SwiftUI NavigationSplitView, TCA @Reducer, @Query for reactive data

**Scope:** Phase 3 of 8 from original design

**Codebase verified:** 2026-01-29 (Phase 1-2 must complete first)

---

## Phase 3: Library Feature with Navigation

### Done When
- Can create nested notebooks and notes
- Navigate hierarchy with breadcrumbs
- Delete notebooks/notes with confirmation
- Navigation to note editor triggers (editor is placeholder)
- All CRUD operations persist via repositories

---

<!-- START_TASK_1 -->
### Task 1: Create LibraryFeature with TCA

**Files:**
- Create: `NoteApp/Features/Library/LibraryFeature.swift`

**Step 1: Create LibraryFeature structure**

```swift
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
```

Commit:
```bash
git add NoteApp/Features/Library/LibraryFeature.swift
git commit -m "feat: create LibraryFeature with TCA state management

- Define LibraryFeature.State for notebooks, notes, selection
- Implement actions for CRUD operations and navigation
- Integrate with repositories via TCA dependencies
- Add create/delete confirmation dialogs
- Placeholder for Phase 4 note editor navigation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create LibraryView with NavigationSplitView

**Files:**
- Create: `NoteApp/Features/Library/LibraryView.swift`
- Create: `NoteApp/Features/Library/NotebookListView.swift`
- Create: `NoteApp/Features/Library/NoteListView.swift`
- Create: `NoteApp/Features/Library/NoteRowView.swift`

**Step 1: Create LibraryView**

```swift
import SwiftUI
import ComposableArchitecture

struct LibraryView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        NavigationSplitView {
            // Sidebar: Notebooks
            NotebookListView(store: store)
        } content: {
            // Content: Notes in selected notebook
            NoteListView(store: store)
        } detail: {
            // Detail: Selected note (placeholder until Phase 4)
            if let noteId = store.selectedNoteId,
               let note = store.notes.first(where: { $0.id == noteId }) {
                Text("Note: \(note.title)")
                    .font(.title)
                Text("Editor coming in Phase 4")
                    .foregroundColor(.gray)
            } else {
                Text("Select a note")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .alert($store.scope(state: \.createNotebookAlert, action: \.createNotebookAlert))
        .alert($store.scope(state: \.createNoteAlert, action: \.createNoteAlert))
        .confirmationDialog($store.scope(state: \.deleteConfirmation, action: \.deleteConfirmation))
    }
}
```

**Step 2: Create NotebookListView with Breadcrumb Navigation**

```swift
import SwiftUI
import ComposableArchitecture

struct NotebookListView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumb navigation
            if !store.notebookPath.isEmpty {
                BreadcrumbView(
                    path: store.notebookPath,
                    onSelect: { notebookId in
                        store.send(.navigateToBreadcrumb(notebookId))
                    }
                )
            }

            List(selection: $store.selectedNotebookId.sending(\.notebookSelected)) {
                ForEach(store.notebooks) { notebook in
                    Label(notebook.name, systemImage: "folder")
                        .tag(notebook.id as UUID?)
                        .contextMenu {
                            Button("New Notebook") {
                                store.send(.showCreateNotebook(parentId: notebook.id))
                            }
                            Button("Delete", role: .destructive) {
                                store.send(.showDeleteConfirmation(item: .notebook(notebook.id)))
                            }
                        }
                }
            }
        }
        .navigationTitle("Notebooks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.showCreateNotebook(parentId: nil))
                } label: {
                    Label("New Notebook", systemImage: "folder.badge.plus")
                }
            }
        }
    }
}

// Breadcrumb component for hierarchical navigation
struct BreadcrumbView: View {
    let path: [NotebookViewModel]
    let onSelect: (UUID?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button("All") {
                    onSelect(nil)
                }

                ForEach(path) { notebook in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(notebook.name) {
                        onSelect(notebook.id)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
        .background(Color(.systemGray6))
    }
}
```

**Step 3: Create NoteListView**

```swift
import SwiftUI
import ComposableArchitecture

struct NoteListView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        Group {
            if let notebookId = store.selectedNotebookId,
               let notebook = store.notebooks.first(where: { $0.id == notebookId }) {
                List(selection: $store.selectedNoteId.sending(\.noteSelected)) {
                    ForEach(store.notes) { note in
                        NoteRowView(note: note)
                            .tag(note.id as UUID?)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    store.send(.showDeleteConfirmation(item: .note(note.id)))
                                }
                            }
                    }
                }
                .navigationTitle(notebook.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.showCreateNote)
                        } label: {
                            Label("New Note", systemImage: "note.text.badge.plus")
                        }
                    }
                }
            } else {
                Text("Select a notebook")
                    .foregroundColor(.gray)
            }
        }
    }
}
```

**Step 4: Create NoteRowView**

```swift
import SwiftUI

struct NoteRowView: View {
    let note: NoteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(.headline)

            Text(note.createdAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

Commit:
```bash
git add NoteApp/Features/Library/
git commit -m "feat: create Library UI with NavigationSplitView

- Add LibraryView with three-column iPad layout
- Add NotebookListView with hierarchical notebook tree
- Add NoteListView showing notes in selected notebook
- Add NoteRowView with title and timestamp
- Include context menus for create/delete operations
- Placeholder detail view until Phase 4 editor

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Integrate LibraryFeature into AppFeature

**Files:**
- Modify: `NoteApp/App/AppFeature.swift`
- Modify: `NoteApp/App/AppView.swift`

**Step 1: Update AppFeature to include LibraryFeature**

```swift
import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var focusModeEnabled: Bool = false
        var lastSyncDate: Date?
        var isOnline: Bool = true

        // Phase 3: Library feature
        var library: LibraryFeature.State = .init()
    }

    enum Action: Equatable {
        case onAppear
        case focusModeToggled
        case networkStatusChanged(Bool)

        // Phase 3: Library actions
        case library(LibraryFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }

        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .focusModeToggled:
                state.focusModeEnabled.toggle()
                return .none

            case .networkStatusChanged(let isOnline):
                state.isOnline = isOnline
                return .none

            case .library:
                return .none
            }
        }
    }
}
```

**Step 2: Update AppView to show LibraryView**

```swift
import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        LibraryView(
            store: store.scope(
                state: \.library,
                action: \.library
            )
        )
        .onAppear {
            store.send(.onAppear)
        }
    }
}

#Preview {
    AppView(
        store: Store(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )
    )
}
```

Commit:
```bash
git add NoteApp/App/AppFeature.swift NoteApp/App/AppView.swift
git commit -m "feat: integrate LibraryFeature into App root

- Add LibraryFeature.State to AppFeature
- Compose LibraryFeature reducer with Scope
- Replace placeholder AppView with LibraryView
- Phase 3 complete: functional notebook/note browsing

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_3 -->

---

## Phase 3 Complete

**Verification:**
- ✓ LibraryFeature manages notebooks/notes state with TCA
- ✓ NavigationSplitView provides iPad-optimized layout
- ✓ Can create/delete notebooks and notes
- ✓ Hierarchical notebook structure with context menus
- ✓ Repository integration via TCA dependencies
- ✓ Placeholder detail view ready for Phase 4 editor

**Next Phase:** Phase 4 - PencilKit Note Editor
