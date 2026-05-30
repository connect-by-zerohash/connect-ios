//
//  ConnectWithdrawalSessionTests.swift
//  ConnectSDKTests
//
//  Tests for ConnectWithdrawalSession lifecycle and presentation

import Foundation
import Testing
@testable import ConnectSDK

@MainActor
struct ConnectWithdrawalSessionTests {

    // MARK: - Initialization Tests

    @Test("ConnectWithdrawalSession initializes correctly") func testWithdrawalSession_Initialization() {
        let session = ConnectWithdrawalSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyWithdrawalCallbacks
        )
        #expect(session.isActive == false)
    }

    // MARK: - JWT Validation Tests

    @Test("present fails with empty JWT") func testWithdrawalSession_Present_WithEmptyJWT() {
        let session = ConnectWithdrawalSession(
            jwt: MockData.emptyJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyWithdrawalCallbacks
        )
        let mockVC = MockUIViewController()
        let result = session.present(from: mockVC)
        #expect(result == nil)
        #expect(!mockVC.presentCalled)
    }

    @Test("present succeeds with valid JWT") func testWithdrawalSession_Present_WithValidJWT() {
        let session = ConnectWithdrawalSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyWithdrawalCallbacks
        )
        let mockVC = MockUIViewController()
        let connectSession = session.present(from: mockVC)
        #expect(connectSession != nil)
        #expect(connectSession?.app == .withdrawal)
        #expect(mockVC.presentCalled)
    }

    @Test("present only allows one active session") func testWithdrawalSession_Present_OnlyOnce() {
        let session = ConnectWithdrawalSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyWithdrawalCallbacks
        )
        let mockVC = MockUIViewController()
        let first = session.present(from: mockVC)
        let second = session.present(from: mockVC)
        #expect(first === second)
        #expect(mockVC.presentedViewControllers.count == 1)
    }

    // MARK: - Cancel Tests

    @Test("cancel deactivates session") func testWithdrawalSession_Cancel() {
        let session = ConnectWithdrawalSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyWithdrawalCallbacks
        )
        let mockVC = MockUIViewController()
        _ = session.present(from: mockVC)
        session.cancel()
        #expect(session.isActive == false)
    }

    @Test("isActive reflects session state") func testWithdrawalSession_IsActive() {
        let session = ConnectWithdrawalSession(
            jwt: MockData.validJWT,
            environment: .sandbox,
            theme: .light,
            callbacks: MockData.emptyWithdrawalCallbacks
        )
        #expect(session.isActive == false)
        let mockVC = MockUIViewController()
        let connectSession = session.present(from: mockVC)
        #expect(connectSession?.isActive == true)
        #expect(session.isActive == true)
    }

    // MARK: - ConnectApp URL Tests

    @Test("withdrawal app uses correct URL identifier") func testWithdrawalApp_URL() {
        #expect(ConnectApp.withdrawal.identifier == "withdraw")
        #expect(ConnectApp.withdrawal.baseURL(for: .production) == "https://sdk.connect.xyz/mobile/#withdraw")
        #expect(ConnectApp.withdrawal.baseURL(for: .sandbox) == "https://sdk.sandbox.connect.xyz/mobile/#withdraw")
    }
}
