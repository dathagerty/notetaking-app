# reMarkable-like iPad Note-Taking App Design

## Summary

This design describes a reMarkable-inspired note-taking app for iPad that prioritizes focused, distraction-free writing with Apple Pencil. The app uses **The Composable Architecture (TCA)** to manage application state and side effects across four feature domains: the root app coordinator, a library for browsing notebooks and notes, a full-screen note editor powered by PencilKit, and organization capabilities (tags, search, handwriting recognition). Data persists locally using SwiftData with automatic iCloud synchronization via NSPersistentCloudKitContainer, following a local-first architecture that works fully offline.

The defining characteristic is the **strict single-task navigation model**: once a user enters a note, all navigation UI automatically hides after 3 seconds, forcing deliberate friction to switch contexts (double-tap the top edge to reveal navigation temporarily). This mimics the reMarkable tablet's physical constraint of showing one notebook at a time. Organization features—hierarchical folders, tag filtering, search, and handwriting-to-text conversion—exist exclusively in the Library view. Notes support inline hashtag tagging (#meeting, #ideas) that the Vision framework automatically detects during auto-save. Export capabilities use standard iOS share sheets to output PDFs or images. The implementation follows eight discrete phases, from TCA foundation through error handling and offline support, with each phase having clear verification criteria.

## Definition of Done

This design is complete when:

- Architecture clearly defines TCA feature structure with App, Library, NoteEditor, and Organization features
- Data model specifies SwiftData entities (Notebook, Note, Tag) with relationships and CloudKit sync strategy
- PencilKit integration approach documented with auto-save and debouncing strategy
- Strict single-task navigation model defined with deliberate friction for switching contexts
- Inline hashtag tagging mechanism specified with Vision framework integration timing
- Organization features (hierarchical folders, tags, search, handwriting-to-text) scoped to Library view
- Export capabilities defined (PDF/image via iOS share sheet)
- CloudKit sync strategy documented (local-first with automatic NSPersistentCloudKitContainer sync)
- Error handling and offline support patterns established
- Implementation broken into discrete phases with clear dependencies and verification criteria

## Glossary

- **TCA (The Composable Architecture)**: Redux-inspired state management framework for SwiftUI apps. Enforces unidirectional data flow through pure Reducers that transform State based on Actions, with side effects isolated in Effects.
- **SwiftData**: Apple's modern persistence framework for iOS 17+ that uses Swift macros to define data models. Replaces Core Data with a more ergonomic API.
- **PencilKit**: Apple's framework providing a canvas view (PKCanvasView) and drawing tools (PKToolPicker) optimized for Apple Pencil input. Handles touch prediction, palm rejection, and low-latency rendering.
- **CloudKit**: Apple's cloud storage service that syncs data across a user's devices via iCloud. Used here through NSPersistentCloudKitContainer for automatic background synchronization.
- **NSPersistentCloudKitContainer**: SwiftData/Core Data component that automatically synchronizes local database changes to CloudKit without manual network code.
- **PKDrawing**: PencilKit's data structure representing a drawing. Serializable to binary Data for persistence.
- **Vision framework**: Apple's machine learning framework for image analysis. Used here for handwriting recognition (VNRecognizeTextRequest) and text extraction from drawings.
- **Repository Pattern**: Architectural pattern that abstracts data access behind interfaces. Here, repositories wrap SwiftData queries to keep TCA reducers pure and testable.
- **Reducer**: In TCA, a pure function that takes current State and an Action, returning new State plus Effects to run. Core of business logic.
- **Effect**: In TCA, a representation of side effects (network calls, file I/O, timers). Produces Actions that feed back into Reducers.
- **Local-First**: Architecture pattern where data writes succeed immediately to local storage, with cloud sync happening asynchronously in the background. App remains functional offline.
- **UIViewRepresentable**: SwiftUI protocol for wrapping UIKit views (like PKCanvasView) to use within SwiftUI views.
- **Debouncing**: Delaying an action until a period of inactivity. Used here to auto-save 2 seconds after the user stops drawing, preventing excessive save operations.
- **Last-Write-Wins**: Conflict resolution strategy where the most recent change overwrites older changes, without attempting to merge. Default behavior for CloudKit sync.
- **FCIS (Functional Core, Imperative Shell)**: Design pattern separating pure business logic (functional core) from side effects (imperative shell). TCA naturally enforces this: Reducers are functional, Effects are imperative.
- **NavigationSplitView**: SwiftUI component providing iPad-optimized three-column layout (sidebar, content list, detail view).
- **PKToolPicker**: PencilKit's system-wide toolbar for selecting drawing tools (pen, pencil, marker, eraser). Shared across apps and persists tool selection.
- **VNRecognizeTextRequest**: Vision framework API for detecting and extracting text from images. Used to convert handwritten notes to searchable text.
- **NWPathMonitor**: Network framework API for monitoring network connectivity status (online/offline, Wi-Fi/cellular).
- **UIActivityViewController**: UIKit component providing iOS's native share sheet with options like AirDrop, Files app, Messages, etc.

## Architecture

### Overall System Structure

The app uses **The Composable Architecture (TCA)** to manage state, actions, and side effects across four primary feature domains:

```
AppFeature (Root)
├── focusModeEnabled: Bool
├── lastSyncDate: Date?
├── isOnline: Bool
└── library: LibraryFeature.State

LibraryFeature
├── notebooks: [Notebook]  // Hierarchical tree
├── selectedNotebook: Notebook?
├── searchQuery: String
├── selectedTags: Set<Tag>
└── noteEditor: NoteEditorFeature.State?

NoteEditorFeature
├── note: Note
├── drawing: PKDrawing
├── navigationVisible: Bool
└── showingExitConfirmation: Bool

OrganizationFeature (embedded in Library)
├── allTags: [Tag]
├── searchResults: [Note]
└── handwritingConversionState: ConversionState
```

### Data Flow

Unidirectional data flow following TCA principles:

1. **User Action** → Action dispatched to Store
2. **Reducer** → Pure function produces new State + Effects
3. **Effects** → Handle side effects (CloudKit sync, file I/O, Vision framework)
4. **State Update** → Views automatically re-render

Example: Drawing update flow
```
User draws on canvas
→ Action.drawingChanged(PKDrawing)
→ Reducer: state.currentDrawing = newDrawing
→ Effect: Debounced save (2 seconds)
→ Repository serializes PKDrawing to Data
→ SwiftData writes to local store
→ NSPersistentCloudKitContainer syncs to iCloud
→ Action.syncCompleted(Date)
→ Reducer: state.lastSyncDate = date
```

### Key Architectural Decisions

**TCA Feature Composition**: Features compose naturally. LibraryFeature contains NoteEditorFeature as optional child state, enabling navigation while maintaining isolation. Each feature owns its domain logic.

**Repository Pattern**: SwiftData queries wrapped in repository interfaces. Keeps reducers pure (no direct database access) and enables testing with mock repositories.

**Local-First Persistence**: All writes go to SwiftData immediately. CloudKit sync happens automatically in background via NSPersistentCloudKitContainer. App functions fully offline.

**Strict Single-Task Model**: Navigation deliberately hidden during note editing. User must explicitly invoke navigation (double-tap top edge) to switch contexts. Mimics reMarkable's physical device constraint.

**Side Effect Management**: All I/O, network operations, and async work handled via TCA's Effect system. Reducers remain pure functions for testability.

## Existing Patterns

This is a new project with no existing codebase. This design establishes initial patterns:

**TCA Architecture**: Redux-inspired unidirectional data flow with State, Action, Reducer, and Effect separation. Industry-standard pattern for complex SwiftUI apps.

**SwiftData + CloudKit**: Modern iOS persistence using SwiftData's automatic CloudKit sync via NSPersistentCloudKitContainer. Standard pattern for iOS 17+ apps requiring iCloud sync.

**Repository Pattern**: Abstraction over SwiftData queries. Common in TCA codebases to keep reducers pure and enable testing.

**PencilKit UIViewRepresentable**: Standard bridge between UIKit's PKCanvasView and SwiftUI. Coordinator pattern for delegate callbacks.

**FCIS (Functional Core, Imperative Shell)**: TCA reducers are pure functions (Functional Core). Effects handle side effects (Imperative Shell). Design enforces this separation naturally.

## Implementation Phases

<!-- START_PHASE_1 -->
### Phase 1: Project Setup & TCA Foundation

**Goal:** Initialize Xcode project with dependencies and basic TCA structure

**Components:**
- Xcode project at root with iPad deployment target iOS 17+
- Swift Package Manager dependencies: swift-composable-architecture
- `App/AppFeature.swift` — Root TCA feature with app-level state
- `App/NoteApp.swift` — SwiftUI app entry point with TCA Store
- Basic SwiftUI navigation structure (empty views)

**Dependencies:** None (first phase)

**Done when:** Project builds successfully, TCA store initializes, empty app launches on iPad simulator

<!-- END_PHASE_1 -->

<!-- START_PHASE_2 -->
### Phase 2: Data Models & SwiftData Persistence

**Goal:** Define core data model and establish local persistence with iCloud sync

**Components:**
- `Models/Notebook.swift` — SwiftData model with hierarchy support (parent/children relationships)
- `Models/Note.swift` — SwiftData model with drawing data, tags, timestamps
- `Models/Tag.swift` — SwiftData model with many-to-many Note relationships
- `Repositories/NoteRepository.swift` — Query abstraction over SwiftData
- `Repositories/NotebookRepository.swift` — Notebook CRUD operations
- `Repositories/TagRepository.swift` — Tag management and filtering
- SwiftData ModelContainer configuration with CloudKit private database enabled

**Dependencies:** Phase 1 (project structure)

**Done when:** SwiftData models persist locally, iCloud sync configuration active (verified by creating data on one simulator and seeing it appear on another after CloudKit sync), repository queries return correct data, all model relationships work correctly

<!-- END_PHASE_2 -->

<!-- START_PHASE_3 -->
### Phase 3: Library Feature with Navigation

**Goal:** Implement notebook/note browsing with hierarchical structure

**Components:**
- `Features/Library/LibraryFeature.swift` — TCA feature for notebook/note navigation
- `Features/Library/LibraryView.swift` — SwiftUI view with NavigationSplitView
- `Features/Library/NotebookListView.swift` — Hierarchical notebook tree in sidebar
- `Features/Library/NoteListView.swift` — Notes within selected notebook
- `Features/Library/NoteRowView.swift` — Individual note preview with title and timestamp
- Basic create/delete operations for notebooks and notes
- Navigation from note row → note editor (placeholder view)

**Dependencies:** Phase 2 (data models and repositories)

**Done when:** Can create nested notebooks, create notes within notebooks, navigate hierarchy with breadcrumbs, delete notebooks/notes with confirmation, navigation to note editor triggers (editor is placeholder), all CRUD operations persist via repositories

<!-- END_PHASE_3 -->

<!-- START_PHASE_4 -->
### Phase 4: PencilKit Note Editor

**Goal:** Full-featured note editing with PencilKit drawing and auto-save

**Components:**
- `Features/NoteEditor/NoteEditorFeature.swift` — TCA feature managing drawing state and auto-save
- `Features/NoteEditor/NoteEditorView.swift` — Full-screen canvas with minimal chrome
- `Features/NoteEditor/CanvasView.swift` — UIViewRepresentable wrapping PKCanvasView
- `Features/NoteEditor/CanvasCoordinator.swift` — Delegate handling drawing updates
- Debounced save effect (2 seconds after drawing stops)
- PKToolPicker integration with system-wide tool selection
- Drawing serialization via PKDrawing.dataRepresentation()

**Dependencies:** Phase 3 (library navigation to reach editor)

**Done when:** Can draw with Apple Pencil and finger (respecting drawing policy), tool picker appears and functions, drawing auto-saves after 2 seconds of inactivity, saved drawings persist and reload correctly, can navigate back to library with unsaved changes confirmation

<!-- END_PHASE_4 -->

<!-- START_PHASE_5 -->
### Phase 5: Strict Single-Task Navigation Model

**Goal:** Implement reMarkable-style focused navigation with deliberate friction

**Components:**
- Navigation bar auto-hide behavior (3 seconds after entering note)
- Edge double-tap gesture recognizer in `NoteEditorView.swift`
- Temporary navigation overlay with fade-in/fade-out animations
- Exit confirmation alert when leaving note with unsaved changes
- Navigation state management in `NoteEditorFeature.swift`
- Gesture-disabled SwiftUI navigation (no swipe-back)
- Hidden home indicator for immersive full-screen

**Dependencies:** Phase 4 (note editor must exist)

**Done when:** Navigation bar hides automatically after 3 seconds in note, double-tap top edge reveals navigation temporarily, cannot swipe back accidentally, exit button shows confirmation if changes exist, home indicator hidden during editing, navigation overlay fades after 5 seconds or when drawing resumes

<!-- END_PHASE_5 -->

<!-- START_PHASE_6 -->
### Phase 6: Tags, Search, and Organization

**Goal:** Full organization features in Library view with inline hashtag detection

**Components:**
- `Features/Library/SearchBar.swift` — Search query input with debouncing
- `Features/Library/TagFilterBar.swift` — Horizontal scrolling tag chips
- Tag filtering logic in `LibraryFeature.swift` (multi-select with AND logic)
- Search implementation across note titles and searchableText
- Vision framework integration in `NoteEditorFeature.swift` for hashtag detection
- Hashtag extraction during auto-save (runs alongside drawing persistence)
- Tag badge in note editor showing active tags
- Tag creation from detected hashtags
- Long-press menu in library for manual tag management

**Dependencies:** Phase 5 (editor must have auto-save for hashtag detection)

**Done when:** Can search notes by title and recognized text, can filter by multiple tags simultaneously, hashtags written in notes automatically create/apply tags during auto-save, tag badge shows current tags in editor (tappable for temporary overlay), can manually add/remove tags from library long-press menu, search and tag filters combine correctly (AND logic)

<!-- END_PHASE_6 -->

<!-- START_PHASE_7 -->
### Phase 7: Handwriting-to-Text Conversion & Export

**Goal:** Text recognition for search and PDF/image export

**Components:**
- `Services/HandwritingRecognition.swift` — Vision framework VNRecognizeTextRequest wrapper
- On-demand conversion trigger in library (long-press menu)
- Progress indicator during text recognition
- Export feature in `Features/Library/ExportFeature.swift`
- PDF generation from PKDrawing via image rendering
- Image export with resolution selection (1x, 2x, 3x)
- iOS share sheet integration (UIActivityViewController bridge)
- Batch export for multiple notes (creates ZIP)
- File naming logic with note title and date

**Dependencies:** Phase 6 (tags and search must exist)

**Done when:** Long-press note in library shows "Convert Handwriting" option, Vision framework processes drawing and extracts text to searchableText, progress indicator appears during conversion, search finds notes by converted text, can export single note as PDF or image, can export multiple notes as ZIP, share sheet appears with Files app and AirDrop options, exported files have meaningful names

<!-- END_PHASE_7 -->

<!-- START_PHASE_8 -->
### Phase 8: Error Handling, Offline Support, and Polish

**Goal:** Robust error handling, network state management, and final UX refinements

**Components:**
- Network monitoring via NWPathMonitor in `AppFeature.swift`
- Sync state tracking (lastSyncDate, isSyncing, syncError)
- CloudKit notification observers for sync events
- Error alert presentation in TCA features (PresentationState pattern)
- Offline badge in library when network unavailable
- Save failure recovery (retry with exponential backoff)
- Export error handling with retry options
- Vision framework error handling (silent failure for non-critical hashtags)
- Sync status indicator in library ("Synced 5 min ago")
- Loading states for all async operations
- Accessibility labels and VoiceOver support

**Dependencies:** Phase 7 (all features must exist)

**Done when:** App functions fully offline (all features work without network), network status visible in library, sync errors show actionable alerts, save failures retry automatically and show user alert if retry fails, export errors offer retry option, Vision framework failures don't crash or disrupt drawing, sync status always visible in library, all interactive elements have accessibility labels, VoiceOver navigation works correctly

<!-- END_PHASE_8 -->

## Additional Considerations

### CloudKit Quotas

Free iCloud tier provides 1 GB storage and 10 GB monthly transfer. PKDrawing data ranges 1-5 MB per complex page. This supports approximately 200-1000 notes comfortably within free tier. No quota management needed at MVP—users hitting limits will see system iCloud storage alerts.

### Conflict Resolution

SwiftData with NSPersistentCloudKitContainer uses **last-write-wins** conflict resolution by default. For single-user note-taking, this is acceptable—conflicts are rare (same note edited on two devices simultaneously). No custom conflict resolution implemented at MVP.

### Privacy

All data stored in iCloud private database (user's personal storage). No data leaves user's iCloud account. No analytics or telemetry. Export generates local files; user controls sharing via iOS share sheet.

### Performance

PencilKit optimized by Apple for iPad Pro—no custom performance tuning needed. SwiftData with CloudKit handles datasets of 10,000+ notes efficiently. Debounced save (2 seconds) prevents excessive I/O during active drawing.

### Testing Strategy

- **Reducers**: Pure functions tested with unit tests (input state + action → output state)
- **Effects**: Tested with mock repositories and schedulers
- **UI**: SwiftUI preview-driven development for rapid iteration
- **Integration**: Manual testing on physical iPad with Apple Pencil for drawing feel
- **Sync**: Testing across two simulators with same iCloud account

### Implementation Scoping

This design has 8 phases exactly, matching the writing-plans skill limit. All phases are required for MVP functionality.
