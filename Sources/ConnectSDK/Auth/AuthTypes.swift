//
//  AuthTypes.swift
//  ConnectSDK
//
//  Auth-specific types and callbacks for ConnectSDK
//

import Foundation

// MARK: - Simplified Auth Callbacks

/// Callbacks specific to the Auth app flow
public struct AuthCallbacks: AppCallbacks {
    // Base callbacks (required for all apps)
    public var onClose: (() -> Void)?
    public var onError: ((ErrorEvent) -> Void)?
    public var onEvent: ((GenericEvent) -> Void)?

    // Auth-specific callback
    public var onDeposit: ((DepositEvent) -> Void)?

    public init(
        onClose: (() -> Void)? = nil,
        onError: ((ErrorEvent) -> Void)? = nil,
        onEvent: ((GenericEvent) -> Void)? = nil,
        onDeposit: ((DepositEvent) -> Void)? = nil
    ) {
        self.onClose = onClose
        self.onError = onError
        self.onEvent = onEvent
        self.onDeposit = onDeposit
    }
}

// MARK: - Event Wrappers

/// Generic event wrapper - forwards all data from webview
public struct GenericEvent {
    /// Event type identifier
    public let type: String

    /// Raw JSON data from webview
    public let data: [String: Any]

    /// Raw JSON string
    public let jsonString: String

    /// Timestamp when event was received
    public let timestamp: Date

    // MARK: - Convenience Accessors

    /// Get a string value from the data
    public func getString(_ key: String) -> String? {
        return data[key] as? String
    }

    /// Get an integer value from the data
    public func getInt(_ key: String) -> Int? {
        return data[key] as? Int
    }

    /// Get a boolean value from the data
    public func getBool(_ key: String) -> Bool? {
        return data[key] as? Bool
    }

    /// Get a nested object from the data
    public func getObject(_ key: String) -> [String: Any]? {
        return data[key] as? [String: Any]
    }

    /// Get a double value from the data
    public func getDouble(_ key: String) -> Double? {
        return data[key] as? Double
    }
}

/// Error event wrapper
public struct ErrorEvent {
    /// Error code from webview
    public let code: String

    /// Human-readable error message
    public let message: String

    /// Raw JSON data for additional error details
    public let data: [String: Any]

    /// Raw JSON string for logging/debugging
    public let jsonString: String

    /// Timestamp when error occurred
    public let timestamp: Date
}

/// Deposit event wrapper (auth-specific)
///
/// **Not terminal.** It also fires while account matching is verifying, and can
/// arrive more than once for the same deposit — read the outcome off `status` /
/// `success` rather than treating the call itself as completion.
public struct DepositEvent {
    /// Raw JSON data from webview
    public let data: [String: Any]

    /// Raw JSON string for forwarding
    public let jsonString: String

    /// Timestamp when received
    public let timestamp: Date

    // MARK: - Convenience Accessors for Common Deposit Fields

    /// Deposit identifier
    public var depositId: String? {
        return data["depositId"] as? String
    }

    /// Deposit status.
    ///
    /// `status` arrives as an object (`{ value, details, occurredAt }`), so the
    /// readable status is `status.value`, not the object itself.
    public var status: String? {
        return (data["status"] as? [String: Any])?["value"] as? String
    }

    /// Status values the Auth flow treats as a successful deposit.
    ///
    /// The web SDK's `isSuccessfulDeposit` shows success at `CONFIRMED` — its
    /// `DepositStatusValue.COMPLETED` is the string `'CONFIRMED'` — or at
    /// `PROCESSED` when the platform runs zerohash with auto-convert. That
    /// profile flag never reaches the bridge, so both are accepted here.
    /// Comparing against `processed` alone reported `false` for every successful
    /// deposit on the default path, the same bug `WithdrawalEvent` already
    /// carries a fix for.
    private static let successStatuses: Set<String> = ["confirmed", "processed"]

    /// Account-matching states the web SDK routes away from success before it
    /// ever looks at the status: `PENDING` shows the verifying screen, `INVALID`
    /// and `ERROR` show the failed screen. Absent, `VALID`, or any value we
    /// don't know yet falls through to the status check, exactly as the web hook
    /// does.
    private static let nonSuccessMatchingStatuses: Set<String> = ["pending", "invalid", "error"]

    /// Returns true if the deposit reached a successful terminal state.
    public var success: Bool {
        guard let value = status?.lowercased(), Self.successStatuses.contains(value) else {
            return false
        }
        guard let matching = accountMatchingStatus?.lowercased() else { return true }
        return !Self.nonSuccessMatchingStatuses.contains(matching)
    }

    /// Account-matching validation status, e.g. `PENDING`, `VALID`, `INVALID`, `ERROR`.
    public var accountMatchingStatus: String? {
        return (data["accountMatchingValidation"] as? [String: Any])?["status"] as? String
    }

    /// Why account matching failed. On a name mismatch this is the only
    /// explanation available anywhere in the stack, so prefer it over reporting
    /// a bare id.
    public var accountMatchingReason: String? {
        return (data["accountMatchingValidation"] as? [String: Any])?["reason"] as? String
    }

    /// Asset ticker (btc, eth, usdc, etc.)
    public var assetId: String? {
        return data["assetId"] as? String
    }

    /// Network/chain used (ethereum, solana, bitcoin, etc.)
    public var networkId: String? {
        return data["networkId"] as? String
    }

    /// Amount sent
    public var amount: String? {
        return data["amount"] as? String
    }
}

// MARK: - Internal Callback Handler

/// Internal handler for auth callbacks
internal class AuthCallbackHandler: CallbackHandler {
    private let callbacks: AuthCallbacks

    init(callbacks: AuthCallbacks) {
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
        let deposit = DepositEvent(
            data: depositData,
            jsonString: jsonString,
            timestamp: Date()
        )
        callbacks.onDeposit?(deposit)
    }
}
