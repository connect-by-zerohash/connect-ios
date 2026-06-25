import Testing
import Foundation
import WebKit
@testable import ConnectSDK

@MainActor
@Suite("PostMessageReplySink encodes envelopes")
struct PostMessageReplySinkTests {
    /// We can't easily mock WKWebView without UI, so this suite exercises the
    /// encoder helpers by exposing them via `internal` test-only methods.

    @Test("encodes AutomationWebView response as scraping-webview-response postMessage")
    func encodeAutomationWebViewResponse() throws {
        let resp = ZeroAuthResponse(
            id: "R1", success: true,
            data: .object(["x": .number(1)]),
            error: nil, sessionId: nil
        )
        let s = try PostMessageReplySink.encode(type: "scraping-webview-response", encoded: resp)
        #expect(s.contains(#""type":"scraping-webview-response""#))
        #expect(s.contains(#""id":"R1""#))
        #expect(s.contains(#""x":1"#))
    }

    @Test("encodes BridgeEvent as scraping-webview-event postMessage")
    func encodeAutomationWebViewEvent() throws {
        let ev = BridgeEvent(correlationId: "C1", type: "cancelled", data: nil)
        let s = try PostMessageReplySink.encode(type: "scraping-webview-event", encoded: ev)
        #expect(s.contains(#""type":"scraping-webview-event""#))
        #expect(s.contains(#""correlationId":"C1""#))
    }

    @Test("rejects UIWebView type with invalid characters")
    func rejectsBadType() {
        // Direct call — should not throw, but must produce no JSON string.
        let s = PostMessageReplySink.encodeUIWebViewMessage(type: "evt;alert(1)", data: ["x": "y"])
        #expect(s == nil)
    }

    @Test("encodes UIWebView event")
    func encodeUIWebViewMessage() {
        let s = PostMessageReplySink.encodeUIWebViewMessage(type: "config", data: ["theme": "dark"])
        #expect(s != nil)
        #expect(s!.contains(#""type":"config""#))
        #expect(s!.contains(#""theme":"dark""#))
    }
}
