//
//  NoteAppTests.swift
//  NoteAppTests
//
//  Created by david.hagerty on 1/30/26.
//

import Testing
import ComposableArchitecture
import Foundation
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

    @Test func cloudKitSyncEventSuccess() async {
        let store = TestStore(
            initialState: AppFeature.State(
                focusModeEnabled: false,
                lastSyncDate: nil,
                isOnline: true
            ),
            reducer: { AppFeature() }
        )

        let now = Date()
        await store.send(.cloudKitSyncEvent(.success(now))) {
            $0.lastSyncDate = now
            $0.syncError = nil
        }
    }

    @Test func cloudKitSyncEventFailure() async {
        let store = TestStore(
            initialState: AppFeature.State(
                focusModeEnabled: false,
                lastSyncDate: nil,
                isOnline: true
            ),
            reducer: { AppFeature() }
        )

        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        await store.send(.cloudKitSyncEvent(.failure(error))) {
            $0.syncError = "Test error"
        }
    }
}
