# reMarkable iPad Note App Implementation Plan - Phase 5

**Goal:** Implement reMarkable-style focused navigation with deliberate friction

**Architecture:** Auto-hiding navigation with gesture-triggered temporary overlay, TCA state management for navigation visibility

**Tech Stack:** SwiftUI gesture recognizers, animations, TCA timers

**Scope:** Phase 5 of 8 from original design

---

## Phase 5: Strict Single-Task Navigation Model

### Done When
- Navigation bar hides automatically after 3 seconds in note
- Double-tap top edge reveals navigation temporarily
- Cannot swipe back accidentally
- Exit button shows confirmation if changes exist
- Home indicator hidden during editing
- Navigation overlay fades after 5 seconds or when drawing resumes

---

<!-- START_TASK_1 -->
### Task 1: Add Navigation Visibility State

**Files:**
- Modify: `NoteApp/Features/NoteEditor/NoteEditorFeature.swift`

Add to State:
```swift
var navigationVisible: Bool = true
var showingExitConfirmation: Bool = false
```

Add to Action:
```swift
case hideNavigationAfterDelay
case showNavigationTemporarily
case hideNavigation
case gestureDetected(GestureType)

enum GestureType {
    case topEdgeDoubleTap
    case drawingStarted
}
```

Add to reducer:
```swift
case .hideNavigationAfterDelay:
    return .run { send in
        try await clock.sleep(for: .seconds(3))
        await send(.hideNavigation)
    }
    .cancellable(id: CancelID.navigationHide, cancelInFlight: true)

case .showNavigationTemporarily:
    state.navigationVisible = true
    return .run { send in
        try await clock.sleep(for: .seconds(5))
        await send(.hideNavigation)
    }
    .cancellable(id: CancelID.navigationHide, cancelInFlight: true)

case .hideNavigation:
    state.navigationVisible = false
    return .none

case .gestureDetected(.topEdgeDoubleTap):
    return .send(.showNavigationTemporarily)

case .gestureDetected(.drawingStarted):
    if state.navigationVisible {
        return .send(.hideNavigationAfterDelay)
    }
    return .none
```

Add CancelID:
```swift
enum CancelID { case save, navigationHide }
```

Commit:
```bash
git add NoteApp/Features/NoteEditor/NoteEditorFeature.swift
git commit -m "feat: add navigation visibility state and timing

- Add navigationVisible state flag
- Implement auto-hide after 3 seconds
- Add temporary show with 5-second fade
- Handle gesture detection actions
- Use cancellable effects for timing control

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Update NoteEditorView with Auto-Hiding Navigation

**Files:**
- Modify: `NoteApp/Features/NoteEditor/NoteEditorView.swift`

Replace with:
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
                    store.send(.gestureDetected(.drawingStarted))
                }
            )
            .ignoresSafeArea()
            .persistentSystemOverlays(.hidden) // Hide home indicator

            // Auto-hiding navigation overlay
            if store.navigationVisible {
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
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Invisible double-tap detection zone at top edge
            VStack {
                Color.clear
                    .frame(height: 60)
                    .contentShape(Rectangle())
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                store.send(.gestureDetected(.topEdgeDoubleTap))
                            }
                    )

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.navigationVisible)
        .onAppear {
            store.send(.onAppear)
            store.send(.hideNavigationAfterDelay)
        }
        .confirmationDialog(
            $store.scope(
                state: \.exitConfirmation,
                action: \.exitConfirmation
            )
        )
        .interactiveDismissDisabled(store.hasUnsavedChanges)
    }
}
```

Commit:
```bash
git add NoteApp/Features/NoteEditor/NoteEditorView.swift
git commit -m "feat: implement auto-hiding navigation overlay

- Hide navigation 3 seconds after entering note
- Add top-edge double-tap gesture for temporary reveal
- Hide navigation when drawing starts
- Fade overlay with smooth animations
- Hide home indicator for immersive experience
- Disable swipe-back when unsaved changes exist
- Phase 5 complete: reMarkable-style focused navigation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```
<!-- END_TASK_2 -->

---

## Phase 5 Complete

**Verification:**
- ✓ Navigation hides after 3 seconds automatically
- ✓ Double-tap top edge reveals navigation for 5 seconds
- ✓ Navigation hides when drawing starts
- ✓ Swipe-back disabled for unsaved changes
- ✓ Home indicator hidden in editor
- ✓ Smooth fade-in/fade-out animations

**Next Phase:** Phase 6 - Tags, Search, and Organization
