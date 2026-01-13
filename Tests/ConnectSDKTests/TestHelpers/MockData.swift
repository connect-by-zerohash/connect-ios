//
//  MockData.swift
//  ConnectSDKTests
//
//  Test fixtures and mock data factory

import Foundation
import WebKit
@testable import ConnectSDK

enum MockData {

    // MARK: - GenericEvent Fixtures

    static func genericEvent(
        type: String = "test-event",
        data: [String: Any] = ["key": "value"],
        jsonString: String = "{\"key\": \"value\"}",
        timestamp: Date = Date()
    ) -> GenericEvent {
        return GenericEvent(
            type: type,
            data: data,
            jsonString: jsonString,
            timestamp: timestamp
        )
    }

    static var emptyGenericEvent: GenericEvent {
        return genericEvent(data: [:], jsonString: "{}")
    }

    // MARK: - ErrorEvent Fixtures

    static func errorEvent(
        code: String = "ERROR_001",
        message: String = "Test error",
        data: [String: Any] = [:],
        jsonString: String = "{}",
        timestamp: Date = Date()
    ) -> ErrorEvent {
        return ErrorEvent(
            code: code,
            message: message,
            data: data,
            jsonString: jsonString,
            timestamp: timestamp
        )
    }

    static var networkError: ErrorEvent {
        return errorEvent(code: "NETWORK_ERROR", message: "Network connection failed")
    }

    static var authError: ErrorEvent {
        return errorEvent(code: "AUTH_ERROR", message: "Authentication failed")
    }

    // MARK: - DepositEvent Fixtures

    static func depositEvent(
        depositId: String = "deposit-123",
        status: String = "processed",
        assetId: String = "BTC",
        networkId: String = "bitcoin",
        amount: String = "0.5",
        jsonString: String = "{}",
        timestamp: Date = Date()
    ) -> DepositEvent {
        let data: [String: Any] = [
            "depositId": depositId,
            "status": ["value": status],
            "assetId": assetId,
            "networkId": networkId,
            "amount": amount
        ]
        return DepositEvent(
            data: data,
            jsonString: jsonString,
            timestamp: timestamp
        )
    }

    static var successfulDeposit: DepositEvent {
        return depositEvent(status: "processed")
    }

    static var pendingDeposit: DepositEvent {
        return depositEvent(status: "pending")
    }

    static var emptyDepositEvent: DepositEvent {
        return DepositEvent(data: [:], jsonString: "{}", timestamp: Date())
    }

    // MARK: - ConnectSession Fixtures

    static func connectSession(app: ConnectApp = .auth) -> ConnectSession {
        return ConnectSession(app: app)
    }

    static var authSession: ConnectSession {
        return connectSession(app: .auth)
    }

    // MARK: - AuthCallbacks Fixtures

    static func authCallbacks(
        onClose: (() -> Void)? = nil,
        onError: ((ErrorEvent) -> Void)? = nil,
        onEvent: ((GenericEvent) -> Void)? = nil,
        onDeposit: ((DepositEvent) -> Void)? = nil
    ) -> AuthCallbacks {
        return AuthCallbacks(
            onClose: onClose,
            onError: onError,
            onEvent: onEvent,
            onDeposit: onDeposit
        )
    }

    static var emptyCallbacks: AuthCallbacks {
        return authCallbacks()
    }

    // MARK: - Raw Data Fixtures

    static var errorDataWithCode: [String: Any] {
        return [
            "type": "network",
            "message": "Connection timeout",
            "code": "NET_001"
        ]
    }

    static var errorDataWithErrorCode: [String: Any] {
        return [
            "type": "authentication",
            "reason": "Invalid credentials",
            "errorCode": "AUTH_001"
        ]
    }

    static var errorDataMinimal: [String: Any] {
        return ["type": "unknown"]
    }

    static var errorDataEmpty: [String: Any] {
        return [:]
    }

    // MARK: - OAuth Fixtures

    static func oauthCallbackURLWithCode(_ code: String = "auth_code_123", state: String = "state_xyz") -> URL {
        return .oauthCallback(code: code, state: state)
    }

    static func oauthCallbackURLWithFragment(accessToken: String = "access_token_123") -> URL {
        return .oauthCallbackWithFragment(accessToken: accessToken)
    }

    static func invalidOauthCallbackURL() -> URL {
        return .invalidOauthCallback()
    }

    // MARK: - WebView Message Fixtures

    static func webViewMessage(type: String, data: [String: Any] = [:]) -> [String: Any] {
        var message: [String: Any] = ["type": type]
        if !data.isEmpty {
            message["data"] = data
        }
        return message
    }

    static func navigationMessage(url: String, mobileTarget: String? = nil) -> [String: Any] {
        var data: [String: Any] = ["url": url]
        if let mobileTarget = mobileTarget {
            data["mobileTarget"] = mobileTarget
        }
        return webViewMessage(type: "navigate", data: data)
    }

    static func errorEventMessage(code: String = "ERR_001", reason: String = "Error occurred") -> [String: Any] {
        return webViewMessage(
            type: "error",
            data: [
                "errorCode": code,
                "reason": reason,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    static func depositEventMessage(depositId: String = "dep-123", status: String = "processed") -> [String: Any] {
        return webViewMessage(
            type: "deposit",
            data: [
                "depositId": depositId,
                "status": ["value": status],
                "assetId": "BTC",
                "networkId": "bitcoin",
                "amount": "1.5"
            ]
        )
    }

    static func pageReadyMessage() -> [String: Any] {
        return webViewMessage(type: "page-ready")
    }

    static func contentReadyMessage() -> [String: Any] {
        return webViewMessage(type: "content-ready")
    }

    static func closeMessage() -> [String: Any] {
        return webViewMessage(type: "close")
    }

    // MARK: - Mock Objects Factories

    static func mockASWebAuthenticationSession(
        onCompletion: @escaping (URL?, Error?) -> Void = { _, _ in }
    ) -> MockASWebAuthenticationSession {
        return MockASWebAuthenticationSession(completionHandler: onCompletion)
    }

    // MARK: - JSON String Fixtures

    static var pageReadyJSON: String {
        return "{\"type\": \"page-ready\"}"
    }

    static var contentReadyJSON: String {
        return "{\"type\": \"content-ready\"}"
    }

    static func navigationJSON(url: String) -> String {
        return "{\"type\": \"navigate\", \"data\": {\"url\": \"\(url)\"}}"
    }

    static func errorEventJSON(code: String = "ERR_001", reason: String = "Error") -> String {
        return "{\"type\": \"error\", \"data\": {\"errorCode\": \"\(code)\", \"reason\": \"\(reason)\"}}"
    }

    static var closeJSON: String {
        return "{\"type\": \"close\"}"
    }

    // MARK: - WebViewController Fixtures

    static func mockConnectSession(
        app: ConnectApp = .auth,
        isActive: Bool = true
    ) -> ConnectSession {
        let session = ConnectSession(app: app)
        session.isActive = isActive
        return session
    }

    static func mockAuthCallbackHandlerCallbacks(
        onClose: (() -> Void)? = nil,
        onError: ((ErrorEvent) -> Void)? = nil,
        onEvent: ((GenericEvent) -> Void)? = nil,
        onDeposit: ((DepositEvent) -> Void)? = nil
    ) -> AuthCallbacks {
        return AuthCallbacks(
            onClose: onClose,
            onError: onError,
            onEvent: onEvent,
            onDeposit: onDeposit
        )
    }

    // MARK: - ConnectAuthSession Fixtures

    @MainActor
    static func connectAuthSession(
        jwt: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c",
        environment: Environment = .sandbox,
        theme: Theme = .light,
        callbacks: AuthCallbacks = AuthCallbacks()
    ) -> ConnectAuthSession {
        return ConnectAuthSession(
            jwt: jwt,
            environment: environment,
            theme: theme,
            callbacks: callbacks
        )
    }

    static var validJWT: String {
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    }

    static var emptyJWT: String {
        return ""
    }

    // MARK: - Navigation Controller Fixtures

    @MainActor
    static func mockUINavigationController(
        rootViewController: UIViewController? = nil
    ) -> UINavigationController {
        let controller = rootViewController ?? UIViewController()
        return UINavigationController(rootViewController: controller)
    }

    // MARK: - Theme and Environment Fixtures

    static func traitCollection(
        userInterfaceStyle: UIUserInterfaceStyle = .light
    ) -> UITraitCollection {
        return UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        ])
    }

    static var lightTraitCollection: UITraitCollection {
        return traitCollection(userInterfaceStyle: .light)
    }

    static var darkTraitCollection: UITraitCollection {
        return traitCollection(userInterfaceStyle: .dark)
    }

    // MARK: - WebViewController Functional Test Fixtures

    @MainActor
    static func webViewControllerCallbacks(
        onClose: (() -> Void)? = nil,
        onError: ((ErrorEvent) -> Void)? = nil,
        onEvent: ((GenericEvent) -> Void)? = nil,
        onDeposit: ((DepositEvent) -> Void)? = nil
    ) -> AuthCallbacks {
        return AuthCallbacks(
            onClose: onClose,
            onError: onError,
            onEvent: onEvent,
            onDeposit: onDeposit
        )
    }

    @MainActor
    static func authCallbackHandler(
        callbacks: AuthCallbacks = AuthCallbacks()
    ) -> AuthCallbackHandler {
        return AuthCallbackHandler(callbacks: callbacks)
    }

    // MARK: - ConnectAuthSession Callback Tests

    static var callbacksWithAllHandlers: AuthCallbacks {
        return authCallbacks(
            onClose: { },
            onError: { _ in },
            onEvent: { _ in },
            onDeposit: { _ in }
        )
    }

    static var callbacksWithCloseOnly: AuthCallbacks {
        return authCallbacks(onClose: { })
    }

    static var callbacksWithErrorOnly: AuthCallbacks {
        return authCallbacks(onError: { _ in })
    }

    static var callbacksWithDepositOnly: AuthCallbacks {
        return authCallbacks(onDeposit: { _ in })
    }

    static var callbacksWithEventOnly: AuthCallbacks {
        return authCallbacks(onEvent: { _ in })
    }

    // MARK: - Error Scenarios Fixtures

    static var invalidJWTToken: String {
        return "invalid.token.here"
    }

    static var malformedJWT: String {
        return "not-a-valid-jwt"
    }

    // MARK: - Message Handler Integration Fixtures

    static func oauthSuccessMessage(connectionId: String = "conn-123") -> [String: Any] {
        return webViewMessage(
            type: "oauth-success",
            data: ["connectionId": connectionId]
        )
    }

    static func oauthErrorMessage(error: String = "User denied") -> [String: Any] {
        return webViewMessage(
            type: "oauth-error",
            data: ["error": error]
        )
    }

    static func dismissalMessage() -> [String: Any] {
        return webViewMessage(type: "dismiss")
    }

    // MARK: - URL Fixtures for WebViewController

    static var sandboxAuthURL: String {
        return "https://sandbox.example.com/auth"
    }

    static var productionAuthURL: String {
        return "https://api.example.com/auth"
    }

    static var invalidURL: String {
        return "not-a-valid-url"
    }
}
