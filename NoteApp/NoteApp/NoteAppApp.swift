//
//  NoteAppApp.swift
//  NoteApp
//
//  Created by david.hagerty on 1/30/26.
//

import SwiftUI
import ComposableArchitecture

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
