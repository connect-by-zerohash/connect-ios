//
//  ConnectSDKTypes.swift
//  ConnectSDK
//
//  Base types and protocols for ConnectSDK
//

import Foundation
import UIKit

// MARK: - App Types

/// Available Connect apps that can be launched
public enum ConnectApp {
    case auth
    case recovery
    case withdrawal

    /// The identifier used in the URL
    var identifier: String {
        switch self {
        case .auth: return "auth"
        case .recovery: return "recovery"
        case .withdrawal: return "withdraw"
        }
    }

    /// Base URL for the web app, resolved against the given environment.
    /// For `.localDev`, returns the local dev-server URL directly so the SDK
    /// shell can point at a LAN dev server. For `.sandbox`/`.production`,
    /// returns the hosted URL (`environment.webHost`) with the app identifier
    /// as a fragment.
    func baseURL(for environment: Environment) -> String {
        switch environment {
        case .localDev(let url):
            return url.absoluteString
        case .sandbox, .production:
            return "https://\(environment.webHost)/mobile/#\(identifier)"
        }
    }
}

// MARK: - Theme

/// Available themes for the Connect UI
public enum Theme: String {
    case light
    case dark
    case system
}

// MARK: - Environment

/// Environment options for the SDK
public enum Environment: Equatable {
    case sandbox
    case production
    case localDev(URL)

    public var rawValue: String {
        switch self {
        case .sandbox:    return "sandbox"
        case .production: return "production"
        case .localDev:   return "localDev"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "sandbox":    self = .sandbox
        case "production": self = .production
        default:           return nil
        }
    }

    /// Host of the embedded Connect web app for this environment. Single
    /// source of truth shared by `ConnectApp.baseURL(for:)` and the
    /// WebView's trusted-origin check. For `.localDev`, this is the host of
    /// the configured local dev-server URL.
    internal var webHost: String {
        switch self {
        case .sandbox:           return "sdk.sandbox.connect.xyz"
        case .production:        return "sdk.connect.xyz"
        case .localDev(let url): return url.host ?? ""
        }
    }
}

// MARK: - Session

/// Represents an active Connect session
public class ConnectSession {
    /// Unique identifier for this session
    public let id: String = UUID().uuidString

    /// The app type for this session
    public let app: ConnectApp

    /// Whether the session is currently active
    public internal(set) var isActive: Bool = true

    /// Reference to the presented view controller
    internal weak var viewController: UIViewController?

    /// Creation timestamp
    public let createdAt: Date = Date()

    internal init(app: ConnectApp, viewController: UIViewController) {
        self.app = app
        self.viewController = viewController
    }

    /// Initializer for testing - creates session without view controller
    internal init(app: ConnectApp) {
        self.app = app
        self.viewController = nil
    }

    /// Closes the Connect session
    public func close() {
        guard isActive else { return }
        isActive = false
        viewController?.dismiss(animated: true)
    }

    /// Cancels any ongoing operations and closes the session
    public func cancel() {
        close()
    }
}

// MARK: - Error Types

/// Errors that can occur in the Connect SDK
public enum ConnectError: LocalizedError {
    case networkError(String)
    case authenticationFailed(String)
    case invalidConfiguration(String)
    case webViewError(String)
    case sessionExpired
    case userCancelled
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .webViewError(let message):
            return "WebView error: \(message)"
        case .sessionExpired:
            return "Session has expired"
        case .userCancelled:
            return "User cancelled the operation"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }

    /// Creates an error from webview message data
    internal static func from(data: [String: Any]) -> ConnectError {
        let type = (data["type"] as? String ?? "").lowercased()
        let message = data["message"] as? String ?? "An error occurred"

        switch type {
        case "network":
            return .networkError(message)
        case "authentication":
            return .authenticationFailed(message)
        case "configuration":
            return .invalidConfiguration(message)
        case "webview":
            return .webViewError(message)
        case "session_expired":
            return .sessionExpired
        case "cancelled":
            return .userCancelled
        default:
            return .unknown(message)
        }
    }
}

// MARK: - Base Protocols

/// Base protocol for app-specific callbacks
public protocol AppCallbacks {
    /// Called when the Connect session is closed
    var onClose: (() -> Void)? { get }

    /// Called when an error occurs (using new ErrorEvent type)
    var onError: ((ErrorEvent) -> Void)? { get }

    /// Called when a generic event occurs
    var onEvent: ((GenericEvent) -> Void)? { get }
}

// MARK: - Internal Types

/// Internal wrapper for passing callbacks to WebViewController
internal protocol CallbackHandler {
    func handleClose()
    func handleErrorEvent(_ errorData: [String: Any], jsonString: String)
    func handleGenericEvent(_ eventData: [String: Any], jsonString: String)
    func handleDepositEvent(_ depositData: [String: Any], jsonString: String)
    func handleWithdrawalEvent(_ withdrawalData: [String: Any], jsonString: String)
}

internal extension CallbackHandler {
    func handleWithdrawalEvent(_ withdrawalData: [String: Any], jsonString: String) {}
}
