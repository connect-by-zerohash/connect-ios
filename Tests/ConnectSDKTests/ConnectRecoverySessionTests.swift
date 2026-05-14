//
//  ConnectRecoverySessionTests.swift
//  ConnectSDKTests
//
//  Tests for ConnectRecoverySession lifecycle and presentation

import Foundation
import Testing
@testable import ConnectSDK

@MainActor
struct ConnectRecoverySessionTests {

    // MARK: - Initialization Tests

    @Test("ConnectRecoverySession initializes correctly") func testRecoverySession_Initialization() {
        let session = ConnectRecoverySession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyRecoveryCallbacks
        )
        #expect(session.isActive == false)
    }

    // MARK: - JWT Validation Tests

    @Test("present fails with empty JWT") func testRecoverySession_Present_WithEmptyJWT() {
        let session = ConnectRecoverySession(
            jwt: MockData.emptyJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyRecoveryCallbacks
        )
        let mockVC = MockUIViewController()
        let result = session.present(from: mockVC)
        #expect(result == nil)
        #expect(!mockVC.presentCalled)
    }

    @Test("present succeeds with valid JWT") func testRecoverySession_Present_WithValidJWT() {
        let session = ConnectRecoverySession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyRecoveryCallbacks
        )
        let mockVC = MockUIViewController()
        let connectSession = session.present(from: mockVC)
        #expect(connectSession != nil)
        #expect(connectSession?.app == .recovery)
        #expect(mockVC.presentCalled)
    }

    @Test("present only allows one active session") func testRecoverySession_Present_OnlyOnce() {
        let session = ConnectRecoverySession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyRecoveryCallbacks
        )
        let mockVC = MockUIViewController()
        let first = session.present(from: mockVC)
        let second = session.present(from: mockVC)
        #expect(first === second)
        #expect(mockVC.presentedViewControllers.count == 1)
    }

    // MARK: - Cancel Tests

    @Test("cancel deactivates session") func testRecoverySession_Cancel() {
        let session = ConnectRecoverySession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyRecoveryCallbacks
        )
        let mockVC = MockUIViewController()
        _ = session.present(from: mockVC)
        session.cancel()
        #expect(session.isActive == false)
    }

    @Test("isActive reflects session state") func testRecoverySession_IsActive() {
        let session = ConnectRecoverySession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyRecoveryCallbacks
        )
        #expect(session.isActive == false)
        let mockVC = MockUIViewController()
        let connectSession = session.present(from: mockVC)
        #expect(connectSession?.isActive == true)
        #expect(session.isActive == true)
    }

    // MARK: - ConnectApp URL Tests

    @Test("recovery app uses correct URL identifier") func testRecoveryApp_URL() {
        #expect(ConnectApp.recovery.identifier == "recovery")
        #expect(ConnectApp.recovery.baseURL == "https://sdk.connect.xyz/mobile/#recovery")
    }
}
