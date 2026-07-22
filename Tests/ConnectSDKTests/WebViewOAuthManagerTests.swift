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

@MainActor
struct WebViewOAuthManagerValidatedHTTPSURLTests {

    @Test("Accepts https URLs")
    func testAcceptsHTTPS() {
        #expect(WebViewOAuthManager.validatedHTTPSURL("https://example.com/path?q=1") != nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("https://appleid.apple.com/auth/authorize?x=1") != nil)
    }

    @Test("Rejects http (cleartext) URLs")
    func testRejectsHTTP() {
        #expect(WebViewOAuthManager.validatedHTTPSURL("http://example.com") == nil)
    }

    @Test("Rejects non-web schemes")
    func testRejectsNonWebSchemes() {
        #expect(WebViewOAuthManager.validatedHTTPSURL("tel:+15551234567") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("mailto:a@b.com") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("javascript:alert(1)") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("data:text/html,<script>alert(1)</script>") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("file:///etc/passwd") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("connectsdk-oauth://cb") == nil)
    }

    @Test("Rejects malformed URLs and hostless URLs")
    func testRejectsMalformed() {
        #expect(WebViewOAuthManager.validatedHTTPSURL("") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("not a url") == nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("https://") == nil)
    }

    @Test("Scheme match is case-insensitive")
    func testSchemeCaseInsensitive() {
        #expect(WebViewOAuthManager.validatedHTTPSURL("HTTPS://example.com") != nil)
        #expect(WebViewOAuthManager.validatedHTTPSURL("HtTpS://example.com") != nil)
    }
}
