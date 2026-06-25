import Testing
import WebKit
@testable import ConnectSDK

@MainActor
@Suite("SharedWebViewConfiguration")
struct SharedWebViewConfigurationTests {

    @Test("platformConfiguration shares the process pool and data store")
    func platformConfigShares() {
        let s = SharedWebViewConfiguration()
        let a = s.platformConfiguration()
        let b = s.platformConfiguration()
        #expect(a.processPool === b.processPool)
        #expect(a.websiteDataStore === b.websiteDataStore)
    }

    @Test("platformConfiguration installs no user scripts or message handlers")
    func platformConfigInstallsNothing() {
        let s = SharedWebViewConfiguration()
        let cfg = s.platformConfiguration()
        // Deposit-address extraction reads the rendered DOM directly, so the
        // shared platform config carries no injected user scripts. No script
        // message handlers are registered either (those would be added via
        // userContentController.add(_:name:), which platformConfiguration does
        // not call).
        #expect(cfg.userContentController.userScripts.isEmpty)
    }

    @Test("dataStore is the SDK-private identifier-based store, not .default()")
    func dataStoreIsSDKPrivate() {
        let s = SharedWebViewConfiguration()
        #expect(s.dataStore !== WKWebsiteDataStore.default())
        // Two `SharedWebViewConfiguration` instances within one process share
        // the same store because the identifier is persisted in UserDefaults.
        let s2 = SharedWebViewConfiguration()
        #expect(s.dataStore === s2.dataStore)
    }

    @Test("SDKDataStoreIdentifier returns the same UUID across calls within a process")
    func identifierStable() {
        let a = SDKDataStoreIdentifier.shared
        let b = SDKDataStoreIdentifier.shared
        #expect(a == b)
    }

    @Test("SDKDataStoreIdentifier persists across UserDefaults round-trips")
    func identifierPersists() {
        let suite = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let first = SDKDataStoreIdentifier.read(from: suite)
        let second = SDKDataStoreIdentifier.read(from: suite)
        #expect(first == second)
        // The key it writes under is documented and stable.
        #expect(suite.string(forKey: "xyz.connect.sdk.dataStoreId") != nil)
    }

    @Test("offscreenRunner is a single long-lived instance")
    func offscreenRunnerSingleton() {
        let s = SharedWebViewConfiguration()
        let a = s.offscreenRunner
        let b = s.offscreenRunner
        #expect(a === b)
    }
}
