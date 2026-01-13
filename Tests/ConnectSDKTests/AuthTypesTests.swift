//
//  AuthTypesTests.swift
//  ConnectSDKTests
//
//  Tests for auth types: AuthCallbacks, GenericEvent, ErrorEvent, DepositEvent, AuthCallbackHandler

import Foundation
import Testing
@testable import ConnectSDK

struct AuthTypesTests {

    // MARK: - AuthCallbacks Tests

    @Test("AuthCallbacks all nil") func testAuthCallbacks_AllNil() {
        let callbacks = MockData.emptyCallbacks
        #expect(callbacks.onClose == nil)
        #expect(callbacks.onError == nil)
        #expect(callbacks.onEvent == nil)
        #expect(callbacks.onDeposit == nil)
    }

    @Test("AuthCallbacks with onClose") func testAuthCallbacks_WithOnClose() {
        var closeCalled = false
        let callbacks = AuthCallbacks(
            onClose: { closeCalled = true }
        )
        callbacks.onClose?()
        #expect(closeCalled)
    }

    @Test("AuthCallbacks with onError") func testAuthCallbacks_WithOnError() {
        var errorCalled = false
        let callbacks = AuthCallbacks(
            onError: { _ in errorCalled = true }
        )
        let error = MockData.errorEvent()
        callbacks.onError?(error)
        #expect(errorCalled)
    }

    @Test("AuthCallbacks with onEvent") func testAuthCallbacks_WithOnEvent() {
        var eventCalled = false
        let callbacks = AuthCallbacks(
            onEvent: { _ in eventCalled = true }
        )
        let event = MockData.genericEvent()
        callbacks.onEvent?(event)
        #expect(eventCalled)
    }

    @Test("AuthCallbacks with onDeposit") func testAuthCallbacks_WithOnDeposit() {
        var depositCalled = false
        let callbacks = AuthCallbacks(
            onDeposit: { _ in depositCalled = true }
        )
        let deposit = MockData.successfulDeposit
        callbacks.onDeposit?(deposit)
        #expect(depositCalled)
    }

    // MARK: - GenericEvent Tests

    @Test("GenericEvent initialization") func testGenericEvent_Initialization() {
        let event = MockData.genericEvent(
            type: "custom",
            data: ["key": "value"]
        )
        #expect(event.type == "custom")
        #expect(event.data["key"] as? String == "value")
    }

    @Test("GenericEvent get string valid key") func testGenericEvent_GetString_WithValidKey() {
        let event = MockData.genericEvent(
            data: ["username": "john"]
        )
        #expect(event.getString("username") == "john")
    }

    @Test("GenericEvent get string missing key") func testGenericEvent_GetString_WithMissingKey() {
        let event = MockData.emptyGenericEvent
        #expect(event.getString("missing") == nil)
    }

    @Test("GenericEvent get string wrong type") func testGenericEvent_GetString_WithWrongType() {
        let event = MockData.genericEvent(
            data: ["count": 42]
        )
        #expect(event.getString("count") == nil)
    }

    @Test("GenericEvent get int valid key") func testGenericEvent_GetInt_WithValidKey() {
        let event = MockData.genericEvent(
            data: ["count": 42]
        )
        #expect(event.getInt("count") == 42)
    }

    @Test("GenericEvent get int missing key") func testGenericEvent_GetInt_WithMissingKey() {
        let event = MockData.emptyGenericEvent
        #expect(event.getInt("missing") == nil)
    }

    @Test("GenericEvent get int wrong type") func testGenericEvent_GetInt_WithWrongType() {
        let event = MockData.genericEvent(
            data: ["name": "john"]
        )
        #expect(event.getInt("name") == nil)
    }

    @Test("GenericEvent get bool valid key") func testGenericEvent_GetBool_WithValidKey() {
        let event = MockData.genericEvent(
            data: ["isActive": true]
        )
        #expect(event.getBool("isActive") == true)
    }

    @Test("GenericEvent get bool missing key") func testGenericEvent_GetBool_WithMissingKey() {
        let event = MockData.emptyGenericEvent
        #expect(event.getBool("missing") == nil)
    }

    @Test("GenericEvent get bool wrong type") func testGenericEvent_GetBool_WithWrongType() {
        let event = MockData.genericEvent(
            data: ["flag": "yes"]
        )
        #expect(event.getBool("flag") == nil)
    }

    @Test("GenericEvent get object valid key") func testGenericEvent_GetObject_WithValidKey() {
        let nested: [String: Any] = ["inner": "value"]
        let event = MockData.genericEvent(
            data: ["obj": nested]
        )
        #expect(event.getObject("obj")?["inner"] as? String == "value")
    }

    @Test("GenericEvent get object missing key") func testGenericEvent_GetObject_WithMissingKey() {
        let event = MockData.emptyGenericEvent
        #expect(event.getObject("missing") == nil)
    }

    @Test("GenericEvent get object wrong type") func testGenericEvent_GetObject_WithWrongType() {
        let event = MockData.genericEvent(
            data: ["text": "string"]
        )
        #expect(event.getObject("text") == nil)
    }

    @Test("GenericEvent get double valid key") func testGenericEvent_GetDouble_WithValidKey() {
        let event = MockData.genericEvent(
            data: ["amount": 3.14]
        )
        #expect(event.getDouble("amount") == 3.14)
    }

    @Test("GenericEvent get double missing key") func testGenericEvent_GetDouble_WithMissingKey() {
        let event = MockData.emptyGenericEvent
        #expect(event.getDouble("missing") == nil)
    }

    @Test("GenericEvent get double wrong type") func testGenericEvent_GetDouble_WithWrongType() {
        let event = MockData.genericEvent(
            data: ["text": "3.14"]
        )
        #expect(event.getDouble("text") == nil)
    }

    // MARK: - ErrorEvent Tests

    @Test("ErrorEvent initialization") func testErrorEvent_Initialization() {
        let error = MockData.errorEvent(
            code: "ERR_001",
            message: "Test error"
        )
        #expect(error.code == "ERR_001")
        #expect(error.message == "Test error")
    }

    @Test("ErrorEvent with raw data") func testErrorEvent_WithRawData() {
        let rawData: [String: Any] = ["details": "context info"]
        let error = MockData.errorEvent(
            data: rawData
        )
        #expect(error.data["details"] as? String == "context info")
    }

    @Test("ErrorEvent timestamp preservation") func testErrorEvent_TimestampPreservation() {
        let now = Date()
        let error = MockData.errorEvent(timestamp: now)
        #expect(error.timestamp == now)
    }

    // MARK: - DepositEvent Tests

    @Test("DepositEvent initialization") func testDepositEvent_Initialization() {
        let deposit = MockData.successfulDeposit
        #expect(deposit.depositId == "deposit-123")
    }

    @Test("DepositEvent deposit ID property") func testDepositEvent_DepositIdProperty() {
        let deposit = MockData.depositEvent(depositId: "dep-456")
        #expect(deposit.depositId == "dep-456")
    }

    @Test("DepositEvent deposit ID missing") func testDepositEvent_DepositId_Missing() {
        let deposit = MockData.emptyDepositEvent
        #expect(deposit.depositId == nil)
    }

    @Test("DepositEvent status property") func testDepositEvent_StatusProperty() {
        let deposit = DepositEvent(
            data: ["status": "processed"],
            jsonString: "{}",
            timestamp: Date()
        )
        #expect(deposit.status == "processed")
    }

    @Test("DepositEvent status missing") func testDepositEvent_Status_Missing() {
        let deposit = MockData.emptyDepositEvent
        #expect(deposit.status == nil)
    }

    @Test("DepositEvent success with processed") func testDepositEvent_Success_WithProcessedStatus() {
        let deposit = MockData.depositEvent(status: "processed")
        #expect(deposit.success == true)
    }

    @Test("DepositEvent success with pending") func testDepositEvent_Success_WithPendingStatus() {
        let deposit = MockData.depositEvent(status: "pending")
        #expect(deposit.success == false)
    }

    @Test("DepositEvent success with missing status") func testDepositEvent_Success_WithMissingStatus() {
        let deposit = MockData.emptyDepositEvent
        #expect(deposit.success == false)
    }

    @Test("DepositEvent success with invalid structure") func testDepositEvent_Success_WithInvalidStatusStructure() {
        let deposit = DepositEvent(
            data: ["status": "not-an-object"],
            jsonString: "{}",
            timestamp: Date()
        )
        #expect(deposit.success == false)
    }

    @Test("DepositEvent success case sensitive") func testDepositEvent_Success_WithCaseSensitivity() {
        let deposit = DepositEvent(
            data: ["status": ["value": "PROCESSED"]],
            jsonString: "{}",
            timestamp: Date()
        )
        #expect(deposit.success == true)
    }

    @Test("DepositEvent asset ID property") func testDepositEvent_AssetIdProperty() {
        let deposit = MockData.depositEvent(assetId: "ETH")
        #expect(deposit.assetId == "ETH")
    }

    @Test("DepositEvent asset ID missing") func testDepositEvent_AssetId_Missing() {
        let deposit = MockData.emptyDepositEvent
        #expect(deposit.assetId == nil)
    }

    @Test("DepositEvent network ID property") func testDepositEvent_NetworkIdProperty() {
        let deposit = MockData.depositEvent(networkId: "ethereum")
        #expect(deposit.networkId == "ethereum")
    }

    @Test("DepositEvent network ID missing") func testDepositEvent_NetworkId_Missing() {
        let deposit = MockData.emptyDepositEvent
        #expect(deposit.networkId == nil)
    }

    @Test("DepositEvent amount property") func testDepositEvent_AmountProperty() {
        let deposit = MockData.depositEvent(amount: "1.5")
        #expect(deposit.amount == "1.5")
    }

    @Test("DepositEvent amount missing") func testDepositEvent_Amount_Missing() {
        let deposit = MockData.emptyDepositEvent
        #expect(deposit.amount == nil)
    }

    // MARK: - AuthCallbackHandler Tests

    @Test("AuthCallbackHandler handle close") func testAuthCallbackHandler_HandleClose() {
        var closeCalled = false
        let callbacks = AuthCallbacks(
            onClose: { closeCalled = true }
        )
        let handler = AuthCallbackHandler(callbacks: callbacks)
        handler.handleClose()
        #expect(closeCalled)
    }

    @Test("AuthCallbackHandler handle close nil") func testAuthCallbackHandler_HandleClose_WithNilCallback() {
        let callbacks = AuthCallbacks()
        let handler = AuthCallbackHandler(callbacks: callbacks)
        handler.handleClose() // Should not crash
        #expect(true)
    }

    @Test("AuthCallbackHandler handle error event") func testAuthCallbackHandler_HandleErrorEvent_CreatesEventAndCallsCallback() {
        var receivedError: ErrorEvent?
        let callbacks = AuthCallbacks(
            onError: { error in
                receivedError = error
            }
        )
        let handler = AuthCallbackHandler(callbacks: callbacks)
        let errorData: [String: Any] = ["code": "ERR_001"]
        handler.handleErrorEvent(errorData, jsonString: "{}")

        #expect(receivedError?.code == "ERR_001")
        #expect(receivedError?.timestamp != nil)
    }

    @Test("AuthCallbackHandler handle error nil") func testAuthCallbackHandler_HandleErrorEvent_WithNilCallback() {
        let callbacks = AuthCallbacks()
        let handler = AuthCallbackHandler(callbacks: callbacks)
        let errorData: [String: Any] = ["code": "ERR_001"]
        handler.handleErrorEvent(errorData, jsonString: "{}") // Should not crash
        #expect(true)
    }

    @Test("AuthCallbackHandler handle generic event") func testAuthCallbackHandler_HandleGenericEvent_CreatesEventAndCallsCallback() {
        var receivedEvent: GenericEvent?
        let callbacks = AuthCallbacks(
            onEvent: { event in
                receivedEvent = event
            }
        )
        let handler = AuthCallbackHandler(callbacks: callbacks)
        let eventData: [String: Any] = ["eventType": "ready"]
        handler.handleGenericEvent(eventData, jsonString: "{}")

        #expect(receivedEvent?.type == "ready")
        #expect(receivedEvent?.timestamp != nil)
    }

    @Test("AuthCallbackHandler handle generic nil") func testAuthCallbackHandler_HandleGenericEvent_WithNilCallback() {
        let callbacks = AuthCallbacks()
        let handler = AuthCallbackHandler(callbacks: callbacks)
        let eventData: [String: Any] = ["eventType": "ready"]
        handler.handleGenericEvent(eventData, jsonString: "{}") // Should not crash
        #expect(true)
    }

    @Test("AuthCallbackHandler handle deposit event") func testAuthCallbackHandler_HandleDepositEvent_CreatesEventAndCallsCallback() {
        var receivedDeposit: DepositEvent?
        let callbacks = AuthCallbacks(
            onDeposit: { deposit in
                receivedDeposit = deposit
            }
        )
        let handler = AuthCallbackHandler(callbacks: callbacks)
        let depositData: [String: Any] = [
            "depositId": "dep-001",
            "status": ["value": "processed"]
        ]
        handler.handleDepositEvent(depositData, jsonString: "{}")

        #expect(receivedDeposit?.depositId == "dep-001")
        #expect(receivedDeposit?.success == true)
        #expect(receivedDeposit?.timestamp != nil)
    }

    @Test("AuthCallbackHandler handle deposit nil") func testAuthCallbackHandler_HandleDepositEvent_WithNilCallback() {
        let callbacks = AuthCallbacks()
        let handler = AuthCallbackHandler(callbacks: callbacks)
        let depositData: [String: Any] = ["depositId": "dep-001"]
        handler.handleDepositEvent(depositData, jsonString: "{}") // Should not crash
        #expect(true)
    }
}
