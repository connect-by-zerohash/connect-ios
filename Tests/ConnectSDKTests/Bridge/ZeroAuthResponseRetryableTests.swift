import Testing
import Foundation
@testable import ConnectSDK

@Suite("ZeroAuthResponse retryable")
struct ZeroAuthResponseRetryableTests {

    @Test("retryable defaults to false and encodes")
    func defaultsFalse() throws {
        let resp = ZeroAuthResponse(id: "1", success: true, data: nil, error: nil, sessionId: nil)
        #expect(resp.retryable == false)
        let data = try JSONEncoder().encode(resp)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"retryable\":false"))
    }

    @Test("retryable can be set true")
    func canBeTrue() throws {
        let resp = ZeroAuthResponse(
            id: "1", success: false, data: nil,
            error: "BALANCES_INDETERMINATE: CryptoQuery — could not load a complete response",
            sessionId: nil, retryable: true)
        #expect(resp.retryable == true)
    }
}
