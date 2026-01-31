import ComposableArchitecture
import Foundation

/// AppFeature - Functional Core
/// Pure reducer managing app-level state and actions.
/// All state transformations are deterministic functions of (State, Action) -> (State, Effect).
/// Side effects handled through effects in the reducer body.
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

    var body: some Reducer<State, Action> {
        Scope(state: \.library, action: \.library) {
            LibraryFeature()
        }

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

            case .library:
                return .none
            }
        }
    }
}
