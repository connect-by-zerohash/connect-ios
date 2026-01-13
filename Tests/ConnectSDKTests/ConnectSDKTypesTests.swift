//
//  ConnectSDKTypesTests.swift
//  ConnectSDKTests
//
//  Tests for core types: ConnectApp, Theme, Environment, ConnectSession, ConnectError

import Foundation
import Testing
@testable import ConnectSDK

struct ConnectSDKTypesTests {

    // MARK: - ConnectApp Tests

    @Test("ConnectApp auth identifier") func testConnectAppAuthIdentifier() {
        let app = ConnectApp.auth
        #expect(app.identifier == "auth")
    }

    @Test("ConnectApp auth base URL") func testConnectAppAuthBaseURL() {
        let app = ConnectApp.auth
        #expect(app.baseURL == "https://sdk.connect.xyz/mobile/#auth")
    }

    @Test("ConnectApp auth URL contains identifier") func testConnectAppAuthBaseURLContainsIdentifier() {
        let app = ConnectApp.auth
        #expect(app.baseURL.contains(app.identifier))
    }

    // MARK: - Theme Tests

    @Test("Theme light raw value") func testThemeLightRawValue() {
        let theme = Theme.light
        #expect(theme.rawValue == "light")
    }

    @Test("Theme dark raw value") func testThemeDarkRawValue() {
        let theme = Theme.dark
        #expect(theme.rawValue == "dark")
    }

    @Test("Theme system raw value") func testThemeSystemRawValue() {
        let theme = Theme.system
        #expect(theme.rawValue == "system")
    }

    @Test("Theme all cases exists") func testThemeAllCasesExists() {
        #expect(Theme.light != Theme.dark)
        #expect(Theme.dark != Theme.system)
        #expect(Theme.system != Theme.light)
    }

    // MARK: - Environment Tests

    @Test("Environment sandbox raw value") func testEnvironmentSandboxRawValue() {
        let env = Environment.sandbox
        #expect(env.rawValue == "sandbox")
    }

    @Test("Environment production raw value") func testEnvironmentProductionRawValue() {
        let env = Environment.production
        #expect(env.rawValue == "production")
    }

    @Test("Environment all cases exists") func testEnvironmentAllCasesExists() {
        #expect(Environment.sandbox != Environment.production)
    }

    // MARK: - ConnectSession Tests

    @Test("ConnectSession initialization") func testConnectSessionInitialization() {
        let session = MockData.authSession
        #expect(session.app == .auth)
        #expect(session.isActive == true)
    }

    @Test("ConnectSession has unique ID") func testConnectSessionHasUniqueId() {
        let session1 = MockData.authSession
        let session2 = MockData.authSession
        #expect(session1.id != session2.id)
    }

    @Test("ConnectSession created at timestamp") func testConnectSessionCreatedAtTimestamp() {
        let beforeTime = Date()
        let session = MockData.authSession
        let afterTime = Date()
        #expect(session.createdAt >= beforeTime)
        #expect(session.createdAt <= afterTime)
    }

    @Test("ConnectSession close deactivates") func testConnectSessionClose_DeactivatesSession() {
        let session = MockData.authSession
        session.close()
        #expect(session.isActive == false)
    }

    @Test("ConnectSession close idempotent") func testConnectSessionClose_CalledMultipleTimes_OnlyDeactivatesOnce() {
        let session = MockData.authSession
        session.close()
        session.close()
        #expect(session.isActive == false)
    }

    @Test("ConnectSession cancel is close alias") func testConnectSessionCancel_IsAliasForClose() {
        let session = MockData.authSession
        session.cancel()
        #expect(session.isActive == false)
    }

    // MARK: - ConnectError Tests

    @Test("ConnectError network error description") func testConnectErrorNetworkError_ErrorDescription() {
        let error = ConnectError.networkError("Connection failed")
        #expect(error.errorDescription?.contains("Network error") == true)
        #expect(error.errorDescription?.contains("Connection failed") == true)
    }

    @Test("ConnectError auth failed description") func testConnectErrorAuthenticationFailed_ErrorDescription() {
        let error = ConnectError.authenticationFailed("Invalid token")
        #expect(error.errorDescription?.contains("Authentication failed") == true)
    }

    @Test("ConnectError invalid config description") func testConnectErrorInvalidConfiguration_ErrorDescription() {
        let error = ConnectError.invalidConfiguration("Missing API key")
        #expect(error.errorDescription?.contains("Invalid configuration") == true)
    }

    @Test("ConnectError WebView error description") func testConnectErrorWebViewError_ErrorDescription() {
        let error = ConnectError.webViewError("Script error")
        #expect(error.errorDescription?.contains("WebView error") == true)
    }

    @Test("ConnectError session expired description") func testConnectErrorSessionExpired_ErrorDescription() {
        let error = ConnectError.sessionExpired
        #expect(error.errorDescription?.contains("Session has expired") == true)
    }

    @Test("ConnectError user cancelled description") func testConnectErrorUserCancelled_ErrorDescription() {
        let error = ConnectError.userCancelled
        #expect(error.errorDescription?.contains("cancelled") == true)
    }

    @Test("ConnectError unknown error description") func testConnectErrorUnknown_ErrorDescription() {
        let error = ConnectError.unknown("Mystery error")
        #expect(error.errorDescription?.contains("Unknown error") == true)
    }

    // MARK: - ConnectError.from(data:) Tests

    @Test("ConnectError from data network type") func testConnectErrorFromData_NetworkType() {
        let data: [String: Any] = ["type": "network", "message": "No connection"]
        if case .networkError(let message) = ConnectError.from(data: data) {
            #expect(message == "No connection")
        } else {
            Issue.record("Expected .networkError case")
        }
    }

    @Test("ConnectError from data auth type") func testConnectErrorFromData_AuthenticationType() {
        let data: [String: Any] = ["type": "authentication", "message": "Unauthorized"]
        if case .authenticationFailed(let message) = ConnectError.from(data: data) {
            #expect(message == "Unauthorized")
        } else {
            Issue.record("Expected .authenticationFailed case")
        }
    }

    @Test("ConnectError from data config type") func testConnectErrorFromData_ConfigurationType() {
        let data: [String: Any] = ["type": "configuration", "message": "Invalid setup"]
        if case .invalidConfiguration(let message) = ConnectError.from(data: data) {
            #expect(message == "Invalid setup")
        } else {
            Issue.record("Expected .invalidConfiguration case")
        }
    }

    @Test("ConnectError from data WebView type") func testConnectErrorFromData_WebViewType() {
        let data: [String: Any] = ["type": "webview", "message": "Script failed"]
        if case .webViewError(let message) = ConnectError.from(data: data) {
            #expect(message == "Script failed")
        } else {
            Issue.record("Expected .webViewError case")
        }
    }

    @Test("ConnectError from data session expired") func testConnectErrorFromData_SessionExpiredType() {
        let data: [String: Any] = ["type": "session_expired"]
        if case .sessionExpired = ConnectError.from(data: data) {
            // Success
        } else {
            Issue.record("Expected .sessionExpired case")
        }
    }

    @Test("ConnectError from data cancelled") func testConnectErrorFromData_CancelledType() {
        let data: [String: Any] = ["type": "cancelled"]
        if case .userCancelled = ConnectError.from(data: data) {
            // Success
        } else {
            Issue.record("Expected .userCancelled case")
        }
    }

    @Test("ConnectError from data unknown type") func testConnectErrorFromData_UnknownType() {
        let data: [String: Any] = ["type": "unknown", "message": "Something wrong"]
        if case .unknown(let message) = ConnectError.from(data: data) {
            #expect(message == "Something wrong")
        } else {
            Issue.record("Expected .unknown case")
        }
    }

    @Test("ConnectError from data case insensitive") func testConnectErrorFromData_CaseInsensitiveType() {
        let dataUpper: [String: Any] = ["type": "NETWORK", "message": "Error"]
        if case .networkError = ConnectError.from(data: dataUpper) {
            // Success
        } else {
            Issue.record("Expected case-insensitive matching")
        }

        let dataMixed: [String: Any] = ["type": "NeTwOrK", "message": "Error"]
        if case .networkError = ConnectError.from(data: dataMixed) {
            // Success
        } else {
            Issue.record("Expected case-insensitive matching")
        }
    }

    @Test("ConnectError from data default message") func testConnectErrorFromData_DefaultMessage() {
        let data: [String: Any] = ["type": "network"]
        if case .networkError(let message) = ConnectError.from(data: data) {
            #expect(message == "An error occurred")
        } else {
            Issue.record("Expected default message")
        }
    }

    @Test("ConnectError from data empty returns unknown") func testConnectErrorFromData_EmptyData_ReturnsUnknown() {
        let data: [String: Any] = [:]
        if case .unknown(let message) = ConnectError.from(data: data) {
            #expect(message == "An error occurred")
        } else {
            Issue.record("Expected .unknown case with default message")
        }
    }

    @Test("ConnectError from data missing type returns unknown") func testConnectErrorFromData_MissingType_ReturnsUnknown() {
        let data: [String: Any] = ["message": "Error message"]
        if case .unknown(let message) = ConnectError.from(data: data) {
            #expect(message == "Error message")
        } else {
            Issue.record("Expected .unknown case")
        }
    }
}
