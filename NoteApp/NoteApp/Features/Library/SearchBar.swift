import SwiftUI
import ComposableArchitecture

struct SearchBar: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        TextField("Search notes...", text: $store.searchQuery.sending(\.searchQueryChanged))
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)
            .padding(.vertical, 8)
    }
}
