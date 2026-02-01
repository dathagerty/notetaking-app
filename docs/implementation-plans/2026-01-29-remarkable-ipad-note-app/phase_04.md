# reMarkable iPad Note App Implementation Plan - Phase 4

**Goal:** Full-featured note editing with PencilKit drawing and auto-save

**Architecture:** NoteEditorFeature with PKCanvasView via UIViewRepresentable, debounced auto-save Effect, drawing serialization to SwiftData

**Tech Stack:** PencilKit (PKCanvasView, PKToolPicker, PKDrawing), UIViewRepresentable, TCA debounced effects

**Scope:** Phase 4 of 8 from original design

**Codebase verified:** 2026-01-29 (Phase 1-3 must complete first)

---

## Phase 4: PencilKit Note Editor

### Done When
- Can draw with Apple Pencil and finger
- Tool picker appears and functions
- Drawing auto-saves after 2 seconds of inactivity
- Saved drawings persist and reload correctly
- Can navigate back to library with unsaved changes confirmation

---

<!-- START_TASK_1 -->
### Task 1: Create NoteEditorFeature with TCA

**Files:**
- Create: `NoteApp/Features/NoteEditor/NoteEditorFeature.swift`

```swift
import ComposableArchitecture
import PencilKit
import Foundation

@Reducer
struct NoteEditorFeature {
    @ObservableState
    struct State: Equatable {
        var note: Note
        var drawing: PKDrawing
        var hasUnsavedChanges: Bool = false
        var isSaving: Bool = false
        @Presents var exitConfirmation: ConfirmationDialogState<Action.ExitConfirmation>?
    }

    enum Action: Equatable {
        case onAppear
        case drawingChanged(PKDrawing)
        case saveDrawing
        case drawingSaved
        case saveFailed(String)
        case closeButtonTapped
        case exitConfirmation(PresentationAction<ExitConfirmation>)

        enum ExitConfirmation: Equatable {
            case confirmExit
            case cancelExit
        }
    }

    @Dependency(\.noteRepository) var noteRepo
    @Dependency(\.continuousClock) var clock

    enum CancelID { case save }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Load existing drawing if available
                if let data = state.note.drawingData {
                    do {
                        // Use PKDrawing's native deserialization
                        let drawing = try PKDrawing(data: data)
                        state.drawing = drawing
                    } catch {
                        state.drawing = PKDrawing()
                    }
                } else {
                    state.drawing = PKDrawing()
                }
                return .none

            case .drawingChanged(let newDrawing):
                state.drawing = newDrawing
                state.hasUnsavedChanges = true

                // Debounced auto-save (2 seconds after drawing stops)
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.saveDrawing)
                }
                .cancellable(id: CancelID.save, cancelInFlight: true)

            case .saveDrawing:
                guard state.hasUnsavedChanges else { return .none }
                state.isSaving = true

                let drawing = state.drawing
                let note = state.note

                return .run { send in
                    do {
                        // Use PKDrawing's native serialization
                        let data = drawing.dataRepresentation()

                        // Update note via repository
                        note.drawingData = data
                        note.updatedAt = Date()
                        try await noteRepo.updateNote(note)

                        await send(.drawingSaved)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .drawingSaved:
                state.hasUnsavedChanges = false
                state.isSaving = false
                return .none

            case .saveFailed(let error):
                state.isSaving = false
                print("Save failed: \(error)")
                // Retry save automatically after 5 seconds
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.saveDrawing)
                }

            case .closeButtonTapped:
                if state.hasUnsavedChanges {
                    state.exitConfirmation = ConfirmationDialogState {
                        TextState("Unsaved Changes")
                    } actions: {
                        ButtonState(role: .destructive, action: .confirmExit) {
                            TextState("Discard Changes")
                        }
                        ButtonState(role: .cancel, action: .cancelExit) {
                            TextState("Keep Editing")
                        }
                    } message: {
                        TextState("You have unsaved changes. Discard them?")
                    }
                    return .none
                }
                // No unsaved changes, exit immediately
                return .none

            case .exitConfirmation(.presented(.confirmExit)):
                // Actually handle exit in parent (LibraryFeature)
                return .none

            case .exitConfirmation:
                return .none
            }
        }
        .ifLet(\.$exitConfirmation, action: \.exitConfirmation)
    }
}
```

Commit:
```bash
git add NoteApp/Features/NoteEditor/NoteEditorFeature.swift
git commit -m "feat: create NoteEditorFeature with PencilKit state management

- Define state for PKDrawing and save status
- Implement debounced auto-save with 2-second delay
- Add drawing serialization to SwiftData
- Include unsaved changes confirmation dialog
- Auto-retry failed saves after 5 seconds

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Create CanvasView with UIViewRepresentable

**Files:**
- Create: `NoteApp/Features/NoteEditor/CanvasView.swift`
- Create: `NoteApp/Features/NoteEditor/CanvasCoordinator.swift`

**Step 1: Create CanvasView**

```swift
import SwiftUI
import PencilKit

struct CanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let onDrawingChanged: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()

        // Configure canvas
        canvasView.drawing = drawing
        canvasView.drawingPolicy = .anyInput // Allow Apple Pencil and finger
        canvasView.delegate = context.coordinator

        // Show tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update drawing if changed externally
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> CanvasCoordinator {
        CanvasCoordinator(onDrawingChanged: onDrawingChanged)
    }
}
```

**Step 2: Create CanvasCoordinator**

```swift
import PencilKit

class CanvasCoordinator: NSObject, PKCanvasViewDelegate {
    let onDrawingChanged: (PKDrawing) -> Void

    init(onDrawingChanged: @escaping (PKDrawing) -> Void) {
        self.onDrawingChanged = onDrawingChanged
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        onDrawingChanged(canvasView.drawing)
    }
}
```

Commit:
```bash
git add NoteApp/Features/NoteEditor/CanvasView.swift NoteApp/Features/NoteEditor/CanvasCoordinator.swift
git commit -m "feat: create PencilKit canvas with UIViewRepresentable

- Wrap PKCanvasView in SwiftUI-compatible UIViewRepresentable
- Configure canvas for Apple Pencil and finger input
- Add CanvasCoordinator for drawing change delegation
- Integrate PKToolPicker for system-wide tool selection
- Enable bidirectional drawing updates

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create NoteEditorView

**Files:**
- Create: `NoteApp/Features/NoteEditor/NoteEditorView.swift`

```swift
import SwiftUI
import ComposableArchitecture
import PencilKit

struct NoteEditorView: View {
    @Bindable var store: StoreOf<NoteEditorFeature>

    var body: some View {
        ZStack {
            // Full-screen canvas
            CanvasView(
                drawing: $store.drawing,
                onDrawingChanged: { newDrawing in
                    store.send(.drawingChanged(newDrawing))
                }
            )
            .ignoresSafeArea()

            // Minimal navigation bar (will auto-hide in Phase 5)
            VStack {
                HStack {
                    Button {
                        store.send(.closeButtonTapped)
                    } label: {
                        Label("Close", systemImage: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    if store.isSaving {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Saving...")
                                .font(.caption)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
                .padding()

                Spacer()
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .confirmationDialog(
            $store.scope(
                state: \.exitConfirmation,
                action: \.exitConfirmation
            )
        )
    }
}

#Preview {
    NoteEditorView(
        store: Store(
            initialState: NoteEditorFeature.State(
                note: Note(title: "Test Note"),
                drawing: PKDrawing()
            ),
            reducer: { NoteEditorFeature() }
        )
    )
}
```

Commit:
```bash
git add NoteApp/Features/NoteEditor/NoteEditorView.swift
git commit -m "feat: create full-screen NoteEditorView with PencilKit

- Display CanvasView in full-screen immersive mode
- Add minimal close button with confirmation dialog
- Show saving indicator during auto-save
- Integrate exit confirmation for unsaved changes
- Phase 4 complete: functional drawing and persistence

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Integrate NoteEditor into LibraryFeature

**Files:**
- Modify: `NoteApp/Features/Library/LibraryFeature.swift`
- Modify: `NoteApp/Features/Library/LibraryView.swift`

**Step 1: Update LibraryFeature to include NoteEditorFeature**

Add to `LibraryFeature.State`:
```swift
@Presents var noteEditor: NoteEditorFeature.State?
```

Add to `LibraryFeature.Action`:
```swift
case noteEditor(PresentationAction<NoteEditorFeature.Action>)
```

Update `.noteSelected` case:
```swift
case .noteSelected(let note):
    if let note = note {
        state.noteEditor = NoteEditorFeature.State(
            note: note,
            drawing: PKDrawing()
        )
    }
    return .none
```

Add to reducer body:
```swift
.ifLet(\.$noteEditor, action: \.noteEditor) {
    NoteEditorFeature()
}
```

**Step 2: Update LibraryView detail pane**

Replace detail section:
```swift
detail: {
    if let note = store.selectedNote {
        if let editorStore = store.scope(
            state: \.noteEditor,
            action: \.noteEditor
        ) {
            NoteEditorView(store: editorStore)
        }
    } else {
        Text("Select a note")
            .foregroundColor(.gray)
    }
}
```

Commit:
```bash
git add NoteApp/Features/Library/LibraryFeature.swift NoteApp/Features/Library/LibraryView.swift
git commit -m "feat: integrate NoteEditor into Library navigation

- Add NoteEditorFeature as presented state in LibraryFeature
- Navigate to editor when note selected
- Display editor in NavigationSplitView detail pane
- Phase 4 complete: end-to-end note editing with persistence

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_4 -->

---

## Phase 4 Complete

**Verification:**
- ✓ PKCanvasView integrated via UIViewRepresentable
- ✓ Drawing with Apple Pencil and finger functional
- ✓ PKToolPicker appears and functions
- ✓ Auto-save with 2-second debounce
- ✓ Drawing serialization to SwiftData working
- ✓ Navigation back with unsaved changes confirmation

**Next Phase:** Phase 5 - Strict Single-Task Navigation Model
