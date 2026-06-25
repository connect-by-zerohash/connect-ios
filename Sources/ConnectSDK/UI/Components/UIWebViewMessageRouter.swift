import Foundation

@MainActor
final class UIWebViewMessageRouter {
    weak var delegate: UIWebViewMessageRouterDelegate?

    private let initialMessages: () -> [(type: String, data: [String: Any])]
    private let send: ([String: Any]) -> Void

    init(
        initialMessages: @escaping () -> [(type: String, data: [String: Any])],
        send: @escaping ([String: Any]) -> Void
    ) {
        self.initialMessages = initialMessages
        self.send = send
    }

    func handle(jsonObject: [String: Any], jsonString: String) {
        guard let messageType = jsonObject["type"] as? String else { return }
        switch messageType {
        case "page-ready":
            for m in initialMessages() {
                send(["type": m.type, "data": m.data])
            }
        case "content-ready":
            delegate?.uiWebViewRouterDidReceiveContentReady(self)
        case "navigate":
            if let data = jsonObject["data"] as? [String: Any], let url = data["url"] as? String {
                delegate?.uiWebViewRouter(self, didReceiveNavigate: url,
                                       mobileTarget: data["mobileTarget"] as? String)
            }
        case "close":
            delegate?.uiWebViewRouterDidReceiveClose(self)
        case "error":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.uiWebViewRouter(self, didReceiveError: data, jsonString: jsonString)
            }
        case "event":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.uiWebViewRouter(self, didReceiveEvent: data, jsonString: jsonString)
            }
        case "deposit":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.uiWebViewRouter(self, didReceiveDeposit: data, jsonString: jsonString)
            }
        case "withdrawal":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.uiWebViewRouter(self, didReceiveWithdrawal: data, jsonString: jsonString)
            }
        default:
            print("[NativeIOS] Unknown UIWebView type:", messageType)
        }
    }
}
