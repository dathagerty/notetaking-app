import SwiftUI
import ComposableArchitecture

/// AppView - Imperative Shell
/// SwiftUI view presenting app state and dispatching actions to the store.
/// All UI rendering is driven by reactive state bindings to the TCA store.
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        LibraryView(
            store: store.scope(
                state: \.library,
                action: \.library
            )
        )
        .onAppear {
            store.send(.onAppear)
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
