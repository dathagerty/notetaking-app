import SwiftUI

struct NoteRowView: View {
    let note: NoteViewModel
    let isConverting: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.headline)

                Text(note.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isConverting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
