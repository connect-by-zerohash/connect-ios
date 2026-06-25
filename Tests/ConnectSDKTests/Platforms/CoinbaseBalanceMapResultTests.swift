import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("Coinbase mapBalances")
struct CoinbaseBalanceMapResultTests {

    @Test("maps a crypto row with all fields")
    func mapsCryptoRow() throws {
        let raw: [String: Any] = ["balances": [[
            "key": "BTC", "label": "Bitcoin", "amount": "0.5", "notional": "30000",
            "currency": "USD", "totalStakedPercent": "12.5", "precision": NSNull(),
            "extractedAt": "2026-06-16T00:00:00Z"
        ]]]
        let out = try Coinbase.mapBalances(raw)
        #expect(out.count == 1)
        #expect(out[0].key == "BTC")
        #expect(out[0].currency == "USD")
        #expect(out[0].totalStakedPercent == "12.5")
        #expect(out[0].precision == nil)
    }

    @Test("maps a cash row with null optionals")
    func mapsCashRow() throws {
        let raw: [String: Any] = ["balances": [[
            "key": "USDC", "label": "USD Coin", "amount": "100", "notional": "100",
            "currency": NSNull(), "totalStakedPercent": NSNull(), "precision": NSNull(),
            "extractedAt": "2026-06-16T00:00:00Z"
        ]]]
        let out = try Coinbase.mapBalances(raw)
        #expect(out.count == 1)
        #expect(out[0].currency == nil)
        #expect(out[0].totalStakedPercent == nil)
    }

    @Test("empty balances array maps to empty result (authoritative zero)")
    func mapsEmpty() throws {
        let out = try Coinbase.mapBalances(["balances": [[String: Any]]()])
        #expect(out.isEmpty)
    }

    @Test("missing balances key throws invalidJSReturn")
    func throwsOnMissingKey() {
        #expect(throws: PlatformError.invalidJSReturn) {
            _ = try Coinbase.mapBalances(["nope": 1])
        }
    }

    @Test("row missing a required string throws invalidJSReturn")
    func throwsOnMalformedRow() {
        let raw: [String: Any] = ["balances": [["key": "BTC"]]] // missing label/amount/...
        #expect(throws: PlatformError.invalidJSReturn) {
            _ = try Coinbase.mapBalances(raw)
        }
    }
}
