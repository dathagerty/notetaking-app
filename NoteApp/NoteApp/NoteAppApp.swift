//
//  NoteAppApp.swift
//  NoteApp
//
//  Created by david.hagerty on 1/30/26.
//

import SwiftUI
import SwiftData
import ComposableArchitecture

/// NoteAppApp - Imperative Shell
/// App entry point that initializes the root TCA Store and SwiftData ModelContainer.
/// Bootstraps the app by creating the initial state, configuring persistence, and connecting the root reducer.
@main
struct NoteAppApp: App {
    let modelContainer: ModelContainer
    let store: StoreOf<AppFeature>

    init() {
        // Configure SwiftData with CloudKit sync
        do {
            let schema = Schema([
                Notebook.self,
                Note.self,
                Tag.self
            ])

            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            // Note: CloudKit configuration happens automatically with entitlements

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Provide ModelContext to TCA dependency system
            let modelContext = ModelContext(modelContainer)

            self.store = Store(
                initialState: AppFeature.State(),
                reducer: { AppFeature() }
            ) {
                $0.modelContext = modelContext
            }
        } catch {
            fatalError("Failed to configure ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
        .modelContainer(modelContainer)
    }
}
