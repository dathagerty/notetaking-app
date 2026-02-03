import SwiftUI
import UIKit

// FCIS: Imperative Shell (UIKit bridge) for UIActivityViewController integration
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        activityVC.completionWithItemsHandler = { _, _, _, _ in
            onDismiss()
        }

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
