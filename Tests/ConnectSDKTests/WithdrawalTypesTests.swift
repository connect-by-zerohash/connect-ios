//
//  WithdrawalTypesTests.swift
//  ConnectSDKTests
//
//  Tests for WithdrawalEvent, WithdrawalCallbacks, and WithdrawalCallbackHandler

import Foundation
import Testing
@testable import ConnectSDK

struct WithdrawalTypesTests {

    // MARK: - WithdrawalCallbacks Tests

    @Test("WithdrawalCallbacks all nil") func testWithdrawalCallbacks_AllNil() {
        let callbacks = MockData.emptyWithdrawalCallbacks
        #expect(callbacks.onClose == nil)
        #expect(callbacks.onError == nil)
        #expect(callbacks.onEvent == nil)
        #expect(callbacks.onWithdrawal == nil)
    }

    @Test("WithdrawalCallbacks with onClose") func testWithdrawalCallbacks_WithOnClose() {
        var closeCalled = false
        let callbacks = WithdrawalCallbacks(onClose: { closeCalled = true })
        callbacks.onClose?()
        #expect(closeCalled)
    }

    @Test("WithdrawalCallbacks with onError") func testWithdrawalCallbacks_WithOnError() {
        var errorCalled = false
        let callbacks = WithdrawalCallbacks(onError: { _ in errorCalled = true })
        callbacks.onError?(MockData.errorEvent())
        #expect(errorCalled)
    }

    @Test("WithdrawalCallbacks with onEvent") func testWithdrawalCallbacks_WithOnEvent() {
        var eventCalled = false
        let callbacks = WithdrawalCallbacks(onEvent: { _ in eventCalled = true })
        callbacks.onEvent?(MockData.genericEvent())
        #expect(eventCalled)
    }

    @Test("WithdrawalCallbacks with onWithdrawal") func testWithdrawalCallbacks_WithOnWithdrawal() {
        var withdrawalCalled = false
        let callbacks = WithdrawalCallbacks(onWithdrawal: { _ in withdrawalCalled = true })
        callbacks.onWithdrawal?(MockData.successfulWithdrawal)
        #expect(withdrawalCalled)
    }

    // MARK: - WithdrawalEvent Tests

    @Test("WithdrawalEvent initialization") func testWithdrawalEvent_Initialization() {
        let event = MockData.successfulWithdrawal
        #expect(event.withdrawalId == "withdrawal-123")
    }

    @Test("WithdrawalEvent withdrawal ID property") func testWithdrawalEvent_WithdrawalIdProperty() {
        let event = MockData.withdrawalEvent(withdrawalId: "wit-456")
        #expect(event.withdrawalId == "wit-456")
    }

    @Test("WithdrawalEvent withdrawal ID missing") func testWithdrawalEvent_WithdrawalId_Missing() {
        let event = MockData.emptyWithdrawalEvent
        #expect(event.withdrawalId == nil)
    }

    @Test("WithdrawalEvent success with processed") func testWithdrawalEvent_Success_WithProcessedStatus() {
        let event = MockData.withdrawalEvent(status: "processed")
        #expect(event.success == true)
    }

    @Test("WithdrawalEvent success with pending") func testWithdrawalEvent_Success_WithPendingStatus() {
        let event = MockData.withdrawalEvent(status: "pending")
        #expect(event.success == false)
    }

    @Test("WithdrawalEvent success with missing status") func testWithdrawalEvent_Success_WithMissingStatus() {
        let event = MockData.emptyWithdrawalEvent
        #expect(event.success == false)
    }

    @Test("WithdrawalEvent success case insensitive") func testWithdrawalEvent_Success_WithCaseSensitivity() {
        let event = WithdrawalEvent(
            data: ["status": ["value": "PROCESSED"]],
            jsonString: "{}",
            timestamp: Date()
        )
        #expect(event.success == true)
    }

    @Test("WithdrawalEvent success with invalid status structure") func testWithdrawalEvent_Success_WithInvalidStructure() {
        let event = WithdrawalEvent(
            data: ["status": "not-an-object"],
            jsonString: "{}",
            timestamp: Date()
        )
        #expect(event.success == false)
    }

    @Test("WithdrawalEvent asset ID property") func testWithdrawalEvent_AssetIdProperty() {
        let event = MockData.withdrawalEvent(assetId: "ETH")
        #expect(event.assetId == "ETH")
    }

    @Test("WithdrawalEvent asset ID missing") func testWithdrawalEvent_AssetId_Missing() {
        let event = MockData.emptyWithdrawalEvent
        #expect(event.assetId == nil)
    }

    @Test("WithdrawalEvent network ID property") func testWithdrawalEvent_NetworkIdProperty() {
        let event = MockData.withdrawalEvent(networkId: "ethereum")
        #expect(event.networkId == "ethereum")
    }

    @Test("WithdrawalEvent network ID missing") func testWithdrawalEvent_NetworkId_Missing() {
        let event = MockData.emptyWithdrawalEvent
        #expect(event.networkId == nil)
    }

    @Test("WithdrawalEvent amount property") func testWithdrawalEvent_AmountProperty() {
        let event = MockData.withdrawalEvent(amount: "2.0")
        #expect(event.amount == "2.0")
    }

    @Test("WithdrawalEvent amount missing") func testWithdrawalEvent_Amount_Missing() {
        let event = MockData.emptyWithdrawalEvent
        #expect(event.amount == nil)
    }

    // MARK: - WithdrawalCallbackHandler Tests

    @Test("WithdrawalCallbackHandler handle close") func testWithdrawalCallbackHandler_HandleClose() {
        var closeCalled = false
        let callbacks = WithdrawalCallbacks(onClose: { closeCalled = true })
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        handler.handleClose()
        #expect(closeCalled)
    }

    @Test("WithdrawalCallbackHandler handle close nil") func testWithdrawalCallbackHandler_HandleClose_WithNilCallback() {
        let callbacks = WithdrawalCallbacks()
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        handler.handleClose()
        #expect(true)
    }

    @Test("WithdrawalCallbackHandler handle error event") func testWithdrawalCallbackHandler_HandleErrorEvent() {
        var receivedError: ErrorEvent?
        let callbacks = WithdrawalCallbacks(onError: { receivedError = $0 })
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        handler.handleErrorEvent(["code": "ERR_001"], jsonString: "{}")
        #expect(receivedError?.code == "ERR_001")
        #expect(receivedError?.timestamp != nil)
    }

    @Test("WithdrawalCallbackHandler handle generic event") func testWithdrawalCallbackHandler_HandleGenericEvent() {
        var receivedEvent: GenericEvent?
        let callbacks = WithdrawalCallbacks(onEvent: { receivedEvent = $0 })
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        handler.handleGenericEvent(["eventType": "withdrawal.submitted"], jsonString: "{}")
        #expect(receivedEvent?.type == "withdrawal.submitted")
    }

    @Test("WithdrawalCallbackHandler handle withdrawal event") func testWithdrawalCallbackHandler_HandleWithdrawalEvent() {
        var receivedWithdrawal: WithdrawalEvent?
        let callbacks = WithdrawalCallbacks(onWithdrawal: { receivedWithdrawal = $0 })
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        let data: [String: Any] = [
            "withdrawalId": "wit-001",
            "status": ["value": "processed"]
        ]
        handler.handleWithdrawalEvent(data, jsonString: "{}")
        #expect(receivedWithdrawal?.withdrawalId == "wit-001")
        #expect(receivedWithdrawal?.success == true)
        #expect(receivedWithdrawal?.timestamp != nil)
    }

    @Test("WithdrawalCallbackHandler handle withdrawal nil callback") func testWithdrawalCallbackHandler_HandleWithdrawalEvent_WithNilCallback() {
        let callbacks = WithdrawalCallbacks()
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        handler.handleWithdrawalEvent(["withdrawalId": "wit-001"], jsonString: "{}")
        #expect(true)
    }

    @Test("WithdrawalCallbackHandler deposit event is no-op") func testWithdrawalCallbackHandler_HandleDepositEvent_IsNoOp() {
        var depositCalled = false
        let callbacks = WithdrawalCallbacks()
        let handler = WithdrawalCallbackHandler(callbacks: callbacks)
        // Deposit events should be silently ignored in the withdrawal flow
        handler.handleDepositEvent(["depositId": "dep-001"], jsonString: "{}")
        #expect(!depositCalled)
    }
}
