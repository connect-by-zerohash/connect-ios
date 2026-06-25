import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("UIWebViewMessageRouter routing")
struct UIWebViewMessageRouterTests {

    final class Spy: UIWebViewMessageRouterDelegate {
        var contentReady = 0
        var navigates: [(url: String, target: String?)] = []
        var closes = 0
        var errors: [(data: [String: Any], json: String)] = []
        var events: [(data: [String: Any], json: String)] = []
        var deposits: [(data: [String: Any], json: String)] = []
        var withdrawals: [(data: [String: Any], json: String)] = []

        func uiWebViewRouterDidReceiveContentReady(_ router: UIWebViewMessageRouter) { contentReady += 1 }
        func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveNavigate url: String, mobileTarget: String?) {
            navigates.append((url, mobileTarget))
        }
        func uiWebViewRouterDidReceiveClose(_ router: UIWebViewMessageRouter) { closes += 1 }
        func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveError data: [String: Any], jsonString: String) {
            errors.append((data, jsonString))
        }
        func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveEvent data: [String: Any], jsonString: String) {
            events.append((data, jsonString))
        }
        func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveDeposit data: [String: Any], jsonString: String) {
            deposits.append((data, jsonString))
        }
        func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveWithdrawal data: [String: Any], jsonString: String) {
            withdrawals.append((data, jsonString))
        }
    }

    final class SendBox {
        var sent: [[String: Any]] = []
        func append(_ m: [String: Any]) { sent.append(m) }
    }

    private func makeRouter(spy: Spy, sentBox: SendBox) -> UIWebViewMessageRouter {
        let router = UIWebViewMessageRouter(
            initialMessages: { [
                ("jwt",    ["token": "T", "env": "sandbox"]),
                ("config", ["theme": "system"]),
            ] },
            send: { msg in sentBox.append(msg) }
        )
        router.delegate = spy
        return router
    }

    @Test("page-ready triggers initial messages send")
    func pageReadyEmitsInitialMessages() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "page-ready"], jsonString: #"{"type":"page-ready"}"#)
        #expect(box.sent.count == 2)
        #expect(box.sent[0]["type"] as? String == "jwt")
        #expect(box.sent[1]["type"] as? String == "config")
    }

    @Test("content-ready forwards to delegate")
    func contentReady() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "content-ready"], jsonString: "")
        #expect(spy.contentReady == 1)
    }

    @Test("navigate forwards URL and mobileTarget")
    func navigate() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        let json: [String: Any] = ["type": "navigate",
                                   "data": ["url": "https://x.test", "mobileTarget": "in_app"]]
        router.handle(jsonObject: json, jsonString: "")
        #expect(spy.navigates.count == 1)
        #expect(spy.navigates[0].url == "https://x.test")
        #expect(spy.navigates[0].target == "in_app")
    }

    @Test("close forwards to delegate")
    func close() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "close"], jsonString: "")
        #expect(spy.closes == 1)
    }

    @Test("error forwards data and jsonString")
    func errorForwarded() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "error", "data": ["code": "E"]],
                      jsonString: #"{"type":"error","data":{"code":"E"}}"#)
        #expect(spy.errors.count == 1)
        #expect(spy.errors[0].data["code"] as? String == "E")
        #expect(spy.errors[0].json.contains(#""code":"E""#))
    }

    @Test("event forwards data and jsonString")
    func eventForwarded() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "event", "data": ["kind": "x"]],
                      jsonString: "{}")
        #expect(spy.events.count == 1)
    }

    @Test("deposit forwards data")
    func depositForwarded() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "deposit", "data": ["depositId": "d1"]],
                      jsonString: "{}")
        #expect(spy.deposits.count == 1)
        #expect(spy.deposits[0].data["depositId"] as? String == "d1")
    }

    @Test("withdrawal forwards data")
    func withdrawalForwarded() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "withdrawal", "data": ["withdrawalId": "w1"]],
                      jsonString: "{}")
        #expect(spy.withdrawals.count == 1)
    }

    @Test("unknown type is silently dropped")
    func unknownType() {
        let spy = Spy(); let box = SendBox()
        let router = makeRouter(spy: spy, sentBox: box)
        router.handle(jsonObject: ["type": "made-up"], jsonString: "")
        #expect(spy.contentReady == 0 && spy.closes == 0 && spy.events.isEmpty)
    }
}
