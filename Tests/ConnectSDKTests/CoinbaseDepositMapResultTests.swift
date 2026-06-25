import XCTest
@testable import ConnectSDK

final class CoinbaseDepositMapResultTests: XCTestCase {
    func testMapsMinimalResult() throws {
        let dict: [String: Any] = [
            "address": "0xabc",
            "destinationTag": "",
            "network": "base",
            "asset": "USDC",
            "warnings": ["w1"],
            "depositUri": "ethereum:0xabc",
        ]
        let r = try Coinbase.mapResult(dict, requestedAsset: "USDC", requestedNetwork: "base")
        XCTAssertEqual(r.address, "0xabc")
        XCTAssertEqual(r.destinationTag, "")
        XCTAssertEqual(r.network, "base")
        XCTAssertEqual(r.asset, "USDC")
        XCTAssertEqual(r.warnings, ["w1"])
        XCTAssertEqual(r.depositUri, "ethereum:0xabc")
        XCTAssertNil(r.amountSubmitted)
    }

    func testMapsAmountSubmitted() throws {
        let dict: [String: Any] = [
            "address": "lnbc1",
            "destinationTag": "",
            "network": "lightning",
            "asset": "BTC",
            "warnings": [],
            "depositUri": "lightning:lnbc1",
            "amountSubmitted": [
                "value": "10",
                "requestedCurrency": "fiat",
                "resolvedSymbol": "BTC",
            ],
        ]
        let r = try Coinbase.mapResult(dict, requestedAsset: "BTC", requestedNetwork: "lightning")
        XCTAssertEqual(r.amountSubmitted?.value, "10")
        XCTAssertEqual(r.amountSubmitted?.requestedCurrency, .fiat)
        XCTAssertEqual(r.amountSubmitted?.resolvedSymbol, "BTC")
    }

    func testThrowsWhenAddressMissingOrEmpty() {
        XCTAssertThrowsError(try Coinbase.mapResult(["address": ""], requestedAsset: "BTC", requestedNetwork: nil))
        XCTAssertThrowsError(try Coinbase.mapResult([:], requestedAsset: "BTC", requestedNetwork: nil))
    }

    func testFallsBackToRequestedAssetAndNetworkWhenMissing() throws {
        let dict: [String: Any] = ["address": "0xabc"]
        let r = try Coinbase.mapResult(dict, requestedAsset: "USDC", requestedNetwork: "base")
        XCTAssertEqual(r.asset, "USDC")
        XCTAssertEqual(r.network, "base")
        XCTAssertEqual(r.destinationTag, "")
        XCTAssertEqual(r.warnings, [])
        XCTAssertEqual(r.depositUri, "")
    }

    func testIgnoresPartialAmountSubmitted() throws {
        // Missing resolvedSymbol => amountSubmitted should be nil (not partially built).
        let dict: [String: Any] = [
            "address": "0xabc",
            "amountSubmitted": ["value": "10", "requestedCurrency": "fiat"],
        ]
        let r = try Coinbase.mapResult(dict, requestedAsset: "USDC", requestedNetwork: nil)
        XCTAssertNil(r.amountSubmitted)
    }
}
