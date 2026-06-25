import XCTest
@testable import ConnectSDK

/// Phase 1 smoke tests for the withdraw contract types. Deliberately simple —
/// decode the payloads the web app sends, and round-trip the states the SDK
/// returns, asserting the wire discriminators match the extension contract.
final class WithdrawFlowTypesTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    private func encodedObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - StartWithdrawPayload

    func testStartPayloadWithSpecAmount() throws {
        let json = """
        { "asset": "USDC", "network": "ethereum", "address": "0xabc",
          "amount": { "value": "50", "currency": "asset" } }
        """
        let p = try decode(StartWithdrawPayload.self, json)
        XCTAssertEqual(p.asset, "USDC")
        XCTAssertEqual(p.network, "ethereum")
        XCTAssertEqual(p.address, "0xabc")
        XCTAssertEqual(p.amount, .spec(AmountSpec(value: "50", currency: .asset)))
        XCTAssertNil(p.destinationTag)
    }

    func testStartPayloadWithMaxAmountAndNoNetwork() throws {
        let json = """
        { "asset": "BTC", "address": "bc1qxyz", "amount": "max" }
        """
        let p = try decode(StartWithdrawPayload.self, json)
        XCTAssertEqual(p.amount, .max)
        XCTAssertNil(p.network)
    }

    func testStartPayloadInvalidAmountStringThrows() {
        let json = #"{ "asset": "BTC", "address": "x", "amount": "all" }"#
        XCTAssertThrowsError(try decode(StartWithdrawPayload.self, json))
    }

    // MARK: - ContinueWithdrawPayload

    func testContinueOtpDecodes() throws {
        let p = try decode(ContinueWithdrawPayload.self, #"{ "kind": "otp", "code": "123456" }"#)
        XCTAssertEqual(p, .otp(code: "123456"))
    }

    func testContinuePollDecodes() throws {
        let p = try decode(ContinueWithdrawPayload.self, #"{ "kind": "poll" }"#)
        XCTAssertEqual(p, .poll)
    }

    func testContinueUnknownKindThrows() {
        XCTAssertThrowsError(try decode(ContinueWithdrawPayload.self, #"{ "kind": "nope" }"#))
    }

    // MARK: - WithdrawState wire shape

    func testAwaitingInputOtpEncodesDiscriminators() throws {
        let state = WithdrawState.awaitingInputOtp(details: Self.sampleDetails)
        let obj = try encodedObject(state)
        XCTAssertEqual(obj["state"] as? String, "awaiting-input")
        XCTAssertEqual(obj["kind"] as? String, "otp")
        XCTAssertNotNil(obj["details"])
    }

    func testIdVerificationKeepsExplicitNullCompleteBefore() throws {
        let state = WithdrawState.awaitingUserActionIdVerification(
            details: Self.sampleDetails, completeBefore: nil)
        let obj = try encodedObject(state)
        XCTAssertEqual(obj["state"] as? String, "awaiting-user-action")
        XCTAssertEqual(obj["kind"] as? String, "id-verification")
        // contract: completeBefore is `string | null` — key present, value null.
        XCTAssertTrue(obj.keys.contains("completeBefore"))
        XCTAssertTrue(obj["completeBefore"] is NSNull)
    }

    func testSubmittedRoundTrips() throws {
        let state = WithdrawState.submitted(result: WithdrawSubmittedResult(
            status: "PENDING", completeBefore: nil, referenceId: "ref-1",
            sendUuid: "uuid-1", details: Self.sampleDetails))
        let data = try JSONEncoder().encode(state)
        let back = try JSONDecoder().decode(WithdrawState.self, from: data)
        XCTAssertEqual(back, state)
    }

    func testRejectedOtpRetriableRoundTrips() throws {
        let state = WithdrawState.rejected(
            reason: WithdrawRejectReason.otpRejected, pendingTransfer: nil)
        let obj = try encodedObject(state)
        XCTAssertEqual(obj["state"] as? String, "rejected")
        XCTAssertEqual(obj["reason"] as? String, "otp_rejected")
        XCTAssertFalse(obj.keys.contains("pendingTransfer")) // optional key omitted when nil
    }

    private static let sampleDetails = WithdrawDetails(
        fiatAmount: "$50.00", cryptoAmount: "50 USDC", recipient: "0xabc",
        network: "ethereum", timeEstimate: "~2 min", fee: "$0.10")
}
