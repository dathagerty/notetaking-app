import SwiftUI
import ComposableArchitecture

/// AppView - Imperative Shell
/// SwiftUI view presenting app state and dispatching actions to the store.
/// All UI rendering is driven by reactive state bindings to the TCA store.
struct AppView: View {
    @Bindable var store: StoreOf<AppFeature>

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("reMarkable iPad Note App")
                    .font(.largeTitle)

                Text("Phase 2: Data Models Complete")
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
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    store.send(.focusModeToggled)
                } label: {
                    Label("Toggle Focus Mode", systemImage: "moon.fill")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
