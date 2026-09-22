import Testing
import Foundation
@testable import ConnectSDK

@Suite("AssetBalance model")
struct BalanceFlowTests {

    @Test("round-trips through Codable with optionals present")
    func roundTripFull() throws {
        let b = AssetBalance(
            key: "BTC", label: "Bitcoin", amount: "0.5", notional: "30000",
            currency: "USD", totalStakedPercent: "12.5", precision: 8,
            extractedAt: "2026-06-16T00:00:00Z")
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(AssetBalance.self, from: data)
        #expect(decoded == b)
    }

    @Test("round-trips with nil optionals")
    func roundTripNils() throws {
        let b = AssetBalance(
            key: "USD", label: "US Dollar", amount: "100", notional: "100",
            currency: nil, totalStakedPercent: nil, precision: nil,
            extractedAt: "2026-06-16T00:00:00Z")
        let data = try JSONEncoder().encode(b)
        let decoded = try JSONDecoder().decode(AssetBalance.self, from: data)
        #expect(decoded == b)
        #expect(decoded.currency == nil)
    }

    // The rows go out as JSON, and the contract types every optional as
    // `T | null` rather than as an optional key (`docs/contracts/types.md`). The
    // synthesized `Codable` conformance uses `encodeIfPresent`, which drops a nil
    // key entirely, so rows were leaving with `totalStakedPercent` missing
    // instead of null.
    //
    // A round-trip test cannot catch this: decoding accepts both shapes, so it
    // stays green either way. The wire shape has to be asserted directly.
    private func encodedObject(_ row: AssetBalance) throws -> [String: Any] {
        let data = try JSONEncoder().encode(row)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private var rowWithNoOptionals: AssetBalance {
        AssetBalance(
            key: "BTC", label: "Bitcoin", amount: "0.5321", notional: "34120.55",
            currency: nil, totalStakedPercent: nil, precision: nil,
            extractedAt: "2026-07-27T18:04:11.000Z")
    }

    @Test("a nil staked percent is encoded as null rather than omitted")
    func nilStakedPercentIsNull() throws {
        let json = try encodedObject(rowWithNoOptionals)
        #expect(
            json.keys.contains("totalStakedPercent"),
            "the key must survive: JS sees a dropped key as undefined, not null")
        #expect(json["totalStakedPercent"] is NSNull)
    }

    @Test("the other nil optionals are also encoded as null")
    func otherNilOptionalsAreNull() throws {
        let json = try encodedObject(rowWithNoOptionals)
        #expect(json["currency"] is NSNull)
        #expect(json["precision"] is NSNull)
    }

    @Test("every contract field is present exactly once")
    func everyContractFieldIsPresent() throws {
        let json = try encodedObject(rowWithNoOptionals)
        #expect(
            Set(json.keys) == [
                "key", "label", "amount", "notional", "currency", "totalStakedPercent",
                "precision", "extractedAt",
            ])
    }

    @Test("present values still encode as themselves")
    func presentValuesSurvive() throws {
        let json = try encodedObject(
            AssetBalance(
                key: "ETH", label: "Ethereum", amount: "10", notional: "25000",
                currency: "USD", totalStakedPercent: "50", precision: 8,
                extractedAt: "2026-07-27T18:04:11.000Z"))
        #expect(json["currency"] as? String == "USD")
        #expect(json["totalStakedPercent"] as? String == "50")
        #expect(json["precision"] as? Int == 8)
    }

    // A stored or replayed row from an older build has the keys missing, so
    // decoding must keep accepting that shape alongside an explicit null.
    @Test("decoding accepts both an explicit null and a missing key")
    func decodingAcceptsBothShapes() throws {
        let explicitNull = """
            {"key":"BTC","label":"Bitcoin","amount":"1","notional":"2",
             "currency":null,"totalStakedPercent":null,"precision":null,
             "extractedAt":"2026-07-27T18:04:11.000Z"}
            """
        let missingKeys = """
            {"key":"BTC","label":"Bitcoin","amount":"1","notional":"2",
             "extractedAt":"2026-07-27T18:04:11.000Z"}
            """

        for payload in [explicitNull, missingKeys] {
            let row = try JSONDecoder().decode(AssetBalance.self, from: Data(payload.utf8))
            #expect(row.totalStakedPercent == nil)
            #expect(row.currency == nil)
            #expect(row.precision == nil)
        }
    }
}
