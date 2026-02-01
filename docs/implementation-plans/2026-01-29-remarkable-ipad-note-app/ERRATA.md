# Implementation Plan Errata & Required Fixes

**Date:** 2026-01-29
**Revised:** 2026-01-29 (after technical review)
**Applied:** 2026-01-29 (all corrections integrated into phase files)
**Status:** ✅ All issues corrected and applied to implementation plans

---

## Application Summary

All corrections from this ERRATA have been successfully applied to the implementation plan files:

**Phase 1 (phase_01.md):**
- ✅ Added Dependencies/ folder to directory structure (Minor Issue 3)

**Phase 2 (phase_02.md):**
- ✅ Created ViewModels.swift with NotebookViewModel, NoteViewModel, TagViewModel (Critical Issue 2)
- ✅ Renumbered tasks correctly after insertion

**Phase 3 (phase_03.md):**
- ✅ Updated LibraryFeature to use view models instead of SwiftData models (Critical Issue 2)
- ✅ Changed to UUID-based selection for TCA State Equatable compliance (Critical Issue 2)
- ✅ Added BreadcrumbView component for hierarchical navigation (Important Issue 1)
- ✅ Fixed delete implementation with proper UUID tracking (Important Issue 4)
- ✅ Updated all views (LibraryView, NotebookListView, NoteListView, NoteRowView) to work with view models

**Phase 4 (phase_04.md):**
- ✅ Replaced NSKeyedArchiver/Unarchiver with PKDrawing native serialization (Minor Issue 1)

**Phase 6 (phase_06.md):**
- ✅ Moved tagRepository dependency declaration to reducer level (Important Issue 5)
- ✅ Updated to use modern PKDrawing serialization (Minor Issue 1)
- ✅ Added TagBadgeOverlay showing detected hashtags in editor (Important Issue 2)

**Phase 7 (phase_07.md):**
- ✅ Replaced SSZipArchive with native FileManager.zipItem (Critical Issue 1)
- ✅ Added progress indicator during handwriting conversion (Important Issue 3)
- ✅ Replaced NSKeyedUnarchiver with PKDrawing(data:) in all locations (Minor Issue 1)

**Phase 8 (phase_08.md):**
- ✅ Fixed network monitor async/await with Task wrapper and proper cancellation (Important Issue 6)

**Commit:** b29720b "fix: apply ERRATA corrections to all implementation phases"

---

## Critical Issues (Must Fix Before Implementation)

### Critical 1: Use Native ZIP API Instead of SSZipArchive

**Issue**: Phase 7 imports `ZipArchive` and uses `SSZipArchive` but no SPM dependency is added

**Location**: Phase 7, Task 3 - `ExportFeature.swift`

**Fix**: Use native `FileManager.zipItem(at:to:)` (iOS 16+) instead of third-party dependency

**Corrected code**:
```swift
// Remove: import ZipArchive

// Replace SSZipArchive.createZipFile with:
private func exportMultipleNotes(_ notes: [Note], format: ExportFormat) async throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
    let exportDir = tempDir.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)

    for note in notes {
        guard let url = try? await exportSingleNote(note, format: format) else {
            continue
        }

        let fileName = url.lastPathComponent
        let destination = exportDir.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: url, to: destination)
    }

    // Create ZIP using native FileManager API (iOS 16+)
    let zipURL = tempDir.appendingPathComponent("notes-export.zip")
    try FileManager.default.zipItem(at: exportDir, to: zipURL)

    // Cleanup export directory
    try? FileManager.default.removeItem(at: exportDir)

    return zipURL
}
```

### ~~Critical 2: PKDrawing Not Equatable~~ — REMOVED (Invalid)

**Original claim**: `PKDrawing` doesn't conform to `Equatable`

**Verification result**: **This is incorrect.** Apple's documentation confirms `PKDrawing` conforms to `Equatable`, `Codable`, and `Sendable`. No fix is required—the original Phase 4 code is correct as written.

### Critical 2: SwiftData Models Not Equatable (Renumbered)

**Issue**: SwiftData `@Model` classes are reference types and don't auto-synthesize `Equatable`, which breaks TCA `State: Equatable` requirements

**Location**: Phase 3 - `LibraryFeature.swift`, Phase 4 - `NoteEditorFeature.swift`

**Root cause**: The original errata correctly identified the issue but provided an incomplete fix—it changed selected references to UUIDs while still keeping `[Notebook]` and `[Note]` arrays that also require Equatable conformance.

**Fix**: Create lightweight value-type structs for list display and use UUIDs consistently

**Corrected code**:
```swift
// Add to NoteApp/Models/ViewModels.swift (new file):

/// Lightweight value type for displaying notebooks in lists
struct NotebookViewModel: Equatable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let childCount: Int
    let noteCount: Int

    init(from notebook: Notebook) {
        self.id = notebook.id
        self.name = notebook.name
        self.createdAt = notebook.createdAt
        self.childCount = notebook.children?.count ?? 0
        self.noteCount = notebook.notes?.count ?? 0
    }
}

/// Lightweight value type for displaying notes in lists
struct NoteViewModel: Equatable, Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let hasDrawing: Bool
    let tagNames: [String]

    init(from note: Note) {
        self.id = note.id
        self.title = note.title
        self.createdAt = note.createdAt
        self.updatedAt = note.updatedAt
        self.hasDrawing = note.drawingData != nil
        self.tagNames = note.tags?.map { $0.name } ?? []
    }
}

// Update LibraryFeature.swift:
@ObservableState
struct State: Equatable {
    var notebooks: [NotebookViewModel] = []
    var selectedNotebookId: UUID? = nil
    var notes: [NoteViewModel] = []
    var selectedNoteId: UUID? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Computed properties
    var selectedNotebook: NotebookViewModel? {
        notebooks.first { $0.id == selectedNotebookId }
    }

    var selectedNote: NoteViewModel? {
        notes.first { $0.id == selectedNoteId }
    }
}

enum Action: Equatable {
    case notebookSelected(UUID?)
    case noteSelected(UUID?)
    case notebooksLoaded([NotebookViewModel])
    case notesLoaded([NoteViewModel])
    // ...
}

// Update reducer to map models to view models:
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

// Update NoteEditorFeature.swift - use noteId instead of Note:
@ObservableState
struct State: Equatable {
    var noteId: UUID
    var noteTitle: String
    var drawing: PKDrawing  // PKDrawing IS Equatable
    var hasUnsavedChanges: Bool = false
    var isSaving: Bool = false
    @Presents var exitConfirmation: ConfirmationDialogState<Action.ExitConfirmation>?
}
```

---

## Important Issues (Should Fix for Design Completeness)

### Important 1: Missing Breadcrumb Navigation

**Issue**: Design specifies "navigate hierarchy with breadcrumbs" but not implemented

**Location**: Phase 3 - Missing from `LibraryView.swift`

**Fix**: Add breadcrumb component to NotebookListView

**Add to NotebookListView.swift**:
```swift
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
    }
}

// Add to NotebookListView above List:
BreadcrumbView(path: store.notebookPath, onSelect: { notebookId in
    store.send(.navigateToBreadcrumb(notebookId))
})
```

### Important 2: Missing Tag Badge in Editor

**Issue**: Design says "Tag badge in note editor showing active tags"

**Location**: Phase 6 - Missing from `NoteEditorView.swift`

**Fix**: Add tag badge overlay

**Add to NoteEditorView.swift**:
```swift
// Add after navigation overlay VStack:
if !store.detectedTags.isEmpty {
    VStack {
        Spacer()

        HStack {
            Spacer()

            TagBadgeOverlay(tags: Array(store.detectedTags))
                .padding()
        }
    }
    .transition(.move(edge: .trailing).combined(with: .opacity))
}

struct TagBadgeOverlay: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}
```

### Important 3: Missing Progress Indicator for Conversion

**Issue**: Design specifies progress indicator during handwriting conversion

**Location**: Phase 7 - Missing from `NoteListView.swift`

**Fix**: Show ProgressView when converting

**Add to NoteRowView.swift**:
```swift
struct NoteRowView: View {
    let note: NoteViewModel
    let isConverting: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)

                Text(note.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isConverting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// Update NoteListView to pass isConverting:
ForEach(store.notes) { note in
    NoteRowView(
        note: note,
        isConverting: store.convertingNoteId == note.id
    )
}
```

### Important 4: Incomplete Delete Implementation

**Issue**: Delete confirmation doesn't actually delete items

**Location**: Phase 3 - `LibraryFeature.swift` deleteConfirmation handler

**Fix**: Implement actual deletion

**Replace deleteConfirmation handler**:
```swift
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

// Update DeletableItem to use UUIDs:
enum DeletableItem: Equatable {
    case notebook(UUID)
    case note(UUID)
}

// Add to State:
var itemPendingDeletion: DeletableItem? = nil

// Update showDeleteConfirmation:
case .showDeleteConfirmation(let item):
    state.itemPendingDeletion = item
    state.deleteConfirmation = ConfirmationDialogState { ... }
```

### Important 5: Fix TagRepository Dependency Declaration

**Issue**: `@Dependency(\.tagRepository)` declared inside Effect closure is non-idiomatic and may cause issues

**Location**: Phase 6 - `NoteEditorFeature.swift` inside `.saveDrawing`

**Fix**: Declare at reducer level

**Corrected code**:
```swift
@Reducer
struct NoteEditorFeature {
    @Dependency(\.noteRepository) var noteRepo
    @Dependency(\.tagRepository) var tagRepo  // Move to reducer level
    @Dependency(\.continuousClock) var clock

    // ... in saveDrawing:
    return .run { send in
        do {
            // ... serialize drawing ...

            // Extract hashtags
            let extractor = HashtagExtractor()
            let detectedTags = try await extractor.extractHashtags(from: drawing)

            // Use tagRepo (captured from reducer scope)
            var tags: [Tag] = []
            for tagName in detectedTags {
                let tag = try await tagRepo.fetchOrCreateTag(name: tagName)
                tags.append(tag)
            }

            // ...
        }
    }
}
```

### Important 6: Fix Async/Await in Network Monitor

**Issue**: `await send()` used in non-async closure; also missing proper cancellation handling

**Location**: Phase 8 - `AppFeature.swift` network monitoring

**Fix**: Wrap in Task and add proper cancellation

**Corrected code**:
```swift
case .startNetworkMonitoring:
    return .run { send in
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")

        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task {
                await send(.networkStatusChanged(isOnline))
            }
        }

        monitor.start(queue: queue)

        // Keep monitor alive with proper cancellation handling
        await withTaskCancellationHandler {
            await Task.never()
        } onCancel: {
            monitor.cancel()
        }
    }
```

---

## Minor Issues (Fix Before Final Release)

### Minor 1: Use Modern PKDrawing Serialization

**Location**: Phase 4 & 7 - NSKeyedUnarchiver/Archiver usage

**Fix**: Use PKDrawing's native serialization APIs

```swift
// Serialization - replace NSKeyedArchiver:
let data = drawing.dataRepresentation()

// Deserialization - replace NSKeyedUnarchiver:
let drawing = try PKDrawing(data: drawingData)
```

### Minor 2: Unify State Variable Names

**Location**: Phase 3 vs Phase 6

**Fix**: Use consistent naming - `notes` instead of `notesInSelectedNotebook` or `filteredNotes`

### Minor 3: Add Dependencies/ Folder to Phase 1

**Location**: Phase 1 Task 3

**Fix**: Update directory structure to include:
```markdown
- Create: `NoteApp/Dependencies/` (directory)
```

### Minor 4: Add Export Format Selection UI

**Location**: Phase 7 - ExportFeature has format but no selection UI

**Fix**: Add format picker before export:
```swift
struct ExportOptionsView: View {
    @Bindable var store: StoreOf<ExportFeature>

    var body: some View {
        VStack {
            Picker("Format", selection: $store.exportFormat) {
                Text("PDF").tag(ExportFeature.ExportFormat.pdf)
                Text("Image").tag(ExportFeature.ExportFormat.image)
            }
            .pickerStyle(.segmented)

            Button("Export") {
                store.send(.exportButtonTapped)
            }
        }
    }
}
```

### Minor 5: Clarify OrganizationFeature Structure

**Location**: Design mentions OrganizationFeature but implementation embeds in LibraryFeature

**Note**: This is acceptable since design says "embedded in Library" - just document clearly

---

## Summary of Changes Required

**Before Implementation Starts:**
1. Use `FileManager.zipItem(at:to:)` for ZIP creation (remove SSZipArchive import)
2. Create value-type view models for SwiftData entities to ensure Equatable conformance
3. Declare `@Dependency` properties at reducer level, not inside closures
4. Fix network monitor with `Task {}` wrapper and proper cancellation

**For Design Completeness:**
5. Add breadcrumb navigation component
6. Add tag badge overlay in editor
7. Add progress indicator during conversion
8. Complete delete implementation with UUID-based tracking
9. Add export format selection UI

**Polish (before final release):**
10. Replace NSKeyedArchiver/Unarchiver with PKDrawing's native serialization
11. Unify variable naming across features
12. Add Dependencies/ folder to Phase 1
13. Document OrganizationFeature structure decision

---

## Corrections from Original Errata

| Original Issue | Status | Reason |
|----------------|--------|--------|
| Critical 2: PKDrawing not Equatable | **REMOVED** | Incorrect - PKDrawing conforms to Equatable |
| Critical 1: Compression framework fix | **CORRECTED** | Original fix was invalid (LZFSE ≠ ZIP); now uses FileManager.zipItem |
| Critical 3: SwiftData fix | **EXPANDED** | Original fix was incomplete; now provides full value-type strategy |
| Important 6: Network monitor | **EXPANDED** | Added proper cancellation handling |

---

**Status**: After these fixes, implementation plan is APPROVED and ready for execution.
