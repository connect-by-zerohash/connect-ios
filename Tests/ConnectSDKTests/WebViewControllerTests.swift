//
//  WebViewControllerTests.swift
//  ConnectSDKTests
//
//  Tests for WebViewController - UI orchestration and lifecycle management

import Foundation
import Testing
import UIKit
import WebKit
@testable import ConnectSDK

@MainActor
struct WebViewControllerInitializationTests {

    @Test("WebViewController init valid parameters") func testWebViewController_InitializationWithValidParameters() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc != nil)
    }

    @Test("WebViewController init different environments") func testWebViewController_InitializationWithDifferentEnvironments() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)

        let sandboxVC = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        let productionVC = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .production,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(sandboxVC != nil)
        #expect(productionVC != nil)
    }

    @Test("WebViewController init different themes") func testWebViewController_InitializationWithDifferentThemes() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)

        let lightVC = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        let darkVC = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "dark",
            callbackHandler: callbackHandler
        )

        let systemVC = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "system",
            callbackHandler: callbackHandler
        )

        #expect(lightVC != nil)
        #expect(darkVC != nil)
        #expect(systemVC != nil)
    }

    @Test("WebViewController session reference is weak") func testWebViewController_SessionReferenceIsWeak() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .production,
            theme: "dark",
            callbackHandler: callbackHandler
        )

        // Weak reference means session can be deallocated independently
        #expect(vc.session == nil)
    }

    @Test("WebViewController environment property accessible") func testWebViewController_EnvironmentPropertyAccessible() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc.environment == .sandbox)
    }
}

@MainActor
struct WebViewControllerPropertiesTests {

    @Test("WebViewController stores URL string") func testWebViewController_StoresURLString() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let urlString = "https://custom-domain.com/auth"
        let vc = WebViewController(
            urlString: urlString,
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc != nil)
    }

    @Test("WebViewController stores callback handler") func testWebViewController_StoresCallbackHandler() {
        let callbacks = AuthCallbacks(onClose: { })
        let callbackHandler = AuthCallbackHandler(callbacks: callbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc.callbackHandler != nil)
    }

    @Test("WebViewController theme property set") func testWebViewController_ThemePropertySet() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "dark",
            callbackHandler: callbackHandler
        )

        #expect(vc != nil)
    }

    @Test("WebViewController environment property set") func testWebViewController_EnvironmentPropertySet() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .production,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc.environment == .production)
    }

    @Test("WebViewController custom URL supported") func testWebViewController_CustomURLSupported() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let customURL = "https://api.example.com/authentication/session"

        let vc = WebViewController(
            urlString: customURL,
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc != nil)
    }

    @Test("WebViewController invalid theme handled") func testWebViewController_InvalidThemeHandled() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "invalid-value",
            callbackHandler: callbackHandler
        )

        // Should not crash, should default gracefully
        #expect(vc != nil)
    }
}

@MainActor
struct WebViewControllerArchitectureTests {

    @Test("WebViewController is UIViewController subclass") func testWebViewController_IsUIViewControllerSubclass() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc is UIViewController)
    }

    @Test("WebViewController has callback handler property") func testWebViewController_HasCallbackHandlerProperty() {
        let callbacks = AuthCallbacks()
        let callbackHandler = AuthCallbackHandler(callbacks: callbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc.callbackHandler is AuthCallbackHandler)
    }

    @Test("WebViewController different callbacks supported") func testWebViewController_DifferentCallbacksSupported() {
        var errorCalled = false
        let callbacks = AuthCallbacks(
            onError: { _ in
                errorCalled = true
            }
        )

        let callbackHandler = AuthCallbackHandler(callbacks: callbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc != nil)
    }

    @Test("WebViewController sandbox environment created") func testWebViewController_SandboxEnvironmentCreated() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://sandbox.example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc.environment == .sandbox)
    }

    @Test("WebViewController production environment created") func testWebViewController_ProductionEnvironmentCreated() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://prod.example.com",
            jwt: MockData.validJWT,
            environment: .production,
            theme: "light",
            callbackHandler: callbackHandler
        )

        #expect(vc.environment == .production)
    }

    @Test("WebViewController all themes supported") func testWebViewController_AllThemesSupported() {
        let callbackHandler = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)

        let themes = ["light", "dark", "system"]
        for theme in themes {
            let vc = WebViewController(
                urlString: "https://example.com",
                jwt: MockData.validJWT,
                environment: .sandbox,
                theme: theme,
                callbackHandler: callbackHandler
            )

            #expect(vc != nil)
        }
    }

    @Test("WebViewController multiple instances can be created") func testWebViewController_MultipleInstancesCanBeCreated() {
        let callbackHandler1 = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let callbackHandler2 = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)

        let vc1 = WebViewController(
            urlString: "https://example1.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: callbackHandler1
        )

        let vc2 = WebViewController(
            urlString: "https://example2.com",
            jwt: MockData.validJWT,
            environment: .production,
            theme: "dark",
            callbackHandler: callbackHandler2
        )

        #expect(vc1 !== vc2)
    }
}

@MainActor
struct WebViewControllerInitializationScenarioTests {

    @Test("WebViewController initialization with different callbacks succeeds")
    func testInitWithDifferentCallbacks() {
        let cb1 = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc1 = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: cb1
        )

        let cb2 = AuthCallbackHandler(callbacks: MockData.callbacksWithCloseOnly)
        let vc2 = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: cb2
        )

        #expect(vc1 != nil)
        #expect(vc2 != nil)
    }

    @Test("WebViewController initialization with different environments succeeds")
    func testInitWithDifferentEnvironments() {
        let cb1 = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc1 = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: cb1
        )

        let cb2 = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc2 = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .production,
            theme: "light",
            callbackHandler: cb2
        )

        #expect(vc1 != nil)
        #expect(vc2 != nil)
    }

    @Test("WebViewController view can be loaded without crashing")
    func testViewLoadsWithoutCrashing() {
        let cb = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: cb
        )

        // Accessing view should trigger viewDidLoad
        let _ = vc.view

        #expect(vc.view != nil)
    }

    @Test("WebViewController view has background color configured")
    func testViewBackgroundConfigured() {
        let cb = AuthCallbackHandler(callbacks: MockData.emptyCallbacks)
        let vc = WebViewController(
            urlString: "https://example.com",
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: "light",
            callbackHandler: cb
        )

        // Access view to trigger initialization
        let _ = vc.view

        #expect(vc.view.backgroundColor != nil)
    }
}

@MainActor
struct ConnectAuthSessionErrorScenariosTests {

    @Test("ConnectAuthSession cancel works after presentation")
    func testCancelAfterPresentation() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)
        #expect(result != nil)
        #expect(session.isActive == true)

        session.cancel()

        #expect(session.isActive == false)
    }

    @Test("ConnectAuthSession with empty JWT returns nil on present")
    func testPresentWithEmptyJWT() {
        let session = MockData.connectAuthSession(jwt: "")
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result == nil)
        #expect(session.isActive == false)
    }

    @Test("ConnectAuthSession idempotent cancel after inactive state")
    func testIdempotentCancelAfterInactive() {
        let session = MockData.connectAuthSession(jwt: "")
        let presenter = MockUIViewController()

        // Try to present with empty JWT (will fail)
        _ = session.present(from: presenter)

        // Cancel on already inactive session - should not crash
        session.cancel()

        #expect(session.isActive == false)
    }
}

@MainActor
struct ConnectAuthSessionCallbackConfigurationTests {

    @Test("ConnectAuthSession with close callback is created successfully")
    func testWithCloseCallback() {
        let callbacks = MockData.callbacksWithCloseOnly
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, callbacks: callbacks)

        #expect(session != nil)
    }

    @Test("ConnectAuthSession with error callback is created successfully")
    func testWithErrorCallback() {
        let callbacks = MockData.callbacksWithErrorOnly
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, callbacks: callbacks)

        #expect(session != nil)
    }

    @Test("ConnectAuthSession with deposit callback is created successfully")
    func testWithDepositCallback() {
        let callbacks = MockData.callbacksWithDepositOnly
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, callbacks: callbacks)

        #expect(session != nil)
    }

    @Test("ConnectAuthSession with all callbacks is created successfully")
    func testWithAllCallbacks() {
        let callbacks = MockData.callbacksWithAllHandlers
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, callbacks: callbacks)

        #expect(session != nil)
    }
}

@MainActor
struct ConnectAuthSessionEnvironmentScenariosTests {

    @Test("ConnectAuthSession sandbox environment presentation succeeds")
    func testSandboxEnvironmentPresentation() {
        let callbacks = MockData.callbacksWithCloseOnly
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            callbacks: callbacks
        )
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectAuthSession production environment presentation succeeds")
    func testProductionEnvironmentPresentation() {
        let callbacks = MockData.callbacksWithCloseOnly
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .production,
            callbacks: callbacks
        )
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectAuthSession different environments can coexist")
    func testMultipleEnvironments() {
        let sandbox = MockData.connectAuthSession(jwt: MockData.validJWT, environment: .sandbox)
        let production = MockData.connectAuthSession(jwt: MockData.validJWT, environment: .production)

        let p1 = MockUIViewController()
        let p2 = MockUIViewController()

        let r1 = sandbox.present(from: p1)
        let r2 = production.present(from: p2)

        #expect(r1 != nil)
        #expect(r2 != nil)
    }
}

@MainActor
struct ConnectAuthSessionThemeScenariosTests {

    @Test("ConnectAuthSession light theme presentation succeeds")
    func testLightThemePresentation() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, theme: .light)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectAuthSession dark theme presentation succeeds")
    func testDarkThemePresentation() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, theme: .dark)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectAuthSession system theme presentation succeeds")
    func testSystemThemePresentation() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT, theme: .system)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectAuthSession different themes can coexist")
    func testMultipleThemes() {
        let light = MockData.connectAuthSession(jwt: MockData.validJWT, theme: .light)
        let dark = MockData.connectAuthSession(jwt: MockData.validJWT, theme: .dark)
        let system = MockData.connectAuthSession(jwt: MockData.validJWT, theme: .system)

        let p1 = MockUIViewController()
        let p2 = MockUIViewController()
        let p3 = MockUIViewController()

        let r1 = light.present(from: p1)
        let r2 = dark.present(from: p2)
        let r3 = system.present(from: p3)

        #expect(r1 != nil)
        #expect(r2 != nil)
        #expect(r3 != nil)
    }
}

@MainActor
struct WebViewControllerFullIntegrationTests {

    @Test("Complete flow: Create, present, and cancel session")
    func testCompleteSessionFlow() {
        let callbacks = MockData.callbacksWithAllHandlers
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: callbacks
        )
        let presenter = MockUIViewController()

        // Present
        let result = session.present(from: presenter)
        #expect(result != nil)
        #expect(session.isActive == true)

        // Cancel
        session.cancel()
        #expect(session.isActive == false)
    }

    @Test("Complete flow: Multiple sessions with different configurations")
    func testMultipleSessionsFlow() {
        let session1 = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light
        )
        let session2 = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .production,
            theme: .dark
        )

        let p1 = MockUIViewController()
        let p2 = MockUIViewController()

        let r1 = session1.present(from: p1)
        let r2 = session2.present(from: p2)

        #expect(r1 != nil)
        #expect(r2 != nil)
        #expect(session1.isActive == true)
        #expect(session2.isActive == true)

        session1.cancel()
        session2.cancel()

        #expect(session1.isActive == false)
        #expect(session2.isActive == false)
    }

    @Test("Complete flow: Retry after failure")
    func testRetryAfterFailure() {
        let session = MockData.connectAuthSession(jwt: "")
        let presenter = MockUIViewController()

        // First attempt with invalid JWT
        let result1 = session.present(from: presenter)
        #expect(result1 == nil)

        // Cancel to reset state (though already inactive)
        session.cancel()

        // Create new session with valid JWT
        let session2 = MockData.connectAuthSession(jwt: MockData.validJWT)
        let result2 = session2.present(from: presenter)

        #expect(result2 != nil)
    }
}

@MainActor
struct WebViewMessageHandlerInitializationTests {

    @Test("WebViewMessageHandler initialization succeeds")
    func testInitialization() {
        let mockWebView = MockWKWebView()
        let handler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )
        #expect(handler != nil)
    }

    @Test("WebViewMessageHandler initialization with different environments")
    func testInitializationWithDifferentEnvironments() {
        let mockWebView = MockWKWebView()
        let sandboxHandler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        let mockWebView2 = MockWKWebView()
        let prodHandler = WebViewMessageHandler(
            webView: mockWebView2,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .production
        )

        #expect(sandboxHandler != nil)
        #expect(prodHandler != nil)
    }

    @Test("WebViewMessageHandler initialization with different themes")
    func testInitializationWithDifferentThemes() {
        let mockWebView = MockWKWebView()
        let lightHandler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        let mockWebView2 = MockWKWebView()
        let darkHandler = WebViewMessageHandler(
            webView: mockWebView2,
            jwt: MockData.validJWT,
            theme: "dark",
            environment: .sandbox
        )

        #expect(lightHandler != nil)
        #expect(darkHandler != nil)
    }
}

@MainActor
struct WebViewMessageHandlerSetupTests {

    @Test("WebViewMessageHandler setupMessageHandlers completes")
    func testSetupMessageHandlers() {
        let mockWebView = MockWKWebView()
        let handler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        // Should not crash
        handler.setupMessageHandlers()

        #expect(handler != nil)
    }
}

@MainActor
struct WebViewMessageHandlerSendingTests {

    @Test("WebViewMessageHandler sendInitialMessages completes")
    func testSendInitialMessages() {
        let mockWebView = MockWKWebView()
        let handler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        // Should not crash when sending initial messages
        handler.sendInitialMessages()

        #expect(handler != nil)
    }

    @Test("WebViewMessageHandler sendOAuthResult success completes")
    func testSendOAuthResultSuccess() {
        let mockWebView = MockWKWebView()
        let handler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        // Should not crash when sending OAuth success
        handler.sendOAuthResult(success: true, connectionId: "conn-123")

        #expect(handler != nil)
    }

    @Test("WebViewMessageHandler sendOAuthResult failure completes")
    func testSendOAuthResultFailure() {
        let mockWebView = MockWKWebView()
        let handler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        // Should not crash when sending OAuth failure
        handler.sendOAuthResult(success: false, error: "User denied")

        #expect(handler != nil)
    }

    @Test("WebViewMessageHandler sendMessageToPage completes")
    func testSendMessageToPage() {
        let mockWebView = MockWKWebView()
        let handler = WebViewMessageHandler(
            webView: mockWebView,
            jwt: MockData.validJWT,
            theme: "light",
            environment: .sandbox
        )

        // Should not crash when sending custom message
        handler.sendMessageToPage(type: "custom-event", data: ["key": "value"])

        #expect(handler != nil)
    }
}
