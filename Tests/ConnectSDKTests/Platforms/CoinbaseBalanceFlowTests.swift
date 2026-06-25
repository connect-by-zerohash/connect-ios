import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("Coinbase getBalance flow")
struct CoinbaseBalanceFlowTests {

    @Test("runs ONE visible page load (/home) replaying both ops, concatenated")
    func runsOneLoadAndConcatenates() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        // A single page load now replays both CryptoQuery and CashQuery in-page
        // and returns the concatenated balances, so the mock yields one outcome.
        ctx.visibleOutcomes = [
            .success(["balances": [
                ["key": "BTC", "label": "Bitcoin", "amount": "0.5", "notional": "30000",
                 "currency": "USD", "totalStakedPercent": NSNull(), "precision": NSNull(),
                 "extractedAt": "2026-06-16T00:00:00Z"],
                ["key": "USDC", "label": "USDC", "amount": "100", "notional": "100",
                 "currency": NSNull(), "totalStakedPercent": NSNull(), "precision": NSNull(),
                 "extractedAt": "2026-06-16T00:00:00Z"]
            ]])
        ]
        let out = try await p.getBalance(ctx: ctx, overlay: .default, showOverlay: true)
        #expect(ctx.visibleCalls.count == 1)
        #expect(ctx.visibleCalls[0].url.absoluteString == "https://www.coinbase.com/home")
        #expect(out.map(\.key) == ["BTC", "USDC"])
        // Both ops are requested via the BOUND-ARGUMENT channel: never
        // interpolated into the injected script source.
        #expect(!ctx.visibleCalls[0].script.contains("\"ops\":[\"CryptoQuery\",\"CashQuery\"]"))
        let params = ctx.visibleCalls[0].arguments["params"] as? [String: Any]
        #expect(params?["ops"] as? [String] == ["CryptoQuery", "CashQuery"])
    }

    @Test("nil JS result (not logged in) throws underlying not-logged-in")
    func notLoggedInThrows() async {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleOutcomes = [.success(nil)]
        await #expect(throws: PlatformError.underlying("not logged in")) {
            _ = try await p.getBalance(ctx: ctx, overlay: .default, showOverlay: true)
        }
    }
}
