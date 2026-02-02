import SwiftUI
import ComposableArchitecture

// FCIS: Imperative Shell (view layer for search UI with text input binding)
struct SearchBar: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        TextField("Search notes...", text: $store.searchQuery.sending(\.searchQueryChanged))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}
