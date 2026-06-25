import Testing
import Foundation
@testable import ConnectSDK

@Suite("AssetBalance model")
struct BalanceFlowTests {

    @Test("round-trips through Codable with optionals present")
    func roundTripFull() throws {
        let b = AssetBalance(
            key: "BTC", label: "Bitcoin", amount: "0.5", notional: "30000",
            currency: "USD", totalStakedPercent: "12.5", precision: 8,
            extractedAt: "2026-06-16T00:00:00Z")
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(AssetBalance.self, from: data)
        #expect(decoded == b)
    }

    @Test("round-trips with nil optionals")
    func roundTripNils() throws {
        let b = AssetBalance(
            key: "USD", label: "US Dollar", amount: "100", notional: "100",
            currency: nil, totalStakedPercent: nil, precision: nil,
            extractedAt: "2026-06-16T00:00:00Z")
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(AssetBalance.self, from: data)
        #expect(decoded == b)
        #expect(decoded.currency == nil)
    }
}
