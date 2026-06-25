import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("Coinbase platform")
struct CoinbaseTests {

    @Test("id is 'coinbase'")
    func idIsCoinbase() {
        #expect(Coinbase().id == "coinbase")
    }

    @Test("login presents the modal at login.coinbase.com/signin")
    func loginPresentsModal() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .userClosed
        _ = try await p.login(ctx: ctx)
        #expect(ctx.modalCalls.count == 1)
        #expect(ctx.modalCalls[0].url.absoluteString == "https://login.coinbase.com/signin")
        // The login modal now uses a ModalHostPolicy with multiple stay-open
        // hosts (IdP redirects). `.host` is `stayOpenHosts.first`, which is
        // non-deterministic for a Set, so assert membership on the policy.
        let policy = ctx.modalCalls[0].policy
        // Google/passkeys are hidden in-embed (never redirect off-host), so only
        // the login host and Apple's IdP need to keep the modal open.
        #expect(policy.stayOpenHosts.contains("login.coinbase.com"))
        #expect(policy.stayOpenHosts.contains("appleid.apple.com"))
        #expect(policy.successHosts.contains("www.coinbase.com"))
        // The login modal injects a documentStart script that:
        //  • hides Google + all passkey buttons everywhere (can't complete in-embed),
        //  • auto-advances to Password when it's an available 2FA method.
        let docJS = try #require(ctx.modalCalls[0].documentStartJS)
        #expect(docJS.contains("sign-in-with-google"))
        #expect(docJS.contains(#"button[data-testid*="passkey" i]"#))
        #expect(docJS.contains("two-factor-button-PASSWORD"))
    }

    @Test("login success-close folds auth.status and reports outcome=success")
    func loginSuccessFoldsStatusLoggedIn() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .success
        ctx.offscreenResult = ["loggedIn": true]
        let result = try await p.login(ctx: ctx)
        #expect(result.outcome == "success")
        #expect(result.loggedIn == true)
        // The folded status check must have run against the dashboard.
        #expect(ctx.offscreenCalls.count == 1)
        #expect(ctx.offscreenCalls[0].url.absoluteString == "https://www.coinbase.com/home")
    }

    @Test("login success-close with not-logged-in still reports outcome=success, loggedIn=false")
    func loginSuccessFoldsStatusNotLoggedIn() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .success
        ctx.offscreenResult = ["loggedIn": false]
        let result = try await p.login(ctx: ctx)
        #expect(result.outcome == "success")
        #expect(result.loggedIn == false)
        #expect(ctx.offscreenCalls.count == 1)
    }

    @Test("login user-closed reports outcome=user-closed, loggedIn=false, no status check")
    func loginUserClosed() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .userClosed
        let result = try await p.login(ctx: ctx)
        #expect(result.outcome == "user-closed")
        #expect(result.loggedIn == false)
        #expect(ctx.offscreenCalls.isEmpty)
    }

    @Test("login timeout reports outcome=timeout, loggedIn=false, no status check")
    func loginTimeout() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .timeout
        let result = try await p.login(ctx: ctx)
        #expect(result.outcome == "timeout")
        #expect(result.loggedIn == false)
        #expect(ctx.offscreenCalls.isEmpty)
    }

    @Test("login supplies a passkey-only auto-close probe to the modal")
    func loginSuppliesAutoCloseProbe() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .userClosed
        _ = try await p.login(ctx: ctx)
        #expect(ctx.modalCalls.count == 1)
        let probe = ctx.modalCalls[0].autoClose
        #expect(probe != nil)
        // The bundled detector keys on Coinbase's passkey-verify button.
        #expect(probe?.probeJS.contains("passkey-verify-button") == true)
    }

    @Test("login condition-met reports outcome=passkey-only, loggedIn=false, no status check")
    func loginPasskeyOnly() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.modalCloseReason = .conditionMet
        let result = try await p.login(ctx: ctx)
        #expect(result.outcome == "passkey-only")
        #expect(result.loggedIn == false)
        #expect(ctx.offscreenCalls.isEmpty)
    }

    @Test("status runs the bundled JS against coinbase.com/home and parses {loggedIn:true}")
    func statusParsesLoggedIn() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.offscreenResult = ["loggedIn": true]
        let result = try await p.status(ctx: ctx)
        #expect(result.loggedIn == true)
        #expect(ctx.offscreenCalls.count == 1)
        #expect(ctx.offscreenCalls[0].url.absoluteString == "https://www.coinbase.com/home")
        #expect(ctx.offscreenCalls[0].script.contains("ProfileDropdownAvatar-wrapper"))
    }

    @Test("status throws .invalidJSReturn when JS returns a non-conforming value")
    func statusThrowsOnGarbage() async {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.offscreenResult = "nonsense"
        await #expect(throws: PlatformError.invalidJSReturn) {
            _ = try await p.status(ctx: ctx)
        }
    }

    @Test("Bundled auth-status.js loads from Bundle.module")
    func bundleResourceLoads() throws {
        // This is the actual integration check: if SPM didn't bundle the JS,
        // Coinbase() would crash on first access. Constructing it here proves
        // the resource pipeline.
        _ = Coinbase()
    }

    @Test("status short-circuits to loggedIn:false when settle sees login.coinbase.com")
    func statusShortCircuitsOnLoginHost() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        // The runner would never need to actually run the script in this
        // case — the predicate alone is enough.
        ctx.offscreenResult = ["loggedIn": false]
        _ = try await p.status(ctx: ctx)

        let call = ctx.offscreenCalls[0]
        // login.coinbase.com → answer(loggedIn=false), no JS.
        let loginDecision = call.settle(URL(string: "https://login.coinbase.com/signin?foo=1")!)
        guard case .answer(let payload) = loginDecision else {
            #expect(Bool(false), "expected .answer for login host")
            return
        }
        let dict = payload as? [String: Bool]
        #expect(dict?["loggedIn"] == false)
    }

    @Test("status runs the bundled JS only when settle sees www.coinbase.com")
    func statusEvaluatesOnDashboardHost() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.offscreenResult = ["loggedIn": true]
        _ = try await p.status(ctx: ctx)

        let call = ctx.offscreenCalls[0]
        let dashboardDecision = call.settle(URL(string: "https://www.coinbase.com/home")!)
        if case .evaluate = dashboardDecision { /* ok */ } else {
            #expect(Bool(false), "expected .evaluate for dashboard host")
        }
    }

    @Test("status keeps waiting on intermediate hosts")
    func statusWaitsOnIntermediateHosts() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.offscreenResult = ["loggedIn": false]
        _ = try await p.status(ctx: ctx)

        let call = ctx.offscreenCalls[0]
        let interim = call.settle(URL(string: "https://other.coinbase.com/redirect")!)
        if case .waitMore = interim { /* ok */ } else {
            #expect(Bool(false), "expected .waitMore for unknown host, got \(interim)")
        }
    }

    // MARK: - getDepositAddress (visible WebView path)

    @Test("getDepositAddress runs a VISIBLE WebView (not offscreen) so the Coinbase SPA renders")
    func depositUsesVisibleWebView() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["address": "0xABC", "network": "base", "asset": "USDC"]
        let payload = GetDepositAddressPayload(asset: "USDC", network: "base")

        let result = try await p.getDepositAddress(ctx: ctx, payload: payload, overlay: .default, showOverlay: true)

        #expect(result.address == "0xABC")
        #expect(result.network == "base")
        #expect(result.asset == "USDC")
        // The SPA-render fix: deposit must go through the visible path, never offscreen.
        #expect(ctx.visibleCalls.count == 1)
        #expect(ctx.offscreenCalls.isEmpty)
    }

    @Test("getDepositAddress forwards url, overlay, timeoutMs and passes params as bound arguments")
    func depositForwardsCallArgs() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["address": "0xABC"]
        let overlay = OverlayOptions(
            titles: ["Fetching your deposit address"],
            subtitles: ["one sec"],
            cycleMs: 4000,
            brand: .zerohash
        )
        let payload = GetDepositAddressPayload(asset: "USDC", network: "base")

        _ = try await p.getDepositAddress(ctx: ctx, payload: payload, overlay: overlay, showOverlay: true)

        let call = ctx.visibleCalls[0]
        #expect(call.url.absoluteString == "https://www.coinbase.com/trade")
        #expect(call.timeoutMs == 30_000)
        // The resolved overlay is threaded straight through to the context.
        #expect(call.overlay == overlay)
        // showOverlay rides alongside the overlay options.
        #expect(call.showOverlay == true)
        // The request payload is handed to WebKit as the bound argument,
        // so it reaches the script without being interpolated into its source.
        #expect(!call.script.contains("window.__zhDepositParams"))
        #expect(!call.script.contains(#""asset":"USDC""#))
        let params = call.arguments["params"] as? [String: Any]
        #expect(params?["asset"] as? String == "USDC")
        #expect(params?["network"] as? String == "base")
    }

    @Test("getDepositAddress passes params as bound arguments, immune to JS injection")
    func depositParamsNotInterpolated() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["address": "0xABC"]
        // A malicious asset string that would break out of a JS string/object
        // literal and execute attacker code IF interpolated into the source.
        let evil = "\");globalThis.__pwned=1;(\""
        let payload = GetDepositAddressPayload(asset: evil, network: "base")

        _ = try await p.getDepositAddress(ctx: ctx, payload: payload, overlay: .default, showOverlay: true)

        let call = ctx.visibleCalls[0]
        // The payload value must NOT appear anywhere in the executable source.
        #expect(!call.script.contains("__pwned"))
        #expect(!call.script.contains(evil))
        // It must arrive intact via the bound-argument channel.
        let params = call.arguments["params"] as? [String: Any]
        #expect(params?["asset"] as? String == evil)
    }

    // MARK: - getBalance (bound-argument params)

    @Test("getBalance passes ops as bound arguments, not interpolated")
    func balanceParamsNotInterpolated() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["balances": [[
            "key": "BTC", "label": "Bitcoin", "amount": "0.5",
            "notional": "30000", "extractedAt": "2026-01-01T00:00:00Z",
        ]]]

        _ = try await p.getBalance(ctx: ctx, overlay: .default, showOverlay: true)

        let call = ctx.visibleCalls[0]
        // Ops must not be interpolated into the source.
        #expect(!call.script.contains("window.__zhBalanceParams"))
        let params = call.arguments["params"] as? [String: Any]
        let ops = params?["ops"] as? [String]
        #expect(ops == ["CryptoQuery", "CashQuery"])
    }

    @Test("getDepositAddress settle predicate: www→evaluate, login→answer(nil), other→waitMore")
    func depositSettleBehaviour() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["address": "0xABC"]
        _ = try await p.getDepositAddress(
            ctx: ctx,
            payload: GetDepositAddressPayload(asset: "USDC"),
            overlay: .default,
            showOverlay: true
        )

        let call = ctx.visibleCalls[0]

        if case .evaluate = call.settle(URL(string: "https://www.coinbase.com/home")!) {} else {
            #expect(Bool(false), "expected .evaluate for www.coinbase.com")
        }

        // login host → .answer(nil) signalling not-logged-in.
        let loginDecision = call.settle(URL(string: "https://login.coinbase.com/signin")!)
        guard case .answer(let payload) = loginDecision else {
            #expect(Bool(false), "expected .answer for login host")
            return
        }
        #expect(payload == nil)

        if case .waitMore = call.settle(URL(string: "https://other.coinbase.com/x")!) {} else {
            #expect(Bool(false), "expected .waitMore for unknown host")
        }
    }

    @Test("getDepositAddress maps a Lightning result with amountSubmitted")
    func depositMapsLightningAmount() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = [
            "address": "lnbc123",
            "network": "lightning",
            "asset": "BTC",
            "amountSubmitted": ["value": "0.001", "requestedCurrency": "asset", "resolvedSymbol": "BTC"],
        ]
        let result = try await p.getDepositAddress(
            ctx: ctx,
            payload: GetDepositAddressPayload(asset: "BTC", network: "lightning"),
            overlay: .default,
            showOverlay: true
        )
        #expect(result.address == "lnbc123")
        #expect(result.amountSubmitted?.value == "0.001")
        #expect(result.amountSubmitted?.resolvedSymbol == "BTC")
    }

    @Test("getDepositAddress throws 'not logged in' when the visible WebView returns nil")
    func depositThrowsNotLoggedIn() async {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = nil // settle short-circuited to .answer(nil)
        await #expect(throws: PlatformError.underlying("not logged in")) {
            _ = try await p.getDepositAddress(
                ctx: ctx,
                payload: GetDepositAddressPayload(asset: "USDC"),
                overlay: .default,
                showOverlay: true
            )
        }
    }

    @Test("getDepositAddress surfaces a JS exception thrown by the visible WebView")
    func depositSurfacesVisibleError() async {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleError = JSException(message: "requires an amount")
        await #expect(throws: JSException.self) {
            _ = try await p.getDepositAddress(
                ctx: ctx,
                payload: GetDepositAddressPayload(asset: "USDC"),
                overlay: .default,
                showOverlay: true
            )
        }
    }

    @Test("getDepositAddress throws .invalidJSReturn when JS returns a non-conforming value")
    func depositThrowsOnGarbage() async {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = "nonsense"
        await #expect(throws: PlatformError.invalidJSReturn) {
            _ = try await p.getDepositAddress(
                ctx: ctx,
                payload: GetDepositAddressPayload(asset: "USDC"),
                overlay: .default,
                showOverlay: true
            )
        }
    }

    // MARK: - getDepositAddress showOverlay forwarding (contract.ts:38-41)

    @Test("getDepositAddress forwards showOverlay:false into the VisibleCall")
    func depositForwardsShowOverlayFalse() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["address": "0xABC"]
        _ = try await p.getDepositAddress(
            ctx: ctx,
            payload: GetDepositAddressPayload(asset: "USDC"),
            overlay: .default,
            showOverlay: false
        )
        #expect(ctx.visibleCalls[0].showOverlay == false)
    }

    @Test("getDepositAddress forwards showOverlay:true into the VisibleCall")
    func depositForwardsShowOverlayTrue() async throws {
        let p = Coinbase()
        let ctx = MockExecutionContext()
        ctx.visibleResult = ["address": "0xABC"]
        _ = try await p.getDepositAddress(
            ctx: ctx,
            payload: GetDepositAddressPayload(asset: "USDC"),
            overlay: .default,
            showOverlay: true
        )
        #expect(ctx.visibleCalls[0].showOverlay == true)
    }
}
