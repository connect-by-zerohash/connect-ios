import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("WithdrawCoordinator")
struct WithdrawCoordinatorTests {

    private static let details = WithdrawDetails(
        fiatAmount: nil, cryptoAmount: nil, recipient: nil,
        network: nil, timeEstimate: nil, fee: nil)

    private static func payload() -> StartWithdrawPayload {
        StartWithdrawPayload(asset: "USDC", address: "0xabc", amount: .max)
    }

    /// A WithdrawFlow whose `startWithdraw` suspends until `release()`, so a test
    /// can hold one start in flight and fire an overlapping one — exercising the
    /// coordinator's reentrancy guard (`active == nil && !starting`).
    @MainActor
    final class GatedStartFlow: WithdrawFlow {
        let id = "coinbase"
        let handle: MockAutomationSessionHandle
        let startState: WithdrawState
        private(set) var startCount = 0
        private var entered = false
        private var enteredCont: CheckedContinuation<Void, Never>?
        private var releaseCont: CheckedContinuation<Void, Never>?

        init(handle: MockAutomationSessionHandle, startState: WithdrawState) {
            self.handle = handle
            self.startState = startState
        }

        func startWithdraw(ctx: ExecutionContext, payload: StartWithdrawPayload,
                           overlay: OverlayOptions, showOverlay: Bool) async throws -> WithdrawStartResult {
            startCount += 1
            entered = true
            enteredCont?.resume()
            enteredCont = nil
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in releaseCont = c }
            return WithdrawStartResult(session: handle, state: startState)
        }
        func continueWithdraw(session: AutomationSessionHandle, payload: ContinueWithdrawPayload) async throws -> WithdrawState { startState }
        func cancelWithdraw(session: AutomationSessionHandle) async throws -> Bool { true }

        /// Suspends until `startWithdraw` has been entered (so `starting` is set).
        func waitUntilEntered() async {
            if entered { return }
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in enteredCont = c }
        }
        func release() {
            entered = false // re-arm so a subsequent start can be awaited again
            releaseCont?.resume()
            releaseCont = nil
        }
    }

    @Test("an overlapping start is rejected — startWithdraw runs once, one session")
    func overlappingStartRejected() async throws {
        let coordinator = WithdrawCoordinator()
        let ctx = MockExecutionContext()
        let flow = GatedStartFlow(handle: MockAutomationSessionHandle(),
                                  startState: .awaitingInputOtp(details: Self.details))

        // start #1 — enters startWithdraw and suspends there, having claimed the
        // in-flight flag (its `active` is not stored until startWithdraw returns).
        let first = Task { @MainActor in
            try await coordinator.start(platform: flow, ctx: ctx,
                                        payload: Self.payload(), overlay: .default, showOverlay: false)
        }
        await flow.waitUntilEntered()

        // start #2 while #1 is in flight — must be rejected by the guard, before
        // it ever reaches startWithdraw.
        var secondRejected = false
        do {
            _ = try await coordinator.start(platform: flow, ctx: ctx,
                                            payload: Self.payload(), overlay: .default, showOverlay: false)
        } catch {
            secondRejected = true
        }

        flow.release()                  // let #1 complete
        _ = try await first.value

        #expect(secondRejected == true)
        #expect(flow.startCount == 1)   // the second never opened a second modal
    }

    @Test("after a start completes, a fresh start is accepted")
    func startReusableAfterCompletion() async throws {
        let coordinator = WithdrawCoordinator()
        let ctx = MockExecutionContext()
        // A terminal first state ends the session immediately, freeing the slot.
        let flow = GatedStartFlow(
            handle: MockAutomationSessionHandle(),
            startState: .rejected(reason: WithdrawRejectReason.transferCanceled, pendingTransfer: nil))

        let first = Task { @MainActor in
            try await coordinator.start(platform: flow, ctx: ctx,
                                        payload: Self.payload(), overlay: .default, showOverlay: false)
        }
        await flow.waitUntilEntered()
        flow.release()
        _ = try await first.value

        // The in-flight flag cleared (via defer) and the terminal state left no
        // active session, so a second start is accepted, not rejected.
        let second = Task { @MainActor in
            try await coordinator.start(platform: flow, ctx: ctx,
                                        payload: Self.payload(), overlay: .default, showOverlay: false)
        }
        await flow.waitUntilEntered()
        flow.release()
        _ = try await second.value

        #expect(flow.startCount == 2)
    }

    /// Parks a session at `parked`, then runs one `continue` and reports what the
    /// coordinator did to the screen. Used to check that polling a parked session
    /// does not re-present Coinbase's page.
    @MainActor
    private func park(
        at parked: WithdrawState,
        thenContinueWith payload: ContinueWithdrawPayload
    ) async throws -> MockAutomationSessionHandle {
        let coordinator = WithdrawCoordinator()
        let ctx = MockExecutionContext()
        let handle = MockAutomationSessionHandle()
        let flow = GatedStartFlow(handle: handle, startState: parked)

        let start = Task { @MainActor in
            try await coordinator.start(platform: flow, ctx: ctx, payload: Self.payload(),
                                        overlay: .default, showOverlay: false)
        }
        await flow.waitUntilEntered()
        flow.release()
        let (_, sessionId) = try await start.value

        _ = try await coordinator.continue(platform: flow, sessionId: sessionId, payload: payload)
        return handle
    }

    /// The host polls a parked id-verification every few seconds. Re-presenting the
    /// WebView to read the DOM made Coinbase's risk page flash open and shut on that
    /// cadence — a visible loop, on a screen the user has been told to leave alone.
    ///
    /// A poll only reads (`probePostConfirm` queries, it does not click), and
    /// `stepAside` keeps the WebView alive, so no presentation is needed.
    @Test("polling a parked id-verification never re-presents Coinbase's page")
    func pollDoesNotRepresentThePage() async throws {
        let handle = try await park(
            at: .awaitingUserActionIdVerification(details: Self.details, completeBefore: nil),
            thenContinueWith: .poll)

        // The page stays exactly as the user left it: not dismissed, not re-presented,
        // and still revealed. Re-presenting is what made it flash on every poll.
        #expect(handle.resumeCount == 0)
        #expect(handle.stepAsideCount == 0)
        #expect(handle.overlayRevealed == true)
        #expect(handle.restartTimeoutCount == 1)  // still gets a fresh budget
    }

    /// The counterpart: submitting a code has to type into the page, so it must be
    /// on screen. Skipping presentation for everything would break OTP entry.
    @Test("submitting an OTP does re-present the page, because it types into it")
    func otpRepresentsThePage() async throws {
        let handle = try await park(at: .awaitingInputOtp(details: Self.details),
                                   thenContinueWith: .otp(code: "123456"))

        #expect(handle.resumeCount == 1)
        #expect(handle.restartTimeoutCount == 1)
    }

    /// The user completes Coinbase's identity check in place, so the page must be
    /// revealed — not stepped aside. Coinbase renders that flow itself (no
    /// third-party frame in any captured snapshot) and the SDK grants camera capture
    /// for Coinbase origins, so it can run here.
    @Test("id-verification reveals the page so the user can do the check in place")
    func idVerificationRevealsThePage() async throws {
        let coordinator = WithdrawCoordinator()
        let ctx = MockExecutionContext()
        let handle = MockAutomationSessionHandle()
        let flow = GatedStartFlow(
            handle: handle,
            startState: .awaitingUserActionIdVerification(
                details: Self.details, completeBefore: nil))

        let task = Task { @MainActor in
            try await coordinator.start(platform: flow, ctx: ctx,
                                        payload: Self.payload(), overlay: .default,
                                        showOverlay: false)
        }
        await flow.waitUntilEntered()
        flow.release()
        _ = try await task.value

        #expect(handle.overlayRevealed == true) // Coinbase's page is on screen
        #expect(handle.stepAsideCount == 0)     // and was not dismissed
        #expect(handle.pauseTimeoutCount == 1)  // the wait is unbounded
    }
}
