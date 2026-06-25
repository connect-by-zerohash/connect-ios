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
}
