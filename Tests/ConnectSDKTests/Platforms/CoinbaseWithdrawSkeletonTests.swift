import XCTest
@testable import ConnectSDK

/// Phase 2 smoke tests for the Coinbase `WithdrawFlow` skeleton. The injected JS
/// is stubbed (replaced by the real driver in Phase 3); these exercise the method
/// shapes + the `mapWithdrawState` parser by scripting
/// `MockAutomationSessionHandle`'s `evaluateAsync` results. Deliberately simple.
@MainActor
final class CoinbaseWithdrawSkeletonTests: XCTestCase {

    private let coinbase = Coinbase()

    private static let detailsDict: [String: Any] = [
        "fiatAmount": "$50.00", "cryptoAmount": "50 USDC", "recipient": "0xabc",
        "network": "ethereum", "timeEstimate": "~2 min", "fee": "$0.10",
    ]
    private static let details = WithdrawDetails(
        fiatAmount: "$50.00", cryptoAmount: "50 USDC", recipient: "0xabc",
        network: "ethereum", timeEstimate: "~2 min", fee: "$0.10")

    private static let awaitingOtp: [String: Any] =
        ["state": "awaiting-input", "kind": "otp", "details": detailsDict]
    private static let submitted: [String: Any] = [
        "state": "submitted",
        "result": ["status": "PENDING", "referenceId": "ref-1", "sendUuid": "uuid-1",
                   "details": detailsDict],
    ]

    private static let payload = StartWithdrawPayload(
        asset: "USDC", network: "ethereum", address: "0xabc",
        amount: .spec(AmountSpec(value: "50", currency: .asset)))

    // MARK: - start

    func testStartPresentsModalAndReturnsState() async throws {
        let ctx = MockExecutionContext()
        let handle = MockAutomationSessionHandle()
        handle.evaluateResults = [.success(Self.awaitingOtp)]
        ctx.automationHandleToReturn = handle

        let result = try await coinbase.startWithdraw(
            ctx: ctx, payload: Self.payload, overlay: .default, showOverlay: false)

        XCTAssertEqual(ctx.automationCalls.count, 1)
        XCTAssertEqual(result.state, .awaitingInputOtp(details: Self.details))
        // The session handle bundled back is the same live session.
        XCTAssertTrue(result.session as? MockAutomationSessionHandle === handle)
    }

    // MARK: - continue

    func testContinueOtpDrivesSameSessionAndForwardsCode() async throws {
        let handle = MockAutomationSessionHandle()
        handle.evaluateResults = [.success(Self.submitted)]

        let state = try await coinbase.continueWithdraw(
            session: handle, payload: .otp(code: "123456"))

        XCTAssertEqual(state, .submitted(result: WithdrawSubmittedResult(
            status: "PENDING", completeBefore: nil, referenceId: "ref-1",
            sendUuid: "uuid-1", details: Self.details)))
        // The OTP code is passed as a BOUND ARGUMENT (not interpolated into the
        // script source) — the script itself must not contain the code.
        XCTAssertEqual(handle.evaluatedScripts.first?.contains("123456"), false)
        let payload = handle.evaluatedArguments.first?["payload"] as? [String: Any]
        XCTAssertEqual(payload?["kind"] as? String, "otp")
        XCTAssertEqual(payload?["code"] as? String, "123456")
    }

    // MARK: - full loop

    func testFullStartThenContinueLoop() async throws {
        let ctx = MockExecutionContext()
        let handle = MockAutomationSessionHandle()
        handle.evaluateResults = [.success(Self.awaitingOtp), .success(Self.submitted)]
        ctx.automationHandleToReturn = handle

        let start = try await coinbase.startWithdraw(
            ctx: ctx, payload: Self.payload, overlay: .default, showOverlay: false)
        XCTAssertEqual(start.state, .awaitingInputOtp(details: Self.details))

        let next = try await coinbase.continueWithdraw(
            session: start.session, payload: .otp(code: "654321"))
        guard case .submitted = next else {
            return XCTFail("expected submitted, got \(next)")
        }
    }

    // MARK: - cancel

    func testCancelReturnsParsedBool() async throws {
        let handle = MockAutomationSessionHandle()
        handle.evaluateResults = [.success(["cancelled": true])]
        let cancelled = try await coinbase.cancelWithdraw(session: handle)
        XCTAssertTrue(cancelled)
    }

    // MARK: - mapWithdrawState

    func testMapWithdrawStateRejectsMalformed() {
        XCTAssertThrowsError(try Coinbase.mapWithdrawState(["state": "bogus"]))
        XCTAssertThrowsError(try Coinbase.mapWithdrawState("not a dict"))
        XCTAssertThrowsError(try Coinbase.mapWithdrawState(nil))
    }

    func testMapWithdrawStateRejectedReason() throws {
        let dict: [String: Any] = ["state": "rejected", "reason": "otp_rejected"]
        let state = try Coinbase.mapWithdrawState(dict)
        XCTAssertEqual(state, .rejected(reason: WithdrawRejectReason.otpRejected, pendingTransfer: nil))
    }
}
