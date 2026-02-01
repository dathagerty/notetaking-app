# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is a **git worktree-based development repository** for iPad/iOS projects. The main branch contains only design documentation; actual implementation happens in worktrees:

- `docs/design-plans/` — Design documents describing features and architecture
- `.worktrees/` — Git worktrees containing actual implementation code (one per feature branch)

**Important**: The main branch has no Xcode projects or Swift code. All development happens in worktrees created from design plans.

## Working with Worktrees

To start implementing a design plan:

```bash
# Create worktree for a design plan
git worktree add .worktrees/<feature-name> -b <feature-name>
cd .worktrees/<feature-name>

# Work here - this is where Xcode projects live
```

To list existing worktrees:
```bash
git worktree list
```

To remove a completed worktree:
```bash
git worktree remove .worktrees/<feature-name>
```

## Current Project: reMarkable-like iPad Note App

The active implementation is in `.worktrees/remarkable-ipad-note-app/NoteApp/`.

### Architecture Overview

**Framework**: The Composable Architecture (TCA) — Redux-inspired state management with unidirectional data flow (State → Action → Reducer → Effect → State).

**Persistence**: SwiftData with automatic CloudKit sync via entitlements (iCloud container + CloudKit capability). Local-first architecture where all writes succeed immediately to local storage, cloud sync happens asynchronously in background. Note: SwiftData handles CloudKit automatically when entitlements are present—no explicit `NSPersistentCloudKitContainer` needed.

**Core Pattern**: FCIS (Functional Core, Imperative Shell):
- **Functional Core**: TCA Reducers are pure functions `(State, Action) -> (State, Effect)` containing all business logic
- **Imperative Shell**: Effects handle side effects (I/O, network, timers), SwiftUI views, UIKit bridges

### Feature Structure

```
NoteAppApp.swift           — App entry point with SwiftData config (root level)

App/
├── AppFeature.swift       — Root TCA feature (app-level state)
└── AppView.swift          — Root SwiftUI view

Features/
├── Library/               — Notebook/note browsing (NavigationSplitView)
│   ├── LibraryFeature.swift
│   ├── LibraryView.swift
│   ├── NotebookListView.swift
│   ├── NoteListView.swift
│   └── NoteRowView.swift
└── NoteEditor/            — Full-screen PencilKit canvas
    ├── NoteEditorFeature.swift
    ├── NoteEditorView.swift
    ├── CanvasView.swift           (UIViewRepresentable for PKCanvasView)
    └── CanvasCoordinator.swift

Models/                    — SwiftData @Model entities
├── Notebook.swift         — Hierarchical tree (parent/children)
├── Note.swift             — Drawing data + metadata
├── Tag.swift              — Many-to-many with Notes
└── ViewModels.swift       — Lightweight Equatable value types for TCA state

Repositories/              — Abstraction over SwiftData queries
├── NoteRepository.swift
├── NotebookRepository.swift
└── TagRepository.swift

Dependencies/
└── RepositoryDependencies.swift — TCA dependency injection setup
```

### Data Flow Pattern

1. User interaction → Action dispatched to Store
2. Reducer (pure function) → New State + Effects
3. Effects → Run side effects (async operations)
4. Effect completion → New Action dispatched
5. State update → SwiftUI views re-render

Example:
```swift
// Drawing update flow
User draws → .drawingChanged(PKDrawing)
→ Reducer: state.drawing = newDrawing, state.hasUnsavedChanges = true
→ Effect: Debounced save (2 seconds)
→ Repository serializes PKDrawing.dataRepresentation()
→ SwiftData persists → CloudKit syncs
→ .drawingSaved → Reducer: state.hasUnsavedChanges = false
```

### Key Architectural Decisions

**Repository Pattern**: SwiftData queries wrapped in protocol-based repositories. Keeps reducers pure (no direct ModelContext access) and enables testing with mock repositories.

**TCA Feature Composition**: `LibraryFeature` contains `NoteEditorFeature` as optional child state (`@Presents var noteEditor: NoteEditorFeature.State?`). Navigation handled via presentation actions.

**Dependency Injection**: TCA's `@Dependency` system for repositories and services. `ModelContext` provided via dependency values, repositories created lazily from ModelContext.

**iOS 18 Workaround**: SwiftData relationship management differs between iOS 17 and 18. When creating notes, append from parent side (`notebook.notes?.append(note)`) on iOS 18+ instead of setting `note.notebook`.

**ViewModel Pattern**: SwiftData `@Model` classes don't conform to `Equatable`, so TCA state uses lightweight value types (`NotebookViewModel`, `NoteViewModel`, `TagViewModel`) that copy essential fields from models. This enables TCA's state equality checks while avoiding direct model references in state.

**Auto-save Strategy**: Drawing changes debounced with 2-second delay using TCA's cancellable effects. Prevents excessive saves during active drawing while ensuring data persistence.

**Strict Single-Task Model**: Navigation deliberately hidden during note editing (mimics reMarkable tablet). User must explicitly invoke navigation (double-tap top edge) to switch contexts.

## Development Commands

### Building and Running

```bash
cd .worktrees/remarkable-ipad-note-app/NoteApp

# Build
xcodebuild -scheme NoteApp -configuration Debug build

# Run tests (use any available iPad simulator)
xcodebuild test -scheme NoteApp -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'

# Or use Xcode UI
open NoteApp.xcodeproj
```

**Deployment Target**: iOS 17+ (requires SwiftData and TCA 1.x)
**Device**: iPad only (uses NavigationSplitView, optimized for Apple Pencil)

### Running Tests

The project uses **both** Swift Testing and XCTest:
- TCA reducer tests use Swift Testing (`@Test` attribute)
- Repository tests use XCTest (`XCTestCase`)

```bash
# All tests
xcodebuild test -scheme NoteApp

# Specific test file
xcodebuild test -scheme NoteApp -only-testing:NoteAppTests/AppFeatureTests

# TCA tests use TestStore for reducer verification
```

**Test Structure**:
- `NoteAppTests/NoteAppTests.swift` — TCA reducer tests (Swift Testing, `@Test`)
- `NoteAppTests/LibraryFeatureTests.swift` — Library feature tests (Swift Testing)
- `NoteAppTests/RepositoryTests.swift` — Repository layer tests (XCTest, in-memory SwiftData)

### Dependencies

Managed via Swift Package Manager (Xcode integration):

- `swift-composable-architecture` @ 1.23.1 — TCA framework
- Transitive dependencies auto-resolved (swift-dependencies, swift-case-paths, etc.)

To update:
```bash
# In Xcode: File > Packages > Update to Latest Package Versions
# Or via CLI:
xcodebuild -resolvePackageDependencies
```

## Testing CloudKit Sync

CloudKit sync requires:
1. **Entitlements configured** (iCloud container + CloudKit capability)
2. **Physical devices** (iOS Simulators cannot sign into iCloud for CloudKit testing)
3. **Two devices signed into same iCloud account**
4. **Network connectivity**

Verify sync:
```swift
// Create data on Device A
let notebook = Notebook(name: "Test")
modelContext.insert(notebook)
try modelContext.save()

// Wait 30-60 seconds for CloudKit background sync
// Check Device B — should see "Test" notebook appear
```

**Conflict Resolution**: SwiftData with CloudKit uses last-write-wins by default. Acceptable for single-user note-taking; conflicts are rare.

## Code Patterns

### TCA Reducer Pattern

```swift
@Reducer
struct MyFeature {
    @ObservableState
    struct State: Equatable { /* ... */ }

    enum Action { /* ... */ }

    @Dependency(\.myRepository) var repo

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .someAction:
                // Pure state transformations here
                return .run { send in
                    // Side effects in .run
                    let result = try await repo.fetchData()
                    await send(.dataLoaded(result))
                }
            }
        }
    }
}
```

### Repository Interface Pattern

```swift
protocol MyRepository: Sendable {
    func fetchData() async throws -> [Data]
}

actor SwiftDataMyRepository: MyRepository {
    private let modelContext: ModelContext

    func fetchData() async throws -> [Data] {
        let descriptor = FetchDescriptor<MyModel>()
        return try modelContext.fetch(descriptor)
    }
}
```

### PencilKit Integration (UIKit → SwiftUI Bridge)

```swift
struct CanvasView: UIViewRepresentable {
    let drawing: PKDrawing  // Passed from TCA state (not @Binding)
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .anyInput  // Allow Pencil and finger
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing  // Sync external changes
        }
    }

    func makeCoordinator() -> CanvasCoordinator {
        CanvasCoordinator(onDrawingChanged: onDrawingChanged)
    }
}
// Note: Coordinator retains PKToolPicker to prevent deallocation
```

## Common Pitfalls

**SwiftData @Model in TCA State**: SwiftData models are classes and don't conform to `Equatable`. Never store `@Model` instances directly in TCA State. Use ViewModels (see `Models/ViewModels.swift`) to create lightweight value copies.

**SwiftData Relationships**: Always verify iOS version when setting relationships. iOS 18 requires explicit parent-side appends for inverse relationships.

**TCA Effect Cancellation**: Use `.cancellable(id:, cancelInFlight: true)` for debounced effects to prevent stale effect completions from racing.

**PKDrawing Serialization**: Use `drawing.dataRepresentation()` to serialize PKDrawing to Data for SwiftData storage. Deserialize with `try PKDrawing(data:)`.

**Testing TCA**: TestStore requires exhaustive assertions. Must assert all state changes from an action, including child feature state.

**CloudKit Quotas**: PKDrawing files range 1-5 MB per complex page. Free iCloud tier (1 GB storage, 10 GB/month transfer) supports ~200-1000 notes. No quota management needed at MVP.

**Navigation State**: Use `@Presents` for presented features (sheets, navigation destinations). TCA automatically manages presentation lifecycle.
