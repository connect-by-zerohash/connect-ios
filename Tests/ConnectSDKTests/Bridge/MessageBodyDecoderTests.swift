import Testing
import Foundation
@testable import ConnectSDK

@Suite("MessageBodyDecoder")
struct MessageBodyDecoderTests {

    @Test("decodes a JSON String body to Data")
    func decodeStringBody() {
        let body: Any = #"{"hi":1}"#
        let d = MessageBodyDecoder.data(from: body)
        #expect(d != nil)
    }

    @Test("decodes an NSDictionary body to Data")
    func decodeDictBody() {
        let body: Any = ["hi": 1] as NSDictionary
        let d = MessageBodyDecoder.data(from: body)
        #expect(d != nil)
    }

    @Test("rejects values that are neither String nor JSON-serialisable")
    func decodeGarbage() {
        let body: Any = Date()
        let d = MessageBodyDecoder.data(from: body)
        #expect(d == nil)
    }

    @Test("identifies a AutomationWebView envelope by role")
    func detectRole() {
        #expect(MessageBodyDecoder.isAutomationWebViewRequest(["role": "zeroauth-host"]))
        #expect(!MessageBodyDecoder.isAutomationWebViewRequest(["role": "other"]))
        #expect(!MessageBodyDecoder.isAutomationWebViewRequest(["type": "page-ready"]))
    }
}
