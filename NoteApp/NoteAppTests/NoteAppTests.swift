//
//  NoteAppTests.swift
//  NoteAppTests
//
//  Created by david.hagerty on 1/30/26.
//

import Testing
import ComposableArchitecture
@testable import NoteApp

struct AppFeatureTests {

    @Test func focusModeToggled() async {
        let store = TestStore(
            initialState: AppFeature.State(
                focusModeEnabled: false,
                lastSyncDate: nil,
                isOnline: true
            ),
            reducer: { AppFeature() }
        )

        await store.send(.focusModeToggled) {
            $0.focusModeEnabled = true
        }

        await store.send(.focusModeToggled) {
            $0.focusModeEnabled = false
        }
    }

    @Test func networkStatusChanged() async {
        let store = TestStore(
            initialState: AppFeature.State(
                focusModeEnabled: false,
                lastSyncDate: nil,
                isOnline: true
            ),
            reducer: { AppFeature() }
        )

        await store.send(.networkStatusChanged(false)) {
            $0.isOnline = false
        }

        await store.send(.networkStatusChanged(true)) {
            $0.isOnline = true
        }
    }

    @Test func onAppear() async {
        let store = TestStore(
            initialState: AppFeature.State(
                focusModeEnabled: false,
                lastSyncDate: nil,
                isOnline: true
            ),
            reducer: { AppFeature() }
        )

        await store.send(.onAppear)
    }
}
