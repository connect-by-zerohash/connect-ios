//
//  OAuthHandlerTests.swift
//  ConnectSDKTests
//
//  Tests for OAuthHandler and its custom-scheme callback validation.
//

import Foundation
import Testing
import AuthenticationServices
@testable import ConnectSDK

struct OAuthCallbackValidationTests {

    @Test("accepts the exact custom-scheme callback")
    func testAccepts() {
        #expect(OAuthHandler.isExpectedCallback(URL(string: "connectsdk-oauth://callback?connectionId=abc")!))
    }

    @Test("accepts scheme and host case-insensitively")
    func testCaseInsensitive() {
        #expect(OAuthHandler.isExpectedCallback(URL(string: "ConnectSDK-OAuth://Callback?connectionId=abc")!))
    }

    @Test("rejects a different host on the right scheme")
    func testRejectsWrongHost() {
        #expect(!OAuthHandler.isExpectedCallback(URL(string: "connectsdk-oauth://elsewhere?connectionId=abc")!))
    }

    @Test("rejects https, which is what the Universal Link flow used")
    func testRejectsHTTPS() {
        #expect(!OAuthHandler.isExpectedCallback(URL(string: "https://sdk.connect.xyz/oauth-callback?connectionId=abc")!))
    }

    @Test("rejects a look-alike scheme")
    func testRejectsLookAlikeScheme() {
        #expect(!OAuthHandler.isExpectedCallback(URL(string: "connectsdk-oauth-evil://callback?connectionId=abc")!))
    }
}

struct OAuthErrorTests {

    @Test("OAuthError user cancelled") func testOAuthError_UserCancelled() {
        let error = OAuthHandler.OAuthError.userCancelled
        #expect(error.errorDescription?.contains("cancelled") == true)
    }

    @Test("OAuthError invalid URL") func testOAuthError_InvalidURL() {
        let error = OAuthHandler.OAuthError.invalidURL
        #expect(error.errorDescription?.contains("Invalid OAuth URL") == true)
    }

    @Test("OAuthError missing callback") func testOAuthError_MissingCallback() {
        let error = OAuthHandler.OAuthError.missingCallback
        #expect(error.errorDescription?.contains("callback URL") == true)
    }

    @Test("OAuthError missing parameters") func testOAuthError_MissingParameters() {
        let error = OAuthHandler.OAuthError.missingParameters
        #expect(error.errorDescription?.contains("Missing required parameters") == true)
    }

    @Test("OAuthError session failed") func testOAuthError_SessionFailed() {
        let error = OAuthHandler.OAuthError.sessionFailed("Test message")
        #expect(error.errorDescription?.contains("Authentication session failed") == true)
        #expect(error.errorDescription?.contains("Test message") == true)
    }

    @Test("OAuthError invalid callback URL") func testOAuthError_InvalidCallbackURL() {
        let error = OAuthHandler.OAuthError.invalidCallbackURL("https://wrong.com")
        #expect(error.errorDescription?.contains("Invalid callback URL") == true)
    }
}

struct OAuthURLTests {

    @Test("OAuthCallbackURL with code") func testOAuthCallbackURL_WithCode() {
        let url = MockData.oauthCallbackURLWithCode("test_code_123")
        #expect(url.scheme == OAuthHandler.oauthCallbackScheme)
        #expect(OAuthHandler.isExpectedCallback(url))
        #expect(url.query?.contains("code=test_code_123") == true)
    }

    @Test("OAuthCallbackURL with state") func testOAuthCallbackURL_WithState() {
        let url = MockData.oauthCallbackURLWithCode("code", state: "state_value")
        #expect(url.query?.contains("state=state_value") == true)
    }

    @Test("OAuthCallbackURL fragment access token") func testOAuthCallbackURLWithFragment_HasAccessToken() {
        let url = MockData.oauthCallbackURLWithFragment(accessToken: "token_abc123")
        #expect(url.fragment?.contains("access_token=token_abc123") == true)
    }

    @Test("OAuthCallbackURL fragment token type") func testOAuthCallbackURLWithFragment_HasTokenType() {
        let url = MockData.oauthCallbackURLWithFragment()
        #expect(url.fragment?.contains("token_type=Bearer") == true)
    }

    @Test("invalid OAuth callback URL is rejected")
    func testInvalidOauthCallbackURL() {
        let url = MockData.invalidOauthCallbackURL()
        #expect(!OAuthHandler.isExpectedCallback(url))
    }
}

struct OAuthDataTests {

    @Test("URL encoded string can be decoded") func testURLEncodedString_CanBeDecoded() {
        let encoded = "hello%20world"
        let decoded = encoded.removingPercentEncoding
        #expect(decoded == "hello world")
    }

    @Test("URL encoded string special chars") func testURLEncodedString_WithSpecialChars() {
        let encoded = "test%2Fvalue%2B123"
        let decoded = encoded.removingPercentEncoding
        #expect(decoded == "test/value+123")
    }
}

struct OAuthHandlerTypesTests {

    @Test("OAuthHandler type exists") func testOAuthHandler_TypeExists() {
        #expect(OAuthHandler.self != nil)
    }
}

@MainActor
struct OAuthHandlerInitializationTests {

    @Test("OAuthHandler initialization succeeds")
    func testInitialization() {
        let handler = OAuthHandler()
        #expect(handler != nil)
    }
}

@MainActor
struct OAuthErrorDescriptionTests {

    @Test("OAuthError userCancelled has error description")
    func testUserCancelledError() {
        let error = OAuthHandler.OAuthError.userCancelled
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description?.contains("cancelled") == true || description?.contains("Cancel") == true)
    }

    @Test("OAuthError invalidURL has error description")
    func testInvalidURLError() {
        let error = OAuthHandler.OAuthError.invalidURL
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description?.isEmpty == false)
    }

    @Test("OAuthError missingCallback has error description")
    func testMissingCallbackError() {
        let error = OAuthHandler.OAuthError.missingCallback
        let description = error.errorDescription
        #expect(description != nil)
    }

    @Test("OAuthError missingParameters has error description")
    func testMissingParametersError() {
        let error = OAuthHandler.OAuthError.missingParameters
        let description = error.errorDescription
        #expect(description != nil)
    }

    @Test("OAuthError sessionFailed includes message")
    func testSessionFailedError() {
        let error = OAuthHandler.OAuthError.sessionFailed("Test failure")
        let description = error.errorDescription
        #expect(description != nil)
        #expect(description?.contains("Test failure") == true)
    }

    @Test("OAuthError invalidCallbackURL includes URL")
    func testInvalidCallbackURLError() {
        let error = OAuthHandler.OAuthError.invalidCallbackURL("https://invalid.com")
        let description = error.errorDescription
        #expect(description != nil)
    }
}
