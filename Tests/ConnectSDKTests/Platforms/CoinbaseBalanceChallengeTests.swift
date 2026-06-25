import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("Coinbase getBalance challenge retry")
struct CoinbaseBalanceChallengeTests {

    @Test("on CHALLENGE_PRESENT, re-loads once with overlay hidden then succeeds")
    func retriesWithOverlayHidden() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        // First load hits a challenge; the single retry reveals the page
        // (overlay off, waitForChallenge) and replays BOTH ops, returning the
        // concatenated balances — so the whole flow is two visible loads, not
        // four.
        ctx.visibleOutcomes = [
            .failure(JSException(message: "CHALLENGE_PRESENT")),
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
        #expect(out.map(\.key) == ["BTC", "USDC"])
        #expect(ctx.visibleCalls.count == 2)
        #expect(ctx.visibleCalls[0].showOverlay == true)
        #expect(ctx.visibleCalls[0].waitForChallengeClearance == false)
        #expect(ctx.visibleCalls[1].showOverlay == false)
        // The retry asks the runner to gate on (and survive) the challenge.
        #expect(ctx.visibleCalls[1].waitForChallengeClearance == true)
    }

    @Test("if challenge persists after retry, throws CHALLENGE_UNSOLVED")
    func unsolvedThrows() async {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleOutcomes = [
            .failure(JSException(message: "CHALLENGE_PRESENT")),
            .failure(JSException(message: "CHALLENGE_UNSOLVED"))
        ]
        var caught: String? = nil
        do {
            _ = try await p.getBalance(ctx: ctx, overlay: .default, showOverlay: true)
        } catch let e as JSException {
            caught = e.message
        } catch let e as PlatformError {
            caught = e.message
        } catch {
            caught = "\(error)"
        }
        #expect(caught == "CHALLENGE_UNSOLVED")
    }
}
