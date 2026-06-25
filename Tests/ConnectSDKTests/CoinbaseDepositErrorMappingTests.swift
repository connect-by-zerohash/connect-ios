import XCTest
@testable import ConnectSDK

final class CoinbaseDepositErrorMappingTests: XCTestCase {
    // Change A: a JS exception message survives as localizedDescription.
    func testJSExceptionSurfacesMessage() {
        let e = JSException(message: "requires an amount")
        XCTAssertEqual(e.localizedDescription, "requires an amount")
        XCTAssertEqual((e as? LocalizedError)?.errorDescription, "requires an amount")
    }

    // Change B: PlatformError.message is clean (no enum decoration).
    func testPlatformErrorMessageIsClean() {
        XCTAssertEqual(PlatformError.underlying("not logged in").message, "not logged in")
        XCTAssertEqual(PlatformError.invalidJSReturn.message, "invalid JS return")
    }

    // Reviewer-flagged mapResult gap: invalid currency rawValue => amountSubmitted nil.
    func testMapResultInvalidCurrencyDropsAmount() throws {
        let dict: [String: Any] = [
            "address": "0xabc",
            "amountSubmitted": ["value": "10", "requestedCurrency": "crypto", "resolvedSymbol": "USD"],
        ]
        let r = try Coinbase.mapResult(dict, requestedAsset: "USDC", requestedNetwork: nil)
        XCTAssertNil(r.amountSubmitted, "invalid currency rawValue must drop amountSubmitted")
    }
}
