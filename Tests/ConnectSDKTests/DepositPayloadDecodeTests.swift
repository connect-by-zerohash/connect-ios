import XCTest
@testable import ConnectSDK

final class DepositPayloadDecodeTests: XCTestCase {
    func testDecodesAssetOnly() throws {
        let json: JSONValue = .object(["asset": .string("BTC")])
        let payload = try GetDepositAddressPayload.decode(from: json)
        XCTAssertEqual(payload.asset, "BTC")
        XCTAssertNil(payload.network)
        XCTAssertNil(payload.amount)
    }

    func testDecodesAssetNetworkAmount() throws {
        let json: JSONValue = .object([
            "asset": .string("BTC"),
            "network": .string("lightning"),
            "amount": .object(["value": .string("10"), "currency": .string("fiat")]),
        ])
        let payload = try GetDepositAddressPayload.decode(from: json)
        XCTAssertEqual(payload.asset, "BTC")
        XCTAssertEqual(payload.network, "lightning")
        XCTAssertEqual(payload.amount?.value, "10")
        XCTAssertEqual(payload.amount?.currency, .fiat)
    }

    func testThrowsWhenAssetMissing() {
        let json: JSONValue = .object(["network": .string("base")])
        XCTAssertThrowsError(try GetDepositAddressPayload.decode(from: json))
    }

    func testThrowsWhenPayloadNil() {
        XCTAssertThrowsError(try GetDepositAddressPayload.decode(from: nil))
    }
}
