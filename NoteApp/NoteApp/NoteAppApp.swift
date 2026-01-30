//
//  NoteAppApp.swift
//  NoteApp
//
//  Created by david.hagerty on 1/30/26.
//

import SwiftUI
import ComposableArchitecture

/// NoteAppApp - Imperative Shell
/// App entry point that initializes the root TCA Store.
/// Bootstraps the app by creating the initial state and connecting the root reducer.
@main
struct NoteAppApp: App {
    let store = Store(
        initialState: AppFeature.State(),
        reducer: { AppFeature() }
    )

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
