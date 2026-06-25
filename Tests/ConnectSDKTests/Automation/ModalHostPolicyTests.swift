import Testing
import Foundation
@testable import ConnectSDK

@Suite("ModalHostPolicy")
struct ModalHostPolicyTests {

    @Test("success host closes")
    func successCloses() {
        let p = ModalHostPolicy(stayOpenHosts: ["login.coinbase.com", "accounts.google.com"],
                                successHosts: ["www.coinbase.com"])
        #expect(p.decision(forHost: "www.coinbase.com") == .close)
    }

    @Test("stay-open host stays open")
    func stayOpenStays() {
        let p = ModalHostPolicy(stayOpenHosts: ["login.coinbase.com", "accounts.google.com"],
                                successHosts: ["www.coinbase.com"])
        #expect(p.decision(forHost: "accounts.google.com") == .stayOpen)
        #expect(p.decision(forHost: "login.coinbase.com") == .stayOpen)
    }

    @Test("nil or unknown host stays open (never a false success)")
    func unknownStaysOpen() {
        let p = ModalHostPolicy(stayOpenHosts: ["login.coinbase.com"],
                                successHosts: ["www.coinbase.com"])
        #expect(p.decision(forHost: nil) == .stayOpen)
        #expect(p.decision(forHost: "appleid.apple.com") == .stayOpen)
    }

    @Test("legacy single-host maps to stay-open=[host], success=anything-else")
    func legacyMapping() {
        let p = ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com")
        #expect(p.decision(forHost: "login.coinbase.com") == .stayOpen)
        #expect(p.decision(forHost: "www.coinbase.com") == .close)
        #expect(p.decision(forHost: nil) == .stayOpen)
    }
}
