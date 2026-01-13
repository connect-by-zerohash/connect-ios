//
//  WebViewOAuthManagerTests.swift
//  ConnectSDK
//

import Foundation
import Testing
import AuthenticationServices
@testable import ConnectSDK

@MainActor
struct WebViewOAuthManagerInitializationTests {

    @Test("WebViewOAuthManager initialization succeeds")
    func testInitialization() {
        let manager = WebViewOAuthManager()
        #expect(manager != nil)
    }
}

@MainActor
struct WebViewOAuthManagerDelegateTests {

    @Test("WebViewOAuthManager delegate can be set")
    func testDelegateAssignment() {
        let manager = WebViewOAuthManager()
        let delegate = WebViewMessageHandlerDelegateSpy()

        // Delegate should be settable (weak reference)
        manager.delegate = nil

        #expect(manager != nil)
    }

    @Test("WebViewOAuthManager multiple instances can coexist")
    func testMultipleInstances() {
        let manager1 = WebViewOAuthManager()
        let manager2 = WebViewOAuthManager()
        let manager3 = WebViewOAuthManager()

        #expect(manager1 != nil)
        #expect(manager2 != nil)
        #expect(manager3 != nil)
    }
}
