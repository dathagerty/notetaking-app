import SwiftUI
import ComposableArchitecture

// FCIS: Imperative Shell (view layer for tag filter UI with horizontal scrolling)
struct TagFilterBar: View {
    @Bindable var store: StoreOf<LibraryFeature>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(store.allTags, id: \.id) { tag in
                    TagChip(
                        tag: tag,
                        isSelected: store.selectedTags.contains(tag)
                    ) {
                        store.send(.tagToggled(tag))
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 40)
    }
}

struct TagChip: View {
    let tag: TagViewModel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(tag.name)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
