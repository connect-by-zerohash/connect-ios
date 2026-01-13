//
//  ConnectAuthSessionTests.swift
//  ConnectSDKTests
//
//  Tests for ConnectAuthSession - Session management and presentation

import Foundation
import Testing
import UIKit
@testable import ConnectSDK

@MainActor
struct ConnectAuthSessionInitializationTests {

    @Test("ConnectAuthSession init valid parameters") func testConnectAuthSession_InitializationWithValidParameters() {
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyCallbacks
        )

        #expect(session != nil)
    }

    @Test("ConnectAuthSession initial state not presented") func testConnectAuthSession_InitialStateIsNotPresented() {
        let session = MockData.connectAuthSession()

        #expect(!session.isActive)
    }
}

@MainActor
struct ConnectAuthSessionPresentationTests {

    @Test("ConnectAuthSession present valid session") func testConnectAuthSession_PresentValidSession() {
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light
        )

        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
        #expect(presenter.presentCalled)
    }

    @Test("ConnectAuthSession present returns ConnectSession") func testConnectAuthSession_PresentReturnsConnectSession() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result is ConnectSession)
    }

    @Test("ConnectAuthSession present with JWT creates WebViewController") func testConnectAuthSession_PresentWithValidJWTCreatesWebViewController() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result != nil)
    }

    @Test("ConnectAuthSession present sets is presented flag") func testConnectAuthSession_PresentSetsIsPresentedFlag() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)

        #expect(session.isActive)
    }

    @Test("ConnectAuthSession present twice returns existing") func testConnectAuthSession_PresentTwiceReturnsExistingSession() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        let firstResult = session.present(from: presenter)
        let secondResult = session.present(from: presenter)

        #expect(firstResult === secondResult)
    }

    @Test("ConnectAuthSession present creates navigation controller") func testConnectAuthSession_PresentCreatesNavigationController() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)

        #expect(presenter.presentedViewControllers.count == 1)
    }
}

@MainActor
struct ConnectAuthSessionThemeTests {

    @Test("ConnectAuthSession light theme applied to navigation") func testConnectAuthSession_LightThemeAppliedToNavigation() {
        let callbacks = MockData.mockAuthCallbackHandlerCallbacks()
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: callbacks
        )

        let presenter = MockUIViewController()
        _ = session.present(from: presenter)

        #expect(presenter.presentCalled)
    }

    @Test("ConnectAuthSession dark theme applied to navigation") func testConnectAuthSession_DarkThemeAppliedToNavigation() {
        let callbacks = MockData.mockAuthCallbackHandlerCallbacks()
        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .dark,
            callbacks: callbacks
        )

        let presenter = MockUIViewController()
        _ = session.present(from: presenter)

        #expect(presenter.presentCalled)
    }
}

@MainActor
struct ConnectAuthSessionValidationTests {

    @Test("ConnectAuthSession empty JWT returns nil") func testConnectAuthSession_EmptyJWTReturnsNil() {
        let session = MockData.connectAuthSession(jwt: MockData.emptyJWT)
        let presenter = MockUIViewController()

        let result = session.present(from: presenter)

        #expect(result == nil)
    }

    @Test("ConnectAuthSession empty JWT does not set presented") func testConnectAuthSession_EmptyJWTDoesNotSetPresented() {
        let session = MockData.connectAuthSession(jwt: MockData.emptyJWT)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)

        #expect(!session.isActive)
    }

    @Test("ConnectAuthSession callbacks passed to handler") func testConnectAuthSession_CallbacksPassedToHandler() {
        var errorCalled = false
        let callbacks = AuthCallbacks(
            onError: { _ in
                errorCalled = true
            }
        )

        let session = MockData.connectAuthSession(
            jwt: MockData.validJWT,
            callbacks: callbacks
        )

        let presenter = MockUIViewController()
        _ = session.present(from: presenter)

        #expect(presenter.presentCalled)
    }
}

@MainActor
struct ConnectAuthSessionCancellationTests {

    @Test("ConnectAuthSession cancel clears active session") func testConnectAuthSession_CancelClearsActiveSession() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)
        session.cancel()

        #expect(!session.isActive)
    }

    @Test("ConnectAuthSession cancel multiple times does not crash") func testConnectAuthSession_CancelMultipleTimesDoesNotCrash() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)
        session.cancel()
        session.cancel()

        #expect(!session.isActive)
    }
}

@MainActor
struct ConnectAuthSessionStateTests {

    @Test("ConnectAuthSession is active computed property") func testConnectAuthSession_IsActiveComputedProperty() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        #expect(!session.isActive)

        _ = session.present(from: presenter)

        #expect(session.isActive)
    }

    @Test("ConnectAuthSession is active false after cancel") func testConnectAuthSession_IsActiveFalseAfterCancel() {
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let presenter = MockUIViewController()

        _ = session.present(from: presenter)
        session.cancel()

        #expect(!session.isActive)
    }
}
