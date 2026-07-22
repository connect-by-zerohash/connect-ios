//
//  ConnectSDKMainTests.swift
//  ConnectSDK
//

import Foundation
import Testing
import AuthenticationServices
import WebKit
@testable import ConnectSDK

@MainActor
struct ConnectSDKConfigurationTests {

    @Test("ConnectSDK configureAuth with all parameters succeeds")
    func testConfigureAuthAllParameters() {
        let callbacks = MockData.callbacksWithAllHandlers
        let session = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: callbacks,
            oauthCallback: .default
        )

        #expect(session != nil)
    }

    @Test("ConnectSDK configureAuth with default parameters succeeds")
    func testConfigureAuthDefaults() {
        let session = ConnectSDK.configureAuth(jwt: MockData.validJWT, oauthCallback: .default)

        #expect(session != nil)
    }

    @Test("ConnectSDK configureAuth with production environment")
    func testConfigureAuthProduction() {
        let session = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            environment: .production,
            oauthCallback: .default
        )

        #expect(session != nil)
    }

    @Test("ConnectSDK configureAuth with different themes")
    func testConfigureAuthDifferentThemes() {
        let lightSession = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            theme: .light,
            oauthCallback: .default
        )
        let darkSession = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            theme: .dark,
            oauthCallback: .default
        )
        let systemSession = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            theme: .system,
            oauthCallback: .default
        )

        #expect(lightSession != nil)
        #expect(darkSession != nil)
        #expect(systemSession != nil)
    }

    @Test("ConnectSDK configureAuth returns ConnectAuthSession type")
    func testConfigureAuthReturnType() {
        let session = ConnectSDK.configureAuth(jwt: MockData.validJWT, oauthCallback: .default)

        #expect(session is ConnectAuthSession)
    }

    @Test("ConnectSDK multiple configureAuth calls create different sessions")
    func testMultipleConfigureCalls() {
        let session1 = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            oauthCallback: .default
        )
        let session2 = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            environment: .production,
            theme: .dark,
            oauthCallback: .default
        )

        #expect(session1 !== session2)
    }

    @Test("ConnectSDK configureAuth with various callback combinations")
    func testConfigureAuthDifferentCallbacks() {
        let session1 = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            callbacks: MockData.callbacksWithCloseOnly,
            oauthCallback: .default
        )
        let session2 = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            callbacks: MockData.callbacksWithErrorOnly,
            oauthCallback: .default
        )
        let session3 = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            callbacks: MockData.callbacksWithAllHandlers,
            oauthCallback: .default
        )

        #expect(session1 != nil)
        #expect(session2 != nil)
        #expect(session3 != nil)
    }
}

@MainActor
struct ConnectSDKIntegrationTests {

    @Test("ConnectSDK configured session can be presented")
    func testConfiguredSessionPresentation() {
        let session = ConnectSDK.configureAuth(jwt: MockData.validJWT, oauthCallback: .default)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectSDK configured session can be cancelled")
    func testConfiguredSessionCancellation() {
        let session = ConnectSDK.configureAuth(jwt: MockData.validJWT, oauthCallback: .default)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)
        session.cancel()

        #expect(session.isActive == false)
    }

    @Test("ConnectSDK complete flow with configuration")
    func testCompleteFlowWithConfiguration() {
        let callbacks = MockData.callbacksWithAllHandlers
        let session = ConnectSDK.configureAuth(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: callbacks,
            oauthCallback: .default
        )
        let presenter = MockUIViewController()

        // Configure
        #expect(session != nil)

        // Present
        let result = session.present(from: presenter)
        #expect(result != nil)
        #expect(session.isActive == true)

        // Cancel
        session.cancel()
        #expect(session.isActive == false)
    }
}

@MainActor
struct ConnectSDKClearWebsiteDataTests {

    @Test("clearWebsiteData leaves the SDK-private store with zero data records")
    func testClearLeavesStoreEmpty() async {
        await ConnectSDK.clearWebsiteData()

        let store = WKWebsiteDataStore(forIdentifier: SDKDataStoreIdentifier.shared)
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        #expect(records.isEmpty)
    }

    @Test("clearWebsiteData targets the SDK-private store, not WKWebsiteDataStore.default()")
    func testClearDoesNotTouchDefaultStore() async {
        // Sanity: the identifier-based store the API clears is not the process-wide default.
        let store = WKWebsiteDataStore(forIdentifier: SDKDataStoreIdentifier.shared)
        #expect(store !== WKWebsiteDataStore.default())
        // Clearing should succeed without throwing even if the store has no records.
        await ConnectSDK.clearWebsiteData()
    }

    @Test("clearWebsiteData is idempotent")
    func testClearIsIdempotent() async {
        await ConnectSDK.clearWebsiteData()
        await ConnectSDK.clearWebsiteData()

        let store = WKWebsiteDataStore(forIdentifier: SDKDataStoreIdentifier.shared)
        let records = await store.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
        #expect(records.isEmpty)
    }
}
