# reMarkable iPad Note App Implementation Plan - Phase 1

**Goal:** Initialize Xcode project with TCA foundation and basic structure

**Architecture:** TCA (The Composable Architecture) for state management with SwiftUI views, following FCIS pattern where reducers are pure functions and effects handle side effects

**Tech Stack:**
- Xcode 16 (current for 2026)
- Swift 5.10+
- SwiftUI (iOS 17+)
- The Composable Architecture 1.23.1+
- iPad-only deployment target

**Scope:** Phase 1 of 8 from original design

**Codebase verified:** 2026-01-29 17:00 UTC

---

## Phase 1: Project Setup & TCA Foundation

### Codebase Verification Summary

**Testing Methodology** (from investigation):
- No existing CLAUDE.md or AGENTS.md files with testing requirements
- Greenfield iOS project - no code exists yet
- Recommendation: Use XCTest (Apple's standard framework)
- TCA architecture suits test-driven reducer development
- Pure reducers should be unit tested (input state + action → output state)
- Effects tested with mock repositories and schedulers
- High-friction dependencies (PencilKit, CloudKit) require physical device testing

**Project Status:**
- ✗ No Xcode project exists
- ✗ No Swift files exist
- ✗ No Package.swift (iOS apps use Xcode package manager)
- ✓ Design document complete at docs/design-plans/2026-01-29-remarkable-ipad-note-app.md
- This phase creates all initial structure from scratch

**External Dependency Research:**
- TCA Official Repository: https://github.com/pointfreeco/swift-composable-architecture
- Current Stable Version: 1.23.1 (October 2025)
- iOS 17+ uses native @Observable macro (no Perception backport needed)
- Modern @Reducer pattern with body: some ReducerOf<Self>
- Effects use .run with async/await

---

<!-- START_TASK_1 -->
### Task 1: Create Xcode Project

**Files:**
- Create: `NoteApp.xcodeproj`
- Create: `NoteApp/` (source directory)
- Create: `NoteAppTests/` (test target directory)

**Step 1: Create new iOS App project**

Open Xcode 16:
1. File → New → Project
2. Select "iOS" → "App" template
3. Configure project:
   - **Product Name:** NoteApp
   - **Organization Identifier:** com.remarkable (or your identifier)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Include Tests:** Yes
4. Save to repository root (select the `.worktrees/remarkable-ipad-note-app/` directory)

Expected result: Xcode creates `NoteApp.xcodeproj` with default SwiftUI template

**Step 2: Configure iPad-only deployment**

In Xcode:
1. Select project in navigator (top "NoteApp" item)
2. Select "NoteApp" target
3. General tab → Supported Destinations
4. Uncheck "iPhone"
5. Keep "iPad" checked
6. Minimum Deployments → iOS 17.0

Expected result: Project builds for iPad only, iOS 17+ minimum

**Step 3: Verify project builds**

Run in Xcode:
- Product → Build (Cmd+B)

Expected: Build succeeds, shows default "Hello, world!" template

**Step 4: Commit initial project**

```bash
git add NoteApp.xcodeproj NoteApp/ NoteAppTests/
git commit -m "feat: initialize Xcode project with iPad deployment target iOS 17+

- Create NoteApp.xcodeproj with SwiftUI template
- Configure iPad-only deployment
- Add test target NoteAppTests
- Set minimum iOS 17.0 deployment target

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_1 -->

<!-- START_TASK_2 -->
### Task 2: Add TCA Dependency

**Files:**
- Modify: `NoteApp.xcodeproj/project.pbxproj` (via Xcode UI)

**Step 1: Add Swift Package Manager dependency**

In Xcode:
1. Select project in navigator
2. Project Settings → Package Dependencies tab
3. Click "+" button (Add Package Dependency)
4. Enter URL: `https://github.com/pointfreeco/swift-composable-architecture`
5. Dependency Rule: "Up to Next Major Version" → 1.23.1
6. Click "Add Package"
7. Select "ComposableArchitecture" library
8. Add to "NoteApp" target
9. Click "Add Package"

Expected result: TCA appears in Package Dependencies list, resolves successfully

**Step 2: Verify TCA imports**

Create temporary test file in Xcode: File → New → File → Swift File → `TCATest.swift`

Add content:
```swift
import ComposableArchitecture

// Temporary verification - will delete
struct TestFeature: Reducer {
    struct State: Equatable {}
    enum Action {}

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            return .none
        }
    }
}
```

**Step 3: Build to verify TCA resolves**

Run: Product → Build (Cmd+B)

Expected: Build succeeds, no import errors

**Step 4: Remove temporary test file**

Delete `TCATest.swift` in Xcode (right-click → Delete → Move to Trash)

**Step 5: Commit TCA dependency**

```bash
git add NoteApp.xcodeproj/project.pbxproj
git commit -m "feat: add TCA dependency via SPM

- Add swift-composable-architecture 1.23.1+
- Configure for NoteApp target
- Verified TCA imports successfully

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_2 -->

<!-- START_TASK_3 -->
### Task 3: Create Directory Structure

**Files:**
- Create: `NoteApp/App/` (directory)
- Create: `NoteApp/Features/` (directory)
- Create: `NoteApp/Models/` (directory)
- Create: `NoteApp/Repositories/` (directory)
- Create: `NoteApp/Services/` (directory)

**Step 1: Create directories in Xcode**

In Xcode:
1. Right-click `NoteApp` group → New Group → `App`
2. Right-click `NoteApp` group → New Group → `Features`
3. Right-click `NoteApp` group → New Group → `Models`
4. Right-click `NoteApp` group → New Group → `Repositories`
5. Right-click `NoteApp` group → New Group → `Services`

Expected result: Five new folders appear in Xcode project navigator

**Step 2: Verify directory structure**

In terminal:
```bash
ls -la NoteApp/
```

Expected output includes:
```
App/
Features/
Models/
Repositories/
Services/
```

**Step 3: Commit directory structure**

```bash
git add NoteApp/App/ NoteApp/Features/ NoteApp/Models/ NoteApp/Repositories/ NoteApp/Services/
git commit -m "feat: create initial directory structure

- Add App/ for root TCA feature
- Add Features/ for domain features (Library, NoteEditor, etc.)
- Add Models/ for SwiftData models (Phase 2+)
- Add Repositories/ for data access abstractions (Phase 2+)
- Add Services/ for utility services (Phase 7+)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_3 -->

<!-- START_TASK_4 -->
### Task 4: Create AppFeature

**Files:**
- Create: `NoteApp/App/AppFeature.swift`

**Step 1: Create AppFeature.swift file**

In Xcode:
1. Right-click `App/` group → New File
2. Select "Swift File"
3. Name: `AppFeature.swift`
4. Targets: NoteApp (checked)
5. Create

**Step 2: Implement AppFeature with root TCA structure**

Add content to `AppFeature.swift`:

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

        // Child feature states (will be populated in later phases)
        // Phase 3: var library: LibraryFeature.State = .init()
    }

    enum Action: Equatable {
        case onAppear
        case focusModeToggled
        case networkStatusChanged(Bool)

        // Child feature actions (will be populated in later phases)
        // Phase 3: case library(LibraryFeature.Action)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Initialize app state
                return .none

            case .focusModeToggled:
                state.focusModeEnabled.toggle()
                return .none

            case .networkStatusChanged(let isOnline):
                state.isOnline = isOnline
                return .none
            }
        }
    }
}
```

**Step 3: Build to verify no errors**

Run: Product → Build (Cmd+B)

Expected: Build succeeds

**Step 4: Commit AppFeature**

```bash
git add NoteApp/App/AppFeature.swift
git commit -m "feat: create root AppFeature with TCA structure

- Define AppFeature.State with focus mode, sync, and network state
- Define AppFeature.Action for app-level events
- Implement reducer with pure state transformations
- Placeholder for child feature composition (Phase 3+)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_4 -->

<!-- START_TASK_5 -->
### Task 5: Update App Entry Point with Store

**Files:**
- Modify: `NoteApp/NoteAppApp.swift` (default Xcode-generated file)

**Step 1: Update NoteAppApp.swift with TCA Store**

Replace the entire contents of `NoteApp/NoteAppApp.swift` with:

```swift
import SwiftUI
import ComposableArchitecture

@main
struct NoteAppApp: App {
    let store = Store(
        initialState: AppFeature.State(),
        reducer: { AppFeature() }
    )

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
```

**Step 2: Create AppView.swift**

In Xcode:
1. Right-click `App/` group → New File
2. Select "Swift File"
3. Name: `AppView.swift`
4. Create

Add content to `AppView.swift`:

```swift
import SwiftUI
import ComposableArchitecture

struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("reMarkable iPad Note App")
                    .font(.largeTitle)

                Text("Phase 1: Project Setup Complete")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: store.isOnline ? "wifi" : "wifi.slash")
                        Text(store.isOnline ? "Online" : "Offline")
                    }

                    HStack {
                        Image(systemName: store.focusModeEnabled ? "moon.fill" : "sun.max.fill")
                        Text("Focus Mode: \(store.focusModeEnabled ? "On" : "Off")")
                    }

                    if let lastSync = store.lastSyncDate {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Last sync: \(lastSync, style: .relative)")
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)

                Button {
                    store.send(.focusModeToggled)
                } label: {
                    Label("Toggle Focus Mode", systemImage: "moon.fill")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Text("Library, Editor, and Organization features coming in Phase 2-8")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .onAppear {
                store.send(.onAppear)
            }
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

**Step 3: Build and run on iPad simulator**

1. Select iPad simulator (iPad Pro 12.9-inch or similar)
2. Product → Run (Cmd+R)

Expected: App launches, shows:
- "reMarkable iPad Note App" title
- "Phase 1: Project Setup Complete" subtitle
- Network status (Online/Offline)
- Focus Mode status
- Toggle Focus Mode button (functional)
- Placeholder message for future phases

**Step 4: Test Focus Mode toggle**

Tap "Toggle Focus Mode" button

Expected: Focus Mode status changes from Off → On → Off (functional state management via TCA)

**Step 5: Commit app entry point**

```bash
git add NoteApp/NoteAppApp.swift NoteApp/App/AppView.swift
git commit -m "feat: initialize TCA Store and create root AppView

- Update @main entry point with Store initialization
- Create AppView with TCA bindings
- Display app-level state (network, focus mode, sync)
- Add functional Focus Mode toggle demonstrating TCA actions
- Include SwiftUI preview for development
- Phase 1 complete: app builds and runs on iPad simulator

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

<!-- END_TASK_5 -->

---

## Phase 1 Complete

**Verification Checklist:**
- ✓ Xcode project builds successfully
- ✓ TCA dependency resolves and imports
- ✓ App launches on iPad simulator (iOS 17+)
- ✓ AppFeature.State observable and reactive
- ✓ Store dispatches actions correctly
- ✓ Focus Mode toggle demonstrates TCA state management
- ✓ Directory structure ready for Phase 2-8

**Next Phase:** Phase 2 - Data Models & SwiftData Persistence (Models, Repositories, CloudKit configuration)
