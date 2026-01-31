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
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private // Private database for user's personal notes
            )

            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Initialize TCA store
            self.store = Store(
                initialState: AppFeature.State(),
                reducer: { AppFeature() }
            )
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
