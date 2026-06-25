import XCTest
@testable import ConnectSDK

final class DepositAddressResultTests: XCTestCase {
    func testEncodesAllRequiredFieldsAndOmitsAmountWhenNil() throws {
        let result = DepositAddressResult(
            address: "0xabc",
            destinationTag: "",
            network: "base",
            asset: "USDC",
            warnings: ["Only send USDC on Base"],
            depositUri: "ethereum:0xabc@8453",
            amountSubmitted: nil
        )
        let data = try JSONEncoder().encode(result)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(obj["address"] as? String, "0xabc")
        XCTAssertEqual(obj["destinationTag"] as? String, "")
        XCTAssertEqual(obj["network"] as? String, "base")
        XCTAssertEqual(obj["asset"] as? String, "USDC")
        XCTAssertEqual((obj["warnings"] as? [String]), ["Only send USDC on Base"])
        XCTAssertEqual(obj["depositUri"] as? String, "ethereum:0xabc@8453")
        XCTAssertNil(obj["amountSubmitted"], "amountSubmitted must be omitted when nil")
    }

    func testEncodesAmountSubmittedWhenPresent() throws {
        let result = DepositAddressResult(
            address: "lnbc1...",
            destinationTag: "",
            network: "lightning",
            asset: "BTC",
            warnings: [],
            depositUri: "lightning:lnbc1...",
            amountSubmitted: AmountSubmitted(value: "10", requestedCurrency: .fiat, resolvedSymbol: "USD")
        )
        let data = try JSONEncoder().encode(result)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let amount = obj["amountSubmitted"] as! [String: Any]
        XCTAssertEqual(amount["value"] as? String, "10")
        XCTAssertEqual(amount["requestedCurrency"] as? String, "fiat")
        XCTAssertEqual(amount["resolvedSymbol"] as? String, "USD")
    }
}
