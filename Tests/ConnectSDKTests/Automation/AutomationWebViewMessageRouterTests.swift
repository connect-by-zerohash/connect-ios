import Testing
import Foundation
import UIKit
@testable import ConnectSDK

@MainActor
@Suite("AutomationWebViewMessageRouter dispatch routing")
struct AutomationWebViewMessageRouterDispatchTests {

    /// Records every reply / event the router emits.
    final class FakeReplySink: AutomationWebViewReplySink {
        var responses: [ZeroAuthResponse] = []
        var events: [BridgeEvent] = []
        func send(response: ZeroAuthResponse) { responses.append(response) }
        func send(event: BridgeEvent) { events.append(event) }
    }

    private struct StubAuthFlow: AuthFlow {
        let id: String
        let loginResult: AuthLoginResult
        let statusResult: AuthStatusResult
        let throwOnLogin: Error?
        let throwOnStatus: Error?

        init(id: String,
             login: AuthLoginResult = .init(loggedIn: true, outcome: "success"),
             status: AuthStatusResult = .init(loggedIn: false),
             throwOnLogin: Error? = nil,
             throwOnStatus: Error? = nil) {
            self.id = id
            self.loginResult = login
            self.statusResult = status
            self.throwOnLogin = throwOnLogin
            self.throwOnStatus = throwOnStatus
        }

        func login(ctx: ExecutionContext) async throws -> AuthLoginResult {
            if let e = throwOnLogin { throw e }
            return loginResult
        }
        func status(ctx: ExecutionContext) async throws -> AuthStatusResult {
            if let e = throwOnStatus { throw e }
            return statusResult
        }
    }

    /// Records the resolved `OverlayOptions` the router forwards into
    /// `getDepositAddress`. Does not touch `ctx`, so the harness's real
    /// ExecutionContextImpl is never exercised.
    private final class RecordingDepositFlow: DepositFlow {
        let id: String
        private(set) var receivedOverlay: OverlayOptions?
        private(set) var receivedShowOverlay: Bool?
        init(id: String) { self.id = id }
        func getDepositAddress(
            ctx: ExecutionContext,
            payload: GetDepositAddressPayload,
            overlay: OverlayOptions,
            showOverlay: Bool
        ) async throws -> DepositAddressResult {
            receivedOverlay = overlay
            receivedShowOverlay = showOverlay
            return DepositAddressResult(
                address: "0xABC", destinationTag: "", network: "base",
                asset: payload.asset, warnings: [], depositUri: ""
            )
        }
    }

    private func makeRouter(seed: [any PlatformIdentity], sink: FakeReplySink) -> AutomationWebViewMessageRouter {
        let registry = PlatformRegistry(default: seed)
        let shared = SharedWebViewConfiguration()
        let host = UIViewController()
        return AutomationWebViewMessageRouter(
            registry: registry,
            sink: sink,
            executionContextFactory: { reqId in
                ExecutionContextImpl(
                    host: host, shared: shared,
                    currentRequestId: reqId, eventEmitter: sink
                )
            }
        )
    }

    @Test("core.ping short-circuits without consulting the registry")
    func corePing() async {
        let sink = FakeReplySink()
        let router = makeRouter(seed: [], sink: sink)
        let req = ZeroAuthRequest(id: "p1", platform: "core", operation: "core.ping")
        await router.dispatch(req)
        #expect(sink.responses.count == 1)
        #expect(sink.responses[0].success == true)
    }

    @Test("Unknown platform → platformNotRegistered")
    func unknownPlatform() async {
        let sink = FakeReplySink()
        let router = makeRouter(seed: [], sink: sink)
        let req = ZeroAuthRequest(id: "u1", platform: "kraken", operation: "auth.login")
        await router.dispatch(req)
        #expect(sink.responses.count == 1)
        #expect(sink.responses[0].success == false)
        #expect(sink.responses[0].error?.contains("kraken") == true)
    }

    @Test("Unknown operation on registered platform → unsupported")
    func unknownOperation() async {
        let sink = FakeReplySink()
        let router = makeRouter(seed: [StubAuthFlow(id: "stub")], sink: sink)
        let req = ZeroAuthRequest(id: "u2", platform: "stub", operation: "withdraw.start")
        await router.dispatch(req)
        #expect(sink.responses[0].success == false)
        #expect(sink.responses[0].error?.contains("withdraw.start") == true)
    }

    @Test("auth.login routes to AuthFlow.login and returns {loggedIn, outcome}")
    func authLoginRoutes() async {
        let sink = FakeReplySink()
        let router = makeRouter(seed: [StubAuthFlow(id: "stub")], sink: sink)
        let req = ZeroAuthRequest(id: "L1", platform: "stub", operation: "auth.login")
        await router.dispatch(req)
        #expect(sink.responses[0].success == true)
        let dataStr = String(data: try! JSONEncoder().encode(sink.responses[0].data), encoding: .utf8)!
        #expect(dataStr.contains(#""loggedIn":true"#))
        #expect(dataStr.contains(#""outcome":"success""#))
    }

    @Test("auth.status routes to AuthFlow.status and returns loggedIn:bool")
    func authStatusRoutes() async {
        let stub = StubAuthFlow(id: "stub", status: .init(loggedIn: true))
        let sink = FakeReplySink()
        let router = makeRouter(seed: [stub], sink: sink)
        let req = ZeroAuthRequest(id: "S1", platform: "stub", operation: "auth.status")
        await router.dispatch(req)
        #expect(sink.responses[0].success == true)
        let dataStr = String(data: try! JSONEncoder().encode(sink.responses[0].data), encoding: .utf8)!
        #expect(dataStr.contains(#""loggedIn":true"#))
    }

    @Test("Platform throws → platformThrew error envelope")
    func platformThrows() async {
        struct E: Error { }
        let stub = StubAuthFlow(id: "stub", throwOnLogin: E())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [stub], sink: sink)
        let req = ZeroAuthRequest(id: "T1", platform: "stub", operation: "auth.login")
        await router.dispatch(req)
        #expect(sink.responses[0].success == false)
    }

    @Test("CancellationError → emits cancelled event tagged with request id")
    func cancellationEmitsEvent() async {
        let stub = StubAuthFlow(id: "stub", throwOnStatus: CancellationError())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [stub], sink: sink)
        let req = ZeroAuthRequest(id: "C1", platform: "stub", operation: "auth.status")
        await router.dispatch(req)
        #expect(sink.events.contains { $0.correlationId == "C1" && $0.type == "cancelled" })
        #expect(sink.responses[0].success == false)
        #expect(sink.responses[0].error == "cancelled")
    }

    @Test("Concurrent auth.status requests share a single AuthFlow.status invocation")
    func authStatusCoalesces() async {
        // Stub that counts how many times status() is actually invoked.
        actor Counter { var n = 0; func bump() -> Int { n += 1; return n } }
        let counter = Counter()

        struct CountingFlow: AuthFlow {
            let id = "stub"
            let bump: () async -> Int
            func login(ctx: ExecutionContext) async throws -> AuthLoginResult { .init(loggedIn: true, outcome: "success") }
            func status(ctx: ExecutionContext) async throws -> AuthStatusResult {
                _ = await bump()
                // Yield so a second dispatch lands while we're "in flight".
                try await Task.sleep(nanoseconds: 50_000_000)
                return .init(loggedIn: true)
            }
        }

        let flow = CountingFlow(bump: { await counter.bump() })
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        async let r1: Void = router.dispatch(ZeroAuthRequest(id: "S1", platform: "stub", operation: "auth.status"))
        async let r2: Void = router.dispatch(ZeroAuthRequest(id: "S2", platform: "stub", operation: "auth.status"))
        _ = await (r1, r2)

        // Both requests received a successful response …
        #expect(sink.responses.count == 2)
        #expect(sink.responses.allSatisfy { $0.success })
        #expect(Set(sink.responses.map(\.id)) == ["S1", "S2"])
        // … but the underlying status() ran exactly once.
        let n = await counter.n
        #expect(n == 1, "expected status() to be coalesced, ran \(n) times")
    }

    // MARK: - getDepositAddress overlay resolution

    @Test("getDepositAddress WITH overlayOptions resolves and forwards them to the platform")
    func depositResolvesProvidedOverlay() async {
        let flow = RecordingDepositFlow(id: "coinbase")
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        // zerohash branding selects the palette + mark; copy is custom.
        let wire = WireOverlayOptions(
            titles: ["Fetching your deposit address"],
            subtitles: nil,
            cycleMs: nil,
            branding: "zerohash"
        )
        let req = ZeroAuthRequest(
            id: "D1",
            platform: "coinbase",
            operation: "getDepositAddress",
            payload: .object(["asset": .string("USDC"), "network": .string("base")]),
            options: RequestOptions(overlayOptions: wire)
        )
        await router.dispatch(req)

        #expect(sink.responses[0].success == true)
        let got = flow.receivedOverlay
        #expect(got?.titles == ["Fetching your deposit address"])
        // Branding drives the palette — colors come from the zerohash theme.
        #expect(got?.brand == .zerohash)
        #expect(got?.colors == Brand.zerohash.theme.colors)
        // Omitted fields fall back to the Connect defaults.
        #expect(got?.subtitles == OverlayOptions.default.subtitles)
        #expect(got?.cycleMs == OverlayOptions.default.cycleMs)
    }

    @Test("getDepositAddress WITHOUT options forwards OverlayOptions.default")
    func depositForwardsDefaultOverlay() async {
        let flow = RecordingDepositFlow(id: "coinbase")
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        let req = ZeroAuthRequest(
            id: "D2",
            platform: "coinbase",
            operation: "getDepositAddress",
            payload: .object(["asset": .string("USDC")])
        )
        await router.dispatch(req)

        #expect(sink.responses[0].success == true)
        #expect(flow.receivedOverlay == OverlayOptions.default)
    }

    // MARK: - getDepositAddress initialOverlay → showOverlay resolution
    //
    // Contract-intended (contract.ts:38-41): the host can pass
    // initialOverlay:false so the user watches the automation play out.
    // The router maps the wire field to the Swift `showOverlay` and defaults
    // to TRUE when the field is absent (extension default initialOverlay:true).

    @Test("getDepositAddress WITH initialOverlay:false forwards showOverlay:false")
    func depositForwardsShowOverlayFalse() async {
        let flow = RecordingDepositFlow(id: "coinbase")
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        let req = ZeroAuthRequest(
            id: "D3",
            platform: "coinbase",
            operation: "getDepositAddress",
            payload: .object(["asset": .string("USDC")]),
            options: RequestOptions(overlayOptions: nil, initialOverlay: false)
        )
        await router.dispatch(req)

        #expect(sink.responses[0].success == true)
        #expect(flow.receivedShowOverlay == false)
    }

    @Test("getDepositAddress WITH initialOverlay:true forwards showOverlay:true")
    func depositForwardsShowOverlayTrue() async {
        let flow = RecordingDepositFlow(id: "coinbase")
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        let req = ZeroAuthRequest(
            id: "D4",
            platform: "coinbase",
            operation: "getDepositAddress",
            payload: .object(["asset": .string("USDC")]),
            options: RequestOptions(overlayOptions: nil, initialOverlay: true)
        )
        await router.dispatch(req)

        #expect(sink.responses[0].success == true)
        #expect(flow.receivedShowOverlay == true)
    }

    @Test("getDepositAddress WITHOUT initialOverlay defaults showOverlay:true")
    func depositDefaultsShowOverlayTrue() async {
        let flow = RecordingDepositFlow(id: "coinbase")
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        let req = ZeroAuthRequest(
            id: "D5",
            platform: "coinbase",
            operation: "getDepositAddress",
            payload: .object(["asset": .string("USDC")])
        )
        await router.dispatch(req)

        #expect(sink.responses[0].success == true)
        #expect(flow.receivedShowOverlay == true)
    }

    // MARK: - withdraw.start (session opening)

    private static let emptyWithdrawDetails = WithdrawDetails(
        fiatAmount: nil, cryptoAmount: nil, recipient: nil,
        network: nil, timeEstimate: nil, fee: nil)

    /// Returns a canned first state + a mock modal handle, ignoring `ctx`
    /// (mirrors `RecordingDepositFlow`). `continue`/`cancel` are unused in 3.2.
    private struct StubWithdrawFlow: WithdrawFlow {
        let id: String
        let startState: WithdrawState
        /// State returned by `continueWithdraw`; defaults so 3.2 call sites that
        /// only exercise `start` need not provide it.
        var continueState: WithdrawState? = nil
        var cancelResult: Bool = true
        /// When set, the matching method throws instead of returning — exercises
        /// the coordinator's failure-teardown path.
        var continueError: Error? = nil
        var cancelError: Error? = nil
        let handle: MockAutomationSessionHandle
        func startWithdraw(ctx: ExecutionContext, payload: StartWithdrawPayload,
                           overlay: OverlayOptions, showOverlay: Bool) async throws -> WithdrawStartResult {
            WithdrawStartResult(session: handle, state: startState)
        }
        func continueWithdraw(session: AutomationSessionHandle,
                              payload: ContinueWithdrawPayload) async throws -> WithdrawState {
            if let continueError { throw continueError }
            return continueState ?? startState
        }
        func cancelWithdraw(session: AutomationSessionHandle) async throws -> Bool {
            if let cancelError { throw cancelError }
            return cancelResult
        }
    }

    private struct DriveError: Error {}

    private func cancelReq(_ id: String, sessionId: String?) -> ZeroAuthRequest {
        ZeroAuthRequest(id: id, platform: "coinbase", operation: "withdraw.cancel", sessionId: sessionId)
    }

    private func continueReq(_ id: String, sessionId: String?) -> ZeroAuthRequest {
        ZeroAuthRequest(
            id: id, platform: "coinbase", operation: "withdraw.continue",
            payload: .object(["kind": .string("otp"), "code": .string("123456")]),
            sessionId: sessionId)
    }

    private static let submittedState = WithdrawState.submitted(result: WithdrawSubmittedResult(
        status: "PENDING", completeBefore: nil, referenceId: "ref", sendUuid: "uuid",
        details: emptyWithdrawDetails))

    private func startReq(_ id: String) -> ZeroAuthRequest {
        ZeroAuthRequest(
            id: id, platform: "coinbase", operation: "withdraw.start",
            payload: .object([
                "asset": .string("USDC"), "address": .string("0xabc"), "amount": .string("max"),
            ]))
    }

    @Test("withdraw.start opens a session and returns state + a non-empty sessionId")
    func withdrawStartOpensSession() async {
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            handle: MockAutomationSessionHandle())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))

        #expect(sink.responses.count == 1)
        #expect(sink.responses[0].success == true)
        #expect(sink.responses[0].sessionId?.isEmpty == false)
        let dataStr = String(data: try! JSONEncoder().encode(sink.responses[0].data), encoding: .utf8)!
        #expect(dataStr.contains(#""state":"awaiting-input""#))
        #expect(dataStr.contains(#""kind":"otp""#))
    }

    @Test("a second withdraw.start while one is active is rejected")
    func withdrawStartRejectsSecond() async {
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            handle: MockAutomationSessionHandle())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))
        await router.dispatch(startReq("W2"))

        #expect(sink.responses.count == 2)
        #expect(sink.responses[0].success == true)
        #expect(sink.responses[1].success == false)
        #expect(sink.responses[1].error?.contains("already in progress") == true)
    }

    @Test("withdraw.start on a non-WithdrawFlow platform → unsupported")
    func withdrawStartUnsupported() async {
        let sink = FakeReplySink()
        let router = makeRouter(seed: [StubAuthFlow(id: "coinbase")], sink: sink)
        await router.dispatch(startReq("W1"))
        #expect(sink.responses[0].success == false)
        #expect(sink.responses[0].error?.contains("withdraw.start") == true)
    }

    // MARK: - withdraw.continue

    @Test("withdraw.continue drives the open session, echoes its sessionId, and clears on terminal")
    func withdrawContinueDrivesSession() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            continueState: Self.submittedState,
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))
        let sid = sink.responses[0].sessionId
        await router.dispatch(continueReq("W2", sessionId: sid))

        #expect(sink.responses.count == 2)
        #expect(sink.responses[1].success == true)
        #expect(sink.responses[1].sessionId == sid)
        let dataStr = String(data: try! JSONEncoder().encode(sink.responses[1].data), encoding: .utf8)!
        #expect(dataStr.contains(#""state":"submitted""#))
        // Terminal state → the modal was dismissed and the slot cleared.
        #expect(handle.dismissed == true)
    }

    @Test("withdraw.continue with no active session is rejected")
    func withdrawContinueNoSession() async {
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .processing(details: Self.emptyWithdrawDetails),
            handle: MockAutomationSessionHandle())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(continueReq("W1", sessionId: "nope"))

        #expect(sink.responses[0].success == false)
        #expect(sink.responses[0].error?.contains("no active withdraw session") == true)
    }

    @Test("withdraw.continue with a mismatched sessionId is rejected")
    func withdrawContinueMismatch() async {
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            handle: MockAutomationSessionHandle())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))
        await router.dispatch(continueReq("W2", sessionId: "wrong-id"))

        #expect(sink.responses[1].success == false)
        #expect(sink.responses[1].error?.contains("no active withdraw session") == true)
    }

    @Test("a throwing withdraw.continue still dismisses the modal and clears the slot")
    func withdrawContinueFailureTearsDown() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            continueError: DriveError(),
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))
        let sid = sink.responses[0].sessionId
        await router.dispatch(continueReq("W2", sessionId: sid))

        // The failure surfaces to the host…
        #expect(sink.responses[1].success == false)
        // …and the session is torn down: modal dismissed + slot cleared, so a
        // fresh start is accepted rather than rejected as "already in progress".
        #expect(handle.dismissed == true)
        await router.dispatch(startReq("W3"))
        #expect(sink.responses[2].success == true)
    }

    // MARK: - withdraw.cancel

    @Test("withdraw.cancel cancels the open session, returns {cancelled}, and clears it")
    func withdrawCancelClearsSession() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))
        let sid = sink.responses[0].sessionId
        await router.dispatch(cancelReq("W2", sessionId: sid))

        #expect(sink.responses[1].success == true)
        #expect(sink.responses[1].sessionId == sid)
        let dataStr = String(data: try! JSONEncoder().encode(sink.responses[1].data), encoding: .utf8)!
        #expect(dataStr.contains(#""cancelled":true"#))
        #expect(handle.dismissed == true)

        // Slot cleared: a follow-up continue on the same id now errors.
        await router.dispatch(continueReq("W3", sessionId: sid))
        #expect(sink.responses[2].success == false)
    }

    @Test("withdraw.cancel with no active session is rejected")
    func withdrawCancelNoSession() async {
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .processing(details: Self.emptyWithdrawDetails),
            handle: MockAutomationSessionHandle())
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(cancelReq("W1", sessionId: "nope"))

        #expect(sink.responses[0].success == false)
        #expect(sink.responses[0].error?.contains("no active withdraw session") == true)
    }

    @Test("a throwing withdraw.cancel still dismisses the modal and clears the slot")
    func withdrawCancelFailureTearsDown() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            cancelError: DriveError(),
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))
        let sid = sink.responses[0].sessionId
        await router.dispatch(cancelReq("W2", sessionId: sid))

        // Cancel failed, but the session must still be torn down: modal dismissed
        // and slot cleared, so a fresh start is accepted.
        #expect(sink.responses[1].success == false)
        #expect(handle.dismissed == true)
        await router.dispatch(startReq("W3"))
        #expect(sink.responses[2].success == true)
    }

    // MARK: - visibility choreography (A2.2)

    @Test("start awaiting-otp steps the modal aside (host shows)")
    func withdrawStartOtpStepsAside() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))

        #expect(handle.stepAsideCount == 1)
        #expect(handle.overlayRevealed == nil) // not revealed — host took over
    }

    @Test("start id-verification reveals the Coinbase modal (no step-aside)")
    func withdrawStartIdVerificationRevealsCoinbase() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingUserActionIdVerification(details: Self.emptyWithdrawDetails, completeBefore: nil),
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))

        #expect(handle.stepAsideCount == 0)
        #expect(handle.overlayRevealed == true)
    }

    @Test("continue after a step-aside reclaims the screen (resume)")
    func withdrawContinueReclaimsScreen() async {
        let handle = MockAutomationSessionHandle()
        let flow = StubWithdrawFlow(
            id: "coinbase",
            startState: .awaitingInputOtp(details: Self.emptyWithdrawDetails),
            continueState: Self.submittedState,
            handle: handle)
        let sink = FakeReplySink()
        let router = makeRouter(seed: [flow], sink: sink)

        await router.dispatch(startReq("W1"))            // → stepAside
        let sid = sink.responses[0].sessionId
        await router.dispatch(continueReq("W2", sessionId: sid))  // → reclaim (resume)

        #expect(handle.resumeCount == 1)
        #expect(handle.dismissed == true)                // terminal submitted → dismissed
    }
}
