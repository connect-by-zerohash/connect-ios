//
//  WebViewMessageHandler.swift
//  ConnectSDK
//
//  Handles JavaScript message communication for WebViewController
//

import UIKit
import WebKit

@MainActor
protocol WebViewMessageHandlerDelegate: AnyObject {
    func messageHandlerDidReceivePageReady(_ handler: WebViewMessageHandler)
    func messageHandlerDidReceiveContentReady(_ handler: WebViewMessageHandler)
    func messageHandler(_ handler: WebViewMessageHandler, didReceiveNavigate url: String, mobileTarget: String?)
    func messageHandlerDidReceiveClose(_ handler: WebViewMessageHandler)
    func messageHandler(_ handler: WebViewMessageHandler, didReceiveError data: [String: Any], jsonString: String)
    func messageHandler(_ handler: WebViewMessageHandler, didReceiveEvent data: [String: Any], jsonString: String)
    func messageHandler(_ handler: WebViewMessageHandler, didReceiveDeposit data: [String: Any], jsonString: String)
}

class WebViewMessageHandler: NSObject {

    // MARK: - Properties

    weak var delegate: WebViewMessageHandlerDelegate?
    private weak var webView: WKWebView?
    private let jwt: String
    private let theme: String
    private let environment: Environment

    // Allowlist of trusted origins for JavaScript messages
    private let allowedOrigins = ["sdk.connect.xyz"]

    // MARK: - Initialization

    init(webView: WKWebView, jwt: String, theme: String, environment: Environment) {
        self.webView = webView
        self.jwt = jwt
        self.theme = theme
        self.environment = environment
        super.init()
    }

    // MARK: - Public Methods

    func setupMessageHandlers() {
        webView?.configuration.userContentController.add(self, name: "NativeIOS")
    }

    func sendMessageToPage(type: String, data: [String: Any]) {
        guard let webView = webView else { return }

        do {
            // Validate type parameter to prevent JavaScript injection
            // Only allow alphanumeric characters and hyphens
            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
            guard type.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
                print("Error: Invalid message type contains disallowed characters: \(type)")
                return
            }

            // Create complete message object and serialize it all at once
            // This avoids string interpolation and potential injection
            let message: [String: Any] = [
                "type": type,
                "data": data
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: message)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("Error: Failed to encode message as UTF-8")
                return
            }

            // Use template without string interpolation for the message content
            let script = "window.postMessage(\(jsonString));"
            webView.evaluateJavaScript(
                script,
                completionHandler: { (result, error) in
                    if let error = error {
                        print("Error sending message to WebView:", error.localizedDescription)
                    }
                })
        } catch {
            print("Error serializing JSON: \(error)")
        }
    }

    func sendInitialMessages() {
        sendMessageToPage(type: "jwt", data: ["token": jwt, "env": environment.rawValue])
        sendMessageToPage(type: "config", data: ["theme": theme])
    }

    func sendOAuthResult(success: Bool, connectionId: String? = nil, error: String? = nil) {
        if success, let connectionId = connectionId {
            sendMessageToPage(type: "oauth-success", data: ["connectionId": connectionId])
        } else {
            sendMessageToPage(
                type: "oauth-error",
                data: ["error": error ?? "Error processing the data."]
            )
        }
    }
}

// MARK: - WKScriptMessageHandler

extension WebViewMessageHandler: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        // Validate the origin of the message
        let host = message.frameInfo.securityOrigin.host

        // Check if the host is in the allowlist
        guard allowedOrigins.contains(host) else {
            print("Message rejected from unauthorized origin: \(host)")
            return
        }

        guard let jsonString = message.body as? String else {
            print("Unexpected message type:", type(of: message.body))
            return
        }

        do {
            guard
                let jsonObject = try JSONSerialization.jsonObject(
                    with: Data(jsonString.utf8), options: []) as? [String: Any]
            else {
                print("Failed to convert JSON string to a JSON object")
                return
            }

            guard let messageType = jsonObject["type"] as? String else {
                print("Missing 'type' key in JSON object")
                return
            }

            Task { @MainActor in
                handleMessage(type: messageType, jsonObject: jsonObject, jsonString: jsonString)
            }

        } catch {
            print("Error parsing JSON:", error.localizedDescription)
        }
    }

    @MainActor
    private func handleMessage(type: String, jsonObject: [String: Any], jsonString: String) {
        switch type {
        case "page-ready":
            sendInitialMessages()
            delegate?.messageHandlerDidReceivePageReady(self)

        case "content-ready":
            delegate?.messageHandlerDidReceiveContentReady(self)

        case "navigate":
            if let data = jsonObject["data"] as? [String: Any],
               let url = data["url"] as? String {
                let mobileTarget = data["mobileTarget"] as? String
                delegate?.messageHandler(self, didReceiveNavigate: url, mobileTarget: mobileTarget)
            }

        case "close":
            delegate?.messageHandlerDidReceiveClose(self)

        case "error":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.messageHandler(self, didReceiveError: data, jsonString: jsonString)
            }

        case "event":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.messageHandler(self, didReceiveEvent: data, jsonString: jsonString)
            }

        case "deposit":
            if let data = jsonObject["data"] as? [String: Any] {
                delegate?.messageHandler(self, didReceiveDeposit: data, jsonString: jsonString)
            }

        default:
            print("Unknown message type:", type)
        }
    }
}
