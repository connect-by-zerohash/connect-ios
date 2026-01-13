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

    /// The identifier used in the URL
    var identifier: String {
        switch self {
        case .auth: return "auth"
        }
    }

    /// Base URL for the web app
    var baseURL: String {
        return "https://sdk.connect.xyz/mobile/#\(identifier)"
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
public enum Environment: String {
    case sandbox = "sandbox"
    case production = "production"
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
}
