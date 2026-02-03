import ComposableArchitecture
import Foundation
import Network

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
        var syncError: String?

        // Phase 3: Library feature
        var library: LibraryFeature.State = .init()
    }

    enum Action {
        case onAppear
        case focusModeToggled
        case startNetworkMonitoring
        case networkStatusChanged(Bool)
        case cloudKitSyncEvent(Result<Date, Error>)

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
                return .send(.startNetworkMonitoring)

            case .focusModeToggled:
                state.focusModeEnabled.toggle()
                return .none

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
                    do {
                        try await withTaskCancellationHandler {
                            try await Task.never()
                        } onCancel: {
                            monitor.cancel()
                        }
                    } catch {}
                }

            case .networkStatusChanged(let isOnline):
                state.isOnline = isOnline
                state.library.isOnline = isOnline
                return .none

            case .cloudKitSyncEvent(.success(let date)):
                state.lastSyncDate = date
                state.syncError = nil
                state.library.lastSyncDate = date
                state.library.syncError = nil
                return .none

            case .cloudKitSyncEvent(.failure(let error)):
                state.syncError = error.localizedDescription
                state.library.syncError = error.localizedDescription
                return .none

            case .library:
                return .none
            }
        }
    }
}
