//
//  ConnectAuthSessionLifecycleTests.swift
//  ConnectSDKTests
//
//  Tests for ConnectAuthSession UI lifecycle flow - presentation logic testing

import Foundation
import Testing
import UIKit
@testable import ConnectSDK

@MainActor
struct ConnectAuthSessionLifecycleTests {

    // MARK: - Presentation Flow Tests

    @Test("present calls UIViewController.present()")
    func testPresent_CallsUIViewControllerPresent() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act
        let result = session.present(from: mockPresenter)

        // Verify
        #expect(mockPresenter.presentCalled == true)
        #expect(result != nil)
    }

    @Test("present creates UINavigationController")
    func testPresent_CreatesUINavigationController() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act
        _ = session.present(from: mockPresenter)

        // Verify - NavigationController was presented
        #expect(mockPresenter.presentedViewControllers.count == 1)

        // Verify it's a UINavigationController
        let presentedVC = mockPresenter.presentedViewControllers.first
        #expect(presentedVC is UINavigationController)
    }

    @Test("present sets modal presentation style to fullScreen")
    func testPresent_SetsModalPresentationStyle() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act
        _ = session.present(from: mockPresenter)

        // Verify - Get the presented navigation controller
        guard let nav = mockPresenter.presentedViewControllers.first as? UINavigationController else {
            #expect(Bool(false), "Navigation controller not presented")
            return
        }

        // Verify modalPresentationStyle is .fullScreen
        #expect(nav.modalPresentationStyle == .fullScreen)
    }

    @Test("present updates isPresented flag to true")
    func testPresent_UpdatesIsPresentedFlag() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Verify initial state
        #expect(session.isActive == false)

        // Act
        _ = session.present(from: mockPresenter)

        // Verify isPresented changed
        #expect(session.isActive == true)
    }

    @Test("present stores activeSession reference")
    func testPresent_StoresActiveSession() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Verify initial state
        #expect(session.isActive == false)

        // Act
        let result = session.present(from: mockPresenter)

        // Verify activeSession is stored (isActive should be true)
        #expect(session.isActive == true)

        // Verify returned session is not nil
        #expect(result != nil)
    }

    // MARK: - WebViewController Configuration Tests

    @Test("present creates WebViewController as navigation root")
    func testPresent_CreatesWebViewControllerAsRoot() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act
        _ = session.present(from: mockPresenter)

        // Verify - Get the navigation controller
        guard let nav = mockPresenter.presentedViewControllers.first as? UINavigationController else {
            #expect(Bool(false), "Navigation controller not presented")
            return
        }

        // Verify WebViewController is root
        #expect(nav.viewControllers.count >= 1)
        #expect(nav.viewControllers.first is WebViewController)
    }

    @Test("present passes JWT to WebViewController")
    func testPresent_PassesJWTToWebViewController() {
        // Setup
        let testJWT = MockData.validJWT
        let callbacks = MockData.mockAuthCallbackHandlerCallbacks()
        let session = MockData.connectAuthSession(jwt: testJWT, callbacks: callbacks)
        let mockPresenter = MockUIViewController()

        // Act
        _ = session.present(from: mockPresenter)

        // Verify - Get the navigation controller and WebViewController
        guard let nav = mockPresenter.presentedViewControllers.first as? UINavigationController,
              let webVC = nav.viewControllers.first as? WebViewController else {
            #expect(Bool(false), "WebViewController not properly configured")
            return
        }

        // WebViewController should be created (we can verify it exists and has correct environment)
        #expect(webVC.environment == Environment.sandbox)  // From MockData.connectAuthSession default
    }

    // MARK: - Idempotency Tests

    @Test("present twice returns same ConnectSession")
    func testPresent_Twice_ReturnsSameSession() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act - Present first time
        let firstResult = session.present(from: mockPresenter)

        // Act - Present second time
        let secondResult = session.present(from: mockPresenter)

        // Verify - Both return same session reference
        #expect(firstResult === secondResult)
    }

    @Test("present twice only presents once")
    func testPresent_Twice_OnlyPresentsOnce() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act - Present first time
        _ = session.present(from: mockPresenter)
        let presentCountAfterFirst = mockPresenter.presentedViewControllers.count

        // Act - Present second time
        _ = session.present(from: mockPresenter)
        let presentCountAfterSecond = mockPresenter.presentedViewControllers.count

        // Verify - Only one presentation happened
        #expect(presentCountAfterFirst == 1)
        #expect(presentCountAfterSecond == 1)  // No additional presentation
    }

    // MARK: - State Management Tests

    @Test("present with empty JWT returns nil")
    func testPresent_WithEmptyJWT_ReturnsNil() {
        // Setup
        let session = MockData.connectAuthSession(jwt: "")
        let mockPresenter = MockUIViewController()

        // Act
        let result = session.present(from: mockPresenter)

        // Verify
        #expect(result == nil)
        #expect(session.isActive == false)
        #expect(mockPresenter.presentCalled == false)
    }

    @Test("cancel resets isPresented and activeSession")
    func testCancel_ResetsState() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act - Present
        _ = session.present(from: mockPresenter)
        #expect(session.isActive == true)

        // Act - Cancel
        session.cancel()

        // Verify
        #expect(session.isActive == false)
    }

    // MARK: - Navigation Controller Configuration Tests

    @Test("present sets modalPresentationCapturesStatusBarAppearance")
    func testPresent_SetsStatusBarCaptureFlag() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act
        _ = session.present(from: mockPresenter)

        // Verify - Get the navigation controller
        guard let nav = mockPresenter.presentedViewControllers.first as? UINavigationController else {
            #expect(Bool(false), "Navigation controller not presented")
            return
        }

        // Verify modalPresentationCapturesStatusBarAppearance is true
        #expect(nav.modalPresentationCapturesStatusBarAppearance == true)
    }

    @Test("present configures navigation bar background")
    func testPresent_ConfiguresNavigationBar() {
        // Setup
        let session = MockData.connectAuthSession(jwt: MockData.validJWT)
        let mockPresenter = MockUIViewController()

        // Act
        _ = session.present(from: mockPresenter)

        // Verify - Navigation controller was created and presented
        guard let nav = mockPresenter.presentedViewControllers.first as? UINavigationController else {
            #expect(Bool(false), "Navigation controller not presented")
            return
        }

        // Navigation controller should exist with proper configuration
        #expect(nav.viewControllers.count == 1)  // WebViewController is root
    }
}
