import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("NativeIOSMessageHandler routes by envelope role")
struct NativeIOSMessageHandlerTests {

    @Test("body with role=zeroauth-host parses to ZeroAuthRequest")
    func routesAutomationWebView() async throws {
        let bodyJSON = #"""
        {"id":"X1","role":"zeroauth-host","platform":"core","operation":"core.ping"}
        """#
        let parsed = try JSONDecoder().decode(ZeroAuthRequest.self, from: Data(bodyJSON.utf8))
        #expect(parsed.role == "zeroauth-host")
        #expect(parsed.operation == "core.ping")
    }

    @Test("body without role parses as UIWebView JSON object with `type`")
    func routesUIWebView() throws {
        let bodyJSON = #"{"type":"page-ready"}"#
        let obj = try JSONSerialization.jsonObject(with: Data(bodyJSON.utf8)) as? [String: Any]
        #expect(obj?["type"] as? String == "page-ready")
    }
}
