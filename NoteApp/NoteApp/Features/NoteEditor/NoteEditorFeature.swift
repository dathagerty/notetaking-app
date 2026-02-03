import ComposableArchitecture
import PencilKit
import Foundation

// FCIS: Functional Core (reducer logic) with Imperative Shell (TCA integration)
// Manages note editing state: drawing changes, persistence, and exit confirmation

@Reducer
struct NoteEditorFeature {
    @ObservableState
    struct State: Equatable {
        var noteId: UUID
        var noteTitle: String
        var drawing: PKDrawing
        var hasUnsavedChanges: Bool = false
        var isSaving: Bool = false
        var navigationVisible: Bool = true
        var detectedTags: Set<String> = []
        var saveAttempts: Int = 0
        var saveError: String?
        @Presents var exitConfirmation: ConfirmationDialogState<ExitConfirmation>?
        @Presents var saveErrorAlert: AlertState<Action.SaveErrorAlert>?
    }

    @CasePathable
    enum Delegate: Equatable, Sendable {
        case closeRequested
    }

    @CasePathable
    enum ExitConfirmation: Equatable, Sendable {
        case confirmExit
        case cancelExit
    }

    @CasePathable
    enum Action {
        case onAppear
        case drawingLoaded(PKDrawing)
        case drawingChanged(PKDrawing)
        case saveDrawing
        case drawingSaved
        case saveFailed(String)
        case tagSaveFailed(String)
        case tagsDetected(Set<String>)
        case closeButtonTapped
        case exitConfirmation(PresentationAction<ExitConfirmation>)
        case saveErrorAlert(PresentationAction<SaveErrorAlert>)
        case hideNavigationAfterDelay
        case showNavigationTemporarily
        case hideNavigation
        case gestureDetected(GestureType)
        case delegate(Delegate)

        enum SaveErrorAlert: Equatable, Sendable {
            case retry
            case discard
        }
    }

    enum GestureType {
        case topEdgeDoubleTap
        case drawingStarted
    }

    @Dependency(\.noteRepository) var noteRepo
    @Dependency(\.tagRepository) var tagRepo
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let noteId = state.noteId
                return .run { send in
                    do {
                        if let note = try await noteRepo.fetchNote(id: noteId),
                           let drawingData = note.drawingData {
                            let drawing = try PKDrawing(data: drawingData)
                            await send(.drawingLoaded(drawing))
                        } else {
                            await send(.drawingLoaded(PKDrawing()))
                        }
                    } catch {
                        await send(.drawingLoaded(PKDrawing()))
                    }
                }

            case .drawingLoaded(let drawing):
                state.drawing = drawing
                return .none

            case .drawingChanged(let newDrawing):
                state.drawing = newDrawing
                state.hasUnsavedChanges = true

                // Debounced auto-save (2 seconds after drawing stops)
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.saveDrawing)
                }
                .cancellable(id: "NoteEditorSave", cancelInFlight: true)

            case .saveDrawing:
                guard state.hasUnsavedChanges else { return .none }
                state.isSaving = true

                let drawing = state.drawing
                let noteId = state.noteId

                return .run { send in
                    do {
                        // STEP 1: Save drawing first (critical data)
                        let data = drawing.dataRepresentation()

                        if let note = try await noteRepo.fetchNote(id: noteId) {
                            note.drawingData = data
                            note.updatedAt = Date()
                            try await noteRepo.updateNote(note)
                        }

                        // STEP 2: Extract and attach tags (non-critical)
                        // Even if tag operations fail, drawing is safely saved
                        do {
                            let extractor = HashtagExtractor()
                            let detectedTags = try await extractor.extractHashtags(from: drawing)

                            // Update UI with detected tags
                            await send(.tagsDetected(detectedTags))

                            // Create/fetch tags and attach to note
                            var tags: [Tag] = []
                            for tagName in detectedTags {
                                let tag = try await tagRepo.fetchOrCreateTag(name: tagName)
                                tags.append(tag)
                            }

                            // Update note with tags
                            if let note = try await noteRepo.fetchNote(id: noteId) {
                                note.tags = tags
                                try await noteRepo.updateNote(note)
                            }
                        } catch {
                            // Log tag failure but don't fail the save
                            await send(.tagSaveFailed(error.localizedDescription))
                        }

                        await send(.drawingSaved)
                    } catch {
                        await send(.saveFailed(error.localizedDescription))
                    }
                }

            case .tagsDetected(let tags):
                state.detectedTags = tags
                return .none

            case .tagSaveFailed(let message):
                // Log warning but don't fail the save since drawing was already saved
                // In a full app, this could send to error tracking service
                print("Warning: Tag save failed: \(message)")
                return .none

            case .drawingSaved:
                state.hasUnsavedChanges = false
                state.isSaving = false
                state.saveAttempts = 0  // Reset attempts on success
                state.saveError = nil
                return .cancel(id: "NoteEditorRetry")

            case .saveFailed(let error):
                state.isSaving = false

                // Auto-retry with exponential backoff
                let attempt = state.saveAttempts
                let delay = min(pow(2.0, Double(attempt)), 60.0)  // Max 60 seconds

                state.saveAttempts += 1

                if state.saveAttempts < 3 {
                    // Retry automatically
                    return .run { send in
                        try await clock.sleep(for: .seconds(delay))
                        await send(.saveDrawing)
                    }
                    .cancellable(id: "NoteEditorRetry", cancelInFlight: true)
                } else {
                    // Max retries reached, show alert
                    let errorMessage = "Failed to save after \(attempt) attempts: \(error)"
                    state.saveError = errorMessage
                    state.saveErrorAlert = AlertState {
                        TextState("Save Failed")
                    } actions: {
                        ButtonState(action: .retry) {
                            TextState("Retry")
                        }
                        ButtonState(role: .destructive, action: .discard) {
                            TextState("Discard Changes")
                        }
                    } message: {
                        TextState(errorMessage)
                    }
                    return .none
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
                return .send(.delegate(.closeRequested))

            case .exitConfirmation(.presented(.confirmExit)):
                return .send(.delegate(.closeRequested))

            case .exitConfirmation(.presented(.cancelExit)):
                return .none

            case .exitConfirmation(.dismiss):
                return .none

            case .saveErrorAlert(.presented(.retry)):
                state.saveAttempts = 0  // Reset attempts to retry from beginning
                state.saveError = nil
                return .send(.saveDrawing)

            case .saveErrorAlert(.presented(.discard)):
                state.hasUnsavedChanges = false
                state.saveAttempts = 0
                state.saveError = nil
                return .none

            case .saveErrorAlert(.dismiss):
                return .none

            case .hideNavigationAfterDelay:
                // Sleep is wrapped in cancellable effect. Task cancellation (e.g., when navigation is
                // shown again) will interrupt sleep and prevent duplicate hideNavigation actions.
                return .run { send in
                    try await clock.sleep(for: .seconds(3))
                    await send(.hideNavigation)
                }
                .cancellable(id: "NavigationHide", cancelInFlight: true)

            case .showNavigationTemporarily:
                state.navigationVisible = true
                // Sleep is wrapped in cancellable effect. If user taps again before 5s timeout,
                // the previous effect is cancelled and a new timer starts.
                return .run { send in
                    try await clock.sleep(for: .seconds(5))
                    await send(.hideNavigation)
                }
                .cancellable(id: "NavigationHide", cancelInFlight: true)

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

            case .delegate:
                // Handled by parent
                return .none
            }
        }
        .ifLet(\.$exitConfirmation, action: \.exitConfirmation)
        .ifLet(\.$saveErrorAlert, action: \.saveErrorAlert)
    }
}
