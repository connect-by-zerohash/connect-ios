//
//  RecoveryTypes.swift
//  ConnectSDK
//
//  Recovery-specific callback types for ConnectSDK
//

import Foundation

// MARK: - RecoveryCallbacks

/// Callbacks specific to the Recovery app flow
public struct RecoveryCallbacks: AppCallbacks {
    // Base callbacks (required for all apps)
    public var onClose: (() -> Void)?
    public var onError: ((ErrorEvent) -> Void)?
    public var onEvent: ((GenericEvent) -> Void)?

    // Recovery-specific callback — fired when a withdrawal completes during recovery
    public var onWithdrawal: ((WithdrawalEvent) -> Void)?

    public init(
        onClose: (() -> Void)? = nil,
        onError: ((ErrorEvent) -> Void)? = nil,
        onEvent: ((GenericEvent) -> Void)? = nil,
        onWithdrawal: ((WithdrawalEvent) -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onError = onError
        self.onEvent = onEvent
        self.onWithdrawal = onWithdrawal
    }
}

// MARK: - Internal Callback Handler

/// Internal handler for recovery callbacks
internal class RecoveryCallbackHandler: CallbackHandler {
    private let callbacks: RecoveryCallbacks

    init(callbacks: RecoveryCallbacks) {
        self.callbacks = callbacks
    }

    func handleClose() {
        callbacks.onClose?()
    }

    func handleErrorEvent(_ errorData: [String: Any], jsonString: String) {
        let errorEvent = ErrorEvent(
            code: errorData["errorCode"] as? String ?? errorData["code"] as? String ?? "unknown",
            message: errorData["reason"] as? String ?? errorData["message"] as? String ?? "Unknown error",
            data: errorData,
            jsonString: jsonString,
            timestamp: Date()
        )
        callbacks.onError?(errorEvent)
    }

    func handleGenericEvent(_ eventData: [String: Any], jsonString: String) {
        let eventType = eventData["eventType"] as? String ?? "unknown"
        let event = GenericEvent(
            type: eventType,
            data: eventData,
            jsonString: jsonString,
            timestamp: Date()
        )
        callbacks.onEvent?(event)
    }

    func handleDepositEvent(_ depositData: [String: Any], jsonString: String) {
        // Recovery flow does not emit deposit events
    }

    func handleWithdrawalEvent(_ withdrawalData: [String: Any], jsonString: String) {
        let event = WithdrawalEvent(
            data: withdrawalData,
            jsonString: jsonString,
            timestamp: Date()
        )
        callbacks.onWithdrawal?(event)
    }
}
