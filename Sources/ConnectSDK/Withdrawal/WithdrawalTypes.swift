//
//  WithdrawalTypes.swift
//  ConnectSDK
//
//  Shared withdrawal event type and callback types for Recovery and Withdrawal flows
//

import Foundation

// MARK: - WithdrawalEvent

/// Withdrawal event wrapper — used by both Recovery and Withdrawal flows
public struct WithdrawalEvent {
    /// Raw JSON data from webview
    public let data: [String: Any]

    /// Raw JSON string for forwarding
    public let jsonString: String

    /// Timestamp when received
    public let timestamp: Date

    // MARK: - Convenience Accessors

    /// Withdrawal identifier
    public var withdrawalId: String? {
        return data["withdrawalId"] as? String
    }

    /// Withdrawal status string
    public var status: String? {
        return data["status"] as? String
    }

    /// Returns true if the withdrawal was successfully processed
    public var success: Bool {
        guard let status = data["status"] as? [String: Any],
              let value = status["value"] as? String else {
            return false
        }
        return value.lowercased() == "processed"
    }

    /// Asset ticker (btc, eth, usdc, etc.)
    public var assetId: String? {
        return data["assetId"] as? String
    }

    /// Network/chain used (ethereum, bitcoin, solana, etc.)
    public var networkId: String? {
        return data["networkId"] as? String
    }

    /// Amount withdrawn
    public var amount: String? {
        return data["amount"] as? String
    }
}

// MARK: - WithdrawalCallbacks

/// Callbacks specific to the Withdrawal app flow
public struct WithdrawalCallbacks: AppCallbacks {
    // Base callbacks (required for all apps)
    public var onClose: (() -> Void)?
    public var onError: ((ErrorEvent) -> Void)?
    public var onEvent: ((GenericEvent) -> Void)?

    // Withdrawal-specific callback
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

/// Internal handler for withdrawal callbacks
internal class WithdrawalCallbackHandler: CallbackHandler {
    private let callbacks: WithdrawalCallbacks

    init(callbacks: WithdrawalCallbacks) {
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
        // Withdrawal flow does not emit deposit events
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
