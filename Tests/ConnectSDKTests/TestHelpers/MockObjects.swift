//
//  MockObjects.swift
//  ConnectSDKTests
//
//  Mock objects and test doubles for testing

import Foundation
import WebKit
@testable import ConnectSDK

// MARK: - OAuth Mocks

/// Mock for ASWebAuthenticationSession to simulate OAuth flows
class MockASWebAuthenticationSession: NSObject {
    var startWasCalled = false
    var cancelWasCalled = false
    private(set) var completionHandlers: [(URL?, Error?) -> Void] = []

    private let completionHandler: (URL?, Error?) -> Void

    init(completionHandler: @escaping (URL?, Error?) -> Void) {
        self.completionHandler = completionHandler
    }

    func start() -> Bool {
        startWasCalled = true
        return true
    }

    func cancel() {
        cancelWasCalled = true
        completionHandler(nil, NSError(domain: "ASWebAuthenticationSession", code: 1, userInfo: nil))
    }

    func simulateSuccess(with url: URL) {
        completionHandler(url, nil)
    }

    func simulateFailure(with error: Error) {
        completionHandler(nil, error)
    }

    func simulateCancel() {
        cancel()
    }
}

// MARK: - WebView Mocks

/// Mock for WKWebView
class MockWKWebView: WKWebView {
    private(set) var evaluatedScripts: [String] = []
    var lastCompletionHandler: ((Any?, Error?) -> Void)?

    func recordEvaluatedScript(_ script: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        evaluatedScripts.append(script)
        lastCompletionHandler = completionHandler
        completionHandler?(nil, nil)
    }

    func simulateJavaScriptError(_ error: Error) {
        lastCompletionHandler?(nil, error)
    }

    func simulateJavaScriptResult(_ result: Any) {
        lastCompletionHandler?(result, nil)
    }
}

/// Mock for WKUserContentController
class MockWKUserContentController: WKUserContentController {
    private(set) var addedHandlers: [(handler: WKScriptMessageHandler, name: String)] = []

    override func add(_ scriptMessageHandler: WKScriptMessageHandler, name: String) {
        addedHandlers.append((scriptMessageHandler, name))
    }
}

/// Mock WKScriptMessage for testing message handler
class MockWKScriptMessage: NSObject {
    let body: Any
    let name: String
    let webView: WKWebView?

    init(body: Any, name: String = "default", webView: WKWebView? = nil) {
        self.body = body
        self.name = name
        self.webView = webView
    }
}

// MARK: - Delegate Spies

/// Spy for WebViewMessageHandlerDelegate to capture callback invocations
class WebViewMessageHandlerDelegateSpy: WebViewMessageHandlerDelegate {
    private(set) var pageReadyCalls = 0
    private(set) var contentReadyCalls = 0
    private(set) var closeCalls = 0

    private(set) var navigateInvocations: [(url: String, mobileTarget: String?)] = []
    private(set) var errorInvocations: [(data: [String: Any], jsonString: String)] = []
    private(set) var eventInvocations: [(data: [String: Any], jsonString: String)] = []
    private(set) var depositInvocations: [(data: [String: Any], jsonString: String)] = []

    func messageHandlerDidReceivePageReady(_ handler: WebViewMessageHandler) {
        pageReadyCalls += 1
    }

    func messageHandlerDidReceiveContentReady(_ handler: WebViewMessageHandler) {
        contentReadyCalls += 1
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveNavigate url: String, mobileTarget: String?) {
        navigateInvocations.append((url: url, mobileTarget: mobileTarget))
    }

    func messageHandlerDidReceiveClose(_ handler: WebViewMessageHandler) {
        closeCalls += 1
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveError data: [String: Any], jsonString: String) {
        errorInvocations.append((data: data, jsonString: jsonString))
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveEvent data: [String: Any], jsonString: String) {
        eventInvocations.append((data: data, jsonString: jsonString))
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveDeposit data: [String: Any], jsonString: String) {
        depositInvocations.append((data: data, jsonString: jsonString))
    }
}

/// Spy for WebViewLoadingManagerDelegate
class WebViewLoadingManagerDelegateSpy: WebViewLoadingManagerDelegate {
    private(set) var retryCalls = 0
    private(set) var closeCalls = 0

    func loadingManagerDidRequestRetry(_ manager: WebViewLoadingManager) {
        retryCalls += 1
    }

    func loadingManagerDidRequestClose(_ manager: WebViewLoadingManager) {
        closeCalls += 1
    }
}

// MARK: - UIKit Mocks

/// Mock UIView for testing
class MockUIView: UIView {
    private(set) var addedSubviews: [UIView] = []
    private(set) var removedSubviews: [UIView] = []
    private(set) var constraintsBatches: [[NSLayoutConstraint]] = []

    override func addSubview(_ view: UIView) {
        addedSubviews.append(view)
        super.addSubview(view)
    }

    override func removeFromSuperview() {
        if let superview = superview {
            if superview.subviews.contains(self) {
                removedSubviews.append(contentsOf: [self])
            }
        }
        super.removeFromSuperview()
    }
}

/// Mock UITraitCollection for testing theme
struct MockUITraitCollection {
    let userInterfaceStyle: UIUserInterfaceStyle

    init(userInterfaceStyle: UIUserInterfaceStyle = .light) {
        self.userInterfaceStyle = userInterfaceStyle
    }
}

// MARK: - Animation Capture

/// Helper to capture UIView.animate calls
actor AnimationCapture {
    struct AnimationCall {
        let duration: TimeInterval
        let delay: TimeInterval
        let options: UIView.AnimationOptions
    }

    private(set) var capturedAnimations: [AnimationCall] = []
    static let shared = AnimationCapture()

    func record(duration: TimeInterval, delay: TimeInterval, options: UIView.AnimationOptions) {
        capturedAnimations.append(AnimationCall(duration: duration, delay: delay, options: options))
    }

    func clear() {
        capturedAnimations.removeAll()
    }
}

// MARK: - Result Builders for URLs

extension URL {
    /// Create OAuth callback URL with query parameters
    static func oauthCallback(code: String = "auth_code_123", state: String = "state_xyz") -> URL {
        var components = URLComponents()
        components.scheme = "connectsdk-oauth"
        components.host = "callback"
        components.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "state", value: state)
        ]
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// Create OAuth callback URL with fragment parameters
    static func oauthCallbackWithFragment(accessToken: String = "access_token_123", tokenType: String = "Bearer") -> URL {
        var components = URLComponents()
        components.scheme = "connectsdk-oauth"
        components.host = "callback"
        components.fragment = "access_token=\(accessToken)&token_type=\(tokenType)"
        return components.url ?? URL(fileURLWithPath: "/")
    }

    /// Create invalid OAuth callback URL
    static func invalidOauthCallback() -> URL {
        return URL(string: "https://example.com/callback?code=123") ?? URL(fileURLWithPath: "/")
    }
}

// MARK: - UIViewController Mock

/// Mock UIViewController for testing presentation and dismissal
class MockUIViewController: UIViewController {
    private(set) var presentCalled = false
    private(set) var dismissCalled = false
    private(set) var presentedViewControllers: [UIViewController] = []
    private(set) var dismissAnimated = false

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentCalled = true
        presentedViewControllers.append(viewControllerToPresent)
        completion?()
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCalled = true
        dismissAnimated = flag
        completion?()
    }
}

// MARK: - UINavigationController Mock

/// Mock UINavigationController for testing navigation operations
class MockUINavigationController: UINavigationController {
    private(set) var pushedViewControllers: [UIViewController] = []
    private(set) var poppedAnimated = false
    private(set) var setNavigationBarHiddenCalls: [(Bool, Bool)] = []

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushedViewControllers.append(viewController)
        super.pushViewController(viewController, animated: animated)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        poppedAnimated = animated
        return super.popViewController(animated: animated)
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        setNavigationBarHiddenCalls.append((hidden, animated))
        super.setNavigationBarHidden(hidden, animated: animated)
    }
}
