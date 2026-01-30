# Implementation Plan Errata & Required Fixes

**Date:** 2026-01-29
**Status:** Issues identified by code-reviewer, must be addressed before implementation

---

## Critical Issues (Must Fix Before Implementation)

### Critical 1: Remove ZipArchive Dependency

**Issue**: Phase 7 imports `ZipArchive` but no SPM dependency added

**Location**: Phase 7, Task 3 - `ExportFeature.swift` line 4

**Fix**: Replace ZipArchive with native iOS Compression framework

**Corrected code**:
```swift
import Compression
import Foundation

// Replace SSZipArchive.createZipFile with:
private func createZIP(from directory: URL, to destination: URL) throws {
    let fileManager = FileManager.default
    let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

    let archive = try FileHandle(forWritingTo: destination)
    defer { try? archive.close() }

    for fileURL in files {
        let data = try Data(contentsOf: fileURL)
        let compressed = try (data as NSData).compressed(using: .lzfse) as Data
        archive.write(compressed)
    }
}
```

### Critical 2: PKDrawing Not Equatable

**Issue**: `PKDrawing` doesn't conform to `Equatable`, breaks TCA `State: Equatable`

**Location**: Phase 4 - `NoteEditorFeature.swift` State definition

**Fix**: Mark `drawing` property with `@EquatableNoop`

**Corrected code**:
```swift
@ObservableState
struct State: Equatable {
    var note: Note
    @EquatableNoop var drawing: PKDrawing  // Add @EquatableNoop
    var hasUnsavedChanges: Bool = false
    var isSaving: Bool = false
    @Presents var exitConfirmation: ConfirmationDialogState<Action.ExitConfirmation>?
}
```

### Critical 3: SwiftData Models Not Equatable

**Issue**: SwiftData `@Model` classes don't conform to `Equatable`, breaks TCA State

**Location**: Phase 3 - `LibraryFeature.swift` State definition

**Fix**: Use UUIDs instead of model references in TCA state

**Corrected code**:
```swift
@ObservableState
struct State: Equatable {
    var notebooks: [Notebook] = []
    var selectedNotebookId: UUID? = nil  // Changed from Notebook?
    var notesInSelectedNotebook: [Note] = []
    var selectedNoteId: UUID? = nil  // Changed from Note?
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Computed properties for convenience
    var selectedNotebook: Notebook? {
        notebooks.first { $0.id == selectedNotebookId }
    }

    var selectedNote: Note? {
        notesInSelectedNotebook.first { $0.id == selectedNoteId }
    }
}

// Update actions to use UUIDs
enum Action: Equatable {
    case notebookSelected(UUID?)  // Changed from Notebook?
    case noteSelected(UUID?)      // Changed from Note?
    // ...
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
    let path: [Notebook]
    let onSelect: (Notebook?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button("All") {
                    onSelect(nil)
                }

                ForEach(Array(path.enumerated()), id: \.element.id) { index, notebook in
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(notebook.name) {
                        onSelect(notebook)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// Add to NotebookListView above List:
BreadcrumbView(path: store.notebookPath, onSelect: { notebook in
    store.send(.navigateToBreadcrumb(notebook))
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
    let note: Note
    let isConverting: Bool  // Add parameter

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
ForEach(store.notesInSelectedNotebook) { note in
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
    // Track what to delete
    guard let itemToDelete = state.itemPendingDeletion else { return .none }

    return .run { send in
        do {
            switch itemToDelete {
            case .notebook(let notebook):
                try await notebookRepo.deleteNotebook(id: notebook.id)
            case .note(let note):
                try await noteRepo.deleteNote(id: note.id)
            }
            await send(.deleteCompleted)
        } catch {
            await send(.errorOccurred(error.localizedDescription))
        }
    }

// Add to State:
var itemPendingDeletion: DeletableItem? = nil

// Update showDeleteConfirmation:
case .showDeleteConfirmation(let item):
    state.itemPendingDeletion = item  // Track item to delete
    state.deleteConfirmation = ConfirmationDialogState { ... }
```

### Important 5: Fix TagRepository Dependency Declaration

**Issue**: `@Dependency(\.tagRepository)` declared inside Effect closure is invalid

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

            // Use tagRepo (already declared above)
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

**Issue**: `await send()` used in non-async closure

**Location**: Phase 8 - `AppFeature.swift` network monitoring

**Fix**: Wrap in Task

**Corrected code**:
```swift
case .startNetworkMonitoring:
    return .run { send in
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")

        monitor.pathUpdateHandler = { path in
            let isOnline = path.status == .satisfied
            Task {  // Wrap in Task
                await send(.networkStatusChanged(isOnline))
            }
        }

        monitor.start(queue: queue)

        // Keep monitor alive - proper pattern:
        await withCheckedContinuation { continuation in
            // Monitor stays alive for duration of effect
        }
    }
```

---

## Minor Issues (Fix Before Final Release)

### Minor 1: Use Modern PKDrawing Deserialization

**Location**: Phase 4 & 7 - NSKeyedUnarchiver usage

**Fix**:
```swift
// Replace NSKeyedUnarchiver pattern:
let drawing = try PKDrawing(data: drawingData)

// Instead of:
let drawing = try NSKeyedUnarchiver.unarchivedObject(
    ofClass: PKDrawing.self,
    from: drawingData
)
```

### Minor 2: Unify State Variable Names

**Location**: Phase 3 vs Phase 6

**Fix**: Rename `notesInSelectedNotebook` to `filteredNotes` throughout for consistency

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
1. Fix ZipArchive → use Compression framework (or remove batch ZIP)
2. Add `@EquatableNoop` to PKDrawing in NoteEditorFeature
3. Change model references to UUIDs in LibraryFeature State
4. Declare tagRepo at reducer level in NoteEditorFeature
5. Fix async closure in network monitoring

**For Design Completeness:**
6. Add breadcrumb navigation component
7. Add tag badge overlay in editor
8. Add progress indicator during conversion
9. Complete delete implementation
10. Add export format selection UI

**Polish (before final release):**
11. Replace NSKeyedUnarchiver with PKDrawing(data:)
12. Unify variable naming
13. Add Dependencies/ folder to Phase 1
14. Document OrganizationFeature structure decision

---

**Status**: After these fixes, implementation plan will be APPROVED and ready for execution.
