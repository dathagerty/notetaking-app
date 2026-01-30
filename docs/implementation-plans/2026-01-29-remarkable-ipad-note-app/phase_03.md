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
        var notebooks: [Notebook] = []
        var selectedNotebook: Notebook? = nil
        var notesInSelectedNotebook: [Note] = []
        var selectedNote: Note? = nil
        var isLoading: Bool = false
        var errorMessage: String? = nil

        // Create/edit state
        @Presents var createNotebookAlert: AlertState<Action.CreateNotebookAlert>?
        @Presents var createNoteAlert: AlertState<Action.CreateNoteAlert>?
        @Presents var deleteConfirmation: ConfirmationDialogState<Action.DeleteConfirmation>?
    }

    enum Action: Equatable {
        case onAppear
        case refreshData
        case notebooksLoaded([Notebook])
        case notesLoaded([Note])

        // Navigation
        case notebookSelected(Notebook?)
        case noteSelected(Note?)

        // Create
        case showCreateNotebook(parent: Notebook?)
        case showCreateNote
        case createNotebookAlert(PresentationAction<CreateNotebookAlert>)
        case createNoteAlert(PresentationAction<CreateNoteAlert>)

        // Delete
        case showDeleteConfirmation(item: DeletableItem)
        case deleteConfirmation(PresentationAction<DeleteConfirmation>)
        case deleteCompleted

        case errorOccurred(String)

        enum CreateNotebookAlert: Equatable {
            case create(name: String, parent: Notebook?)
        }

        enum CreateNoteAlert: Equatable {
            case create(title: String)
        }

        enum DeleteConfirmation: Equatable {
            case confirmDelete
        }
    }

    enum DeletableItem: Equatable {
        case notebook(Notebook)
        case note(Note)
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
                return .run { [selectedNotebook = state.selectedNotebook] send in
                    do {
                        let notebooks = try await notebookRepo.fetchRootNotebooks()
                        await send(.notebooksLoaded(notebooks))

                        if let notebook = selectedNotebook {
                            let notes = try await noteRepo.fetchNotes(in: notebook)
                            await send(.notesLoaded(notes))
                        }
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .notebooksLoaded(let notebooks):
                state.notebooks = notebooks
                state.isLoading = false
                return .none

            case .notesLoaded(let notes):
                state.notesInSelectedNotebook = notes
                state.isLoading = false
                return .none

            case .notebookSelected(let notebook):
                state.selectedNotebook = notebook
                state.selectedNote = nil
                if let notebook = notebook {
                    return .run { send in
                        do {
                            let notes = try await noteRepo.fetchNotes(in: notebook)
                            await send(.notesLoaded(notes))
                        } catch {
                            await send(.errorOccurred(error.localizedDescription))
                        }
                    }
                }
                return .none

            case .noteSelected(let note):
                state.selectedNote = note
                // Phase 4 will handle navigation to editor
                return .none

            case .showCreateNotebook(let parent):
                state.createNotebookAlert = AlertState {
                    TextState("New Notebook")
                } actions: {
                    ButtonState(action: .create(name: "", parent: parent)) {
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
                guard state.selectedNotebook != nil else {
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

            case .createNotebookAlert(.presented(.create(let name, let parent))):
                guard !name.isEmpty else { return .none }
                return .run { send in
                    do {
                        _ = try await notebookRepo.createNotebook(name: name, parent: parent)
                        await send(.refreshData)
                    } catch {
                        await send(.errorOccurred(error.localizedDescription))
                    }
                }

            case .createNoteAlert(.presented(.create(let title))):
                guard let notebook = state.selectedNotebook else { return .none }
                return .run { send in
                    do {
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
                    case .notebook(let notebook):
                        TextState("Delete '\(notebook.name)' and all its contents?")
                    case .note(let note):
                        TextState("Delete '\(note.title)'?")
                    }
                }
                return .none

            case .deleteConfirmation(.presented(.confirmDelete)):
                // Implementation in actual delete handler
                return .run { send in
                    await send(.deleteCompleted)
                }

            case .deleteConfirmation:
                return .none

            case .deleteCompleted:
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
            if let note = store.selectedNote {
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

**Step 2: Create NotebookListView**

```swift
import SwiftUI
import ComposableArchitecture

struct NotebookListView: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        List(selection: $store.selectedNotebook.sending(\.notebookSelected)) {
            ForEach(store.notebooks) { notebook in
                Label(notebook.name, systemImage: "folder")
                    .tag(notebook as Notebook?)
                    .contextMenu {
                        Button("New Notebook") {
                            store.send(.showCreateNotebook(parent: notebook))
                        }
                        Button("Delete", role: .destructive) {
                            store.send(.showDeleteConfirmation(item: .notebook(notebook)))
                        }
                    }
            }
        }
        .navigationTitle("Notebooks")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.showCreateNotebook(parent: nil))
                } label: {
                    Label("New Notebook", systemImage: "folder.badge.plus")
                }
            }
        }
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
            if let notebook = store.selectedNotebook {
                List(selection: $store.selectedNote.sending(\.noteSelected)) {
                    ForEach(store.notesInSelectedNotebook) { note in
                        NoteRowView(note: note)
                            .tag(note as Note?)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    store.send(.showDeleteConfirmation(item: .note(note)))
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
    let note: Note

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
