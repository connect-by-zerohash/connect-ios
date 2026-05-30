//
//  OAuthHandlerTests.swift
//  ConnectSDKTests
//
//  Tests for OAuthHandler and the ConnectOAuthCallback validation surface.
//

import Foundation
import Testing
import AuthenticationServices
@testable import ConnectSDK

struct ConnectOAuthCallbackTests {

    @Test("urlPrefix combines scheme, host, and path")
    func testURLPrefix() {
        let callback = ConnectOAuthCallback(host: "example.com", path: "/cb")
        #expect(callback.urlPrefix == "https://example.com/cb")
    }

    @Test("matches accepts exact host match")
    func testMatches_ExactHost() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "https://connect.xyz/oauth?code=abc")!
        #expect(callback.matches(url))
    }

    @Test("matches accepts dot-suffix subdomain")
    func testMatches_DotSuffixSubdomain() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "https://sdk.connect.xyz/oauth?code=abc")!
        #expect(callback.matches(url))
    }

    @Test("matches rejects sibling host that ends in target")
    func testMatches_RejectsSiblingHost() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "https://evilconnect.xyz/oauth?code=abc")!
        #expect(!callback.matches(url))
    }

    @Test("matches rejects host where target is a substring before another label")
    func testMatches_RejectsHostWithTargetAsPrefix() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "https://connect.xyz.attacker.com/oauth?code=abc")!
        #expect(!callback.matches(url))
    }

    @Test("matches rejects wrong path")
    func testMatches_RejectsWrongPath() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "https://connect.xyz/somewhere-else?code=abc")!
        #expect(!callback.matches(url))
    }

    @Test("matches accepts longer path under the prefix")
    func testMatches_AcceptsLongerPath() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "https://connect.xyz/oauth/callback?code=abc")!
        #expect(callback.matches(url))
    }

    @Test("matches rejects non-HTTPS scheme")
    func testMatches_RejectsHTTP() {
        let callback = ConnectOAuthCallback(host: "connect.xyz", path: "/oauth")
        let url = URL(string: "http://connect.xyz/oauth?code=abc")!
        #expect(!callback.matches(url))
    }

    @Test("matches is case-insensitive on host")
    func testMatches_HostCaseInsensitive() {
        let callback = ConnectOAuthCallback(host: "Connect.XYZ", path: "/oauth")
        let url = URL(string: "https://connect.xyz/oauth?code=abc")!
        #expect(callback.matches(url))
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
        #expect(url.scheme == "https")
        #expect(url.host == ConnectOAuthCallback.default.host)
        #expect(url.path == ConnectOAuthCallback.default.path)
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

    @Test("invalid OAuth callback URL is rejected by ConnectOAuthCallback.default")
    func testInvalidOauthCallbackURL() {
        let url = MockData.invalidOauthCallbackURL()
        #expect(!ConnectOAuthCallback.default.matches(url))
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
