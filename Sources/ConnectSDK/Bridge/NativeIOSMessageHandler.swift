import Foundation
import WebKit

@MainActor
final class NativeIOSMessageHandler: NSObject, WKScriptMessageHandler {
    private let uiWebView: UIWebViewMessageRouter
    private let automationWebView: AutomationWebViewMessageRouter
    private let allowedOrigins: Set<String>

    /// - Parameter allowedOrigins: hosts whose `WKScriptMessage.frameInfo`
    ///   security origin is accepted. **Must not be empty** — passing an
    ///   empty set is a programmer error and traps. Tests provide an
    ///   explicit set that matches their fixture's `baseURL`.
    init(
        uiWebView: UIWebViewMessageRouter,
        automationWebView: AutomationWebViewMessageRouter,
        allowedOrigins: Set<String>
    ) {
        precondition(!allowedOrigins.isEmpty,
            "NativeIOSMessageHandler requires a non-empty allowlist (R4)")
        self.uiWebView = uiWebView
        self.automationWebView = automationWebView
        self.allowedOrigins = allowedOrigins
        super.init()
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        // Capture frame info (which is bound to the main actor in WKWebView's
        // delivery contract) before hopping off-actor.
        let host = message.frameInfo.securityOrigin.host
        let body = message.body

        Task { @MainActor in
            self.process(host: host, body: body)
        }
    }

    private func process(host: String, body: Any) {
        guard allowedOrigins.contains(host) else {
            Log.bridge.error("rejected message from unauthorized origin: \(host, privacy: .private)")
            return
        }

        guard let bodyData = MessageBodyDecoder.data(from: body) else {
            Log.bridge.error("unrecognized body type: \(String(describing: type(of: body)), privacy: .public)")
            return
        }

        guard let parsed = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            Log.bridge.error("body is not a JSON object")
            return
        }

        if MessageBodyDecoder.isAutomationWebViewRequest(parsed) {
            guard let req = try? JSONDecoder().decode(ZeroAuthRequest.self, from: bodyData) else {
                // Malformed envelope: route to AutomationWebView error path so the JS side gets a structured reply.
                Log.bridge.error("automation envelope failed to decode; routing to invalidEnvelopeProbe")
                Task { await self.automationWebView.dispatch(.invalidEnvelopeProbe()) }
                return
            }
            Log.bridge.debug("inbound automation envelope id=\(req.id, privacy: .public) platform=\(req.platform, privacy: .public) op=\(req.operation, privacy: .public) origin=\(host, privacy: .private)")
            Task { await self.automationWebView.dispatch(req) }
            return
        }

        let jsonString = String(data: bodyData, encoding: .utf8) ?? ""
        let msgType = parsed["type"] as? String ?? "?"
        Log.bridge.debug("inbound UIWebView msg type=\(msgType, privacy: .public) origin=\(host, privacy: .private)")
        uiWebView.handle(jsonObject: parsed, jsonString: jsonString)
    }
}

private extension ZeroAuthRequest {
    /// Synthetic request used to surface "invalid envelope" replies through the
    /// AutomationWebView router when the body has `role=zeroauth-host` but doesn't decode.
    /// The router will reject with `.platformNotRegistered("?")` because the
    /// platform field is empty — but `?` as a sentinel id keeps any pending
    /// JS-side promise from leaking. Replaced with a dedicated path in a
    /// future revision.
    static func invalidEnvelopeProbe() -> ZeroAuthRequest {
        ZeroAuthRequest(id: "?", role: WireRole.host, platform: "?", operation: "?")
    }
}
