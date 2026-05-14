//
//  RecoveryTypesTests.swift
//  ConnectSDKTests
//
//  Tests for RecoveryCallbacks and RecoveryCallbackHandler

import Foundation
import Testing
@testable import ConnectSDK

struct RecoveryTypesTests {

    // MARK: - RecoveryCallbacks Tests

    @Test("RecoveryCallbacks all nil") func testRecoveryCallbacks_AllNil() {
        let callbacks = MockData.emptyRecoveryCallbacks
        #expect(callbacks.onClose == nil)
        #expect(callbacks.onError == nil)
        #expect(callbacks.onEvent == nil)
        #expect(callbacks.onWithdrawal == nil)
    }

    @Test("RecoveryCallbacks with onClose") func testRecoveryCallbacks_WithOnClose() {
        var closeCalled = false
        let callbacks = RecoveryCallbacks(onClose: { closeCalled = true })
        callbacks.onClose?()
        #expect(closeCalled)
    }

    @Test("RecoveryCallbacks with onError") func testRecoveryCallbacks_WithOnError() {
        var errorCalled = false
        let callbacks = RecoveryCallbacks(onError: { _ in errorCalled = true })
        callbacks.onError?(MockData.errorEvent())
        #expect(errorCalled)
    }

    @Test("RecoveryCallbacks with onEvent") func testRecoveryCallbacks_WithOnEvent() {
        var eventCalled = false
        let callbacks = RecoveryCallbacks(onEvent: { _ in eventCalled = true })
        callbacks.onEvent?(MockData.genericEvent())
        #expect(eventCalled)
    }

    @Test("RecoveryCallbacks with onWithdrawal") func testRecoveryCallbacks_WithOnWithdrawal() {
        var withdrawalCalled = false
        let callbacks = RecoveryCallbacks(onWithdrawal: { _ in withdrawalCalled = true })
        callbacks.onWithdrawal?(MockData.successfulWithdrawal)
        #expect(withdrawalCalled)
    }

    // MARK: - RecoveryCallbackHandler Tests

    @Test("RecoveryCallbackHandler handle close") func testRecoveryCallbackHandler_HandleClose() {
        var closeCalled = false
        let callbacks = RecoveryCallbacks(onClose: { closeCalled = true })
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        handler.handleClose()
        #expect(closeCalled)
    }

    @Test("RecoveryCallbackHandler handle close nil") func testRecoveryCallbackHandler_HandleClose_WithNilCallback() {
        let callbacks = RecoveryCallbacks()
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        handler.handleClose()
        #expect(true)
    }

    @Test("RecoveryCallbackHandler handle error event") func testRecoveryCallbackHandler_HandleErrorEvent() {
        var receivedError: ErrorEvent?
        let callbacks = RecoveryCallbacks(onError: { receivedError = $0 })
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        handler.handleErrorEvent(["errorCode": "ERR_RECOVERY"], jsonString: "{}")
        #expect(receivedError?.code == "ERR_RECOVERY")
        #expect(receivedError?.timestamp != nil)
    }

    @Test("RecoveryCallbackHandler handle generic event") func testRecoveryCallbackHandler_HandleGenericEvent() {
        var receivedEvent: GenericEvent?
        let callbacks = RecoveryCallbacks(onEvent: { receivedEvent = $0 })
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        handler.handleGenericEvent(["eventType": "withdrawal.submitted"], jsonString: "{}")
        #expect(receivedEvent?.type == "withdrawal.submitted")
    }

    @Test("RecoveryCallbackHandler handle withdrawal event") func testRecoveryCallbackHandler_HandleWithdrawalEvent() {
        var receivedWithdrawal: WithdrawalEvent?
        let callbacks = RecoveryCallbacks(onWithdrawal: { receivedWithdrawal = $0 })
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        let data: [String: Any] = [
            "withdrawalId": "wit-recovery-001",
            "status": ["value": "processed"],
            "assetId": "ETH",
            "networkId": "ethereum",
            "amount": "1.0"
        ]
        handler.handleWithdrawalEvent(data, jsonString: "{}")
        #expect(receivedWithdrawal?.withdrawalId == "wit-recovery-001")
        #expect(receivedWithdrawal?.success == true)
        #expect(receivedWithdrawal?.assetId == "ETH")
        #expect(receivedWithdrawal?.networkId == "ethereum")
        #expect(receivedWithdrawal?.amount == "1.0")
    }

    @Test("RecoveryCallbackHandler handle withdrawal nil callback") func testRecoveryCallbackHandler_HandleWithdrawalEvent_WithNilCallback() {
        let callbacks = RecoveryCallbacks()
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        handler.handleWithdrawalEvent(["withdrawalId": "wit-001"], jsonString: "{}")
        #expect(true)
    }

    @Test("RecoveryCallbackHandler deposit event is no-op") func testRecoveryCallbackHandler_HandleDepositEvent_IsNoOp() {
        let callbacks = RecoveryCallbacks()
        let handler = RecoveryCallbackHandler(callbacks: callbacks)
        handler.handleDepositEvent(["depositId": "dep-001"], jsonString: "{}")
        #expect(true)
    }
}
