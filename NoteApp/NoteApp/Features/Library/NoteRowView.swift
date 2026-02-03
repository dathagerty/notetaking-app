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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note: \(note.title.isEmpty ? "Untitled" : note.title)")
        .accessibilityHint("Created \(relativeDateString(note.createdAt)). Double tap to open.")
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
