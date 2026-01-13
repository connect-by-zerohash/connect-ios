//
//  OAuthHandler.swift
//  ConnectSDK
//
//  Handles OAuth authentication flows using ASWebAuthenticationSession
//  Requires zero configuration from host applications
//

import Foundation
import AuthenticationServices

@available(iOS 12.0, *)
class OAuthHandler: NSObject {

    // MARK: - Constants

    // Custom URL scheme for OAuth callbacks (doesn't need to be registered in Info.plist)
    static let oauthCallbackScheme = "connectsdk-oauth"

    // Expected callback host when using custom scheme
    private static let expectedCallbackHost = "callback"

    // MARK: - Types

    enum OAuthError: LocalizedError {
        case userCancelled
        case invalidURL
        case missingCallback
        case missingParameters
        case sessionFailed(String)
        case invalidCallbackURL(String)
        case unexpectedRedirect(String)

        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "User cancelled the authentication"
            case .invalidURL:
                return "Invalid OAuth URL provided"
            case .missingCallback:
                return "No callback URL received from OAuth provider"
            case .missingParameters:
                return "Missing required parameters in OAuth response"
            case .sessionFailed(let message):
                return "Authentication session failed: \(message)"
            case .invalidCallbackURL(let url):
                return "Invalid callback URL received: \(url). Expected: \(OAuthHandler.oauthCallbackScheme)://\(OAuthHandler.expectedCallbackHost)"
            case .unexpectedRedirect(let url):
                return "OAuth flow redirected to unexpected URL: \(url)"
            }
        }
    }

    typealias OAuthResult = Result<[String: String], Error>
    typealias OAuthCompletion = (OAuthResult) -> Void

    // MARK: - Properties

    private var authSession: ASWebAuthenticationSession?
    private var completion: OAuthCompletion?
    private weak var presentingViewController: UIViewController?

    // MARK: - Public Methods

    /// Initiates OAuth authentication flow using ASWebAuthenticationSession
    /// - Parameters:
    ///   - url: The OAuth authorization URL
    ///   - callbackURLPrefix: The HTTPS callback URL prefix to intercept (e.g., "https://yourdomain.com/oauth")
    ///   - presentingViewController: The view controller to present the authentication session from
    ///   - completion: Called when authentication completes with parameters or error
    func authenticate(
        url: String,
        callbackURLPrefix: String? = nil,
        from presentingViewController: UIViewController,
        completion: @escaping OAuthCompletion
    ) {
        // Use custom scheme for OAuth callbacks
        let callbackScheme = Self.oauthCallbackScheme
        guard let authURL = URL(string: url) else {
            completion(.failure(OAuthError.invalidURL))
            return
        }

        self.completion = completion
        self.presentingViewController = presentingViewController

        // Create authentication session
        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            self?.handleAuthenticationResult(
                callbackURL: callbackURL,
                error: error
            )
        }

        // Configure session for iOS 13+
        if #available(iOS 13.0, *) {
            authSession?.presentationContextProvider = self
            // Allow SSO with Safari cookies
            authSession?.prefersEphemeralWebBrowserSession = false
        }

        // Start the authentication session
        let started = authSession?.start() ?? false
        if !started {
            completion(.failure(OAuthError.sessionFailed("Failed to start authentication session")))
            cleanup()
        }
    }

    /// Cancels any ongoing authentication session
    func cancel() {
        authSession?.cancel()
        completion?(.failure(OAuthError.userCancelled))
        cleanup()
    }

    // MARK: - Private Methods

    private func handleAuthenticationResult(callbackURL: URL?, error: Error?) {
        defer { cleanup() }

        // Handle errors
        if let error = error {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                completion?(.failure(OAuthError.userCancelled))
            } else {
                completion?(.failure(error))
            }
            return
        }

        // Handle successful callback
        guard let callbackURL = callbackURL else {
            completion?(.failure(OAuthError.missingCallback))
            return
        }

        // Validate the callback URL is from our expected domain
        let isValidCallback = validateCallbackURL(callbackURL)

        if !isValidCallback {
            let errorMessage = "Received unexpected callback URL: \(callbackURL.absoluteString). Expected: \(Self.oauthCallbackScheme)://\(Self.expectedCallbackHost)"
            completion?(.failure(OAuthError.invalidCallbackURL(callbackURL.absoluteString)))
            return
        }

        // Parse OAuth parameters from callback URL
        let parameters = parseOAuthParameters(from: callbackURL)

        if parameters.isEmpty {
            completion?(.failure(OAuthError.missingParameters))
        } else {
            completion?(.success(parameters))
        }
    }

    private func validateCallbackURL(_ url: URL) -> Bool {
        // Check if the URL matches our expected custom scheme callback
        let schemeMatches = url.scheme == Self.oauthCallbackScheme
        let hostMatches = url.host == Self.expectedCallbackHost

        // For custom scheme, we only validate scheme and host
        // Path is not significant for custom scheme URLs
        return schemeMatches && hostMatches
    }

    private func parseOAuthParameters(from url: URL) -> [String: String] {
        var parameters: [String: String] = [:]

        // Parse query parameters (Authorization Code flow)
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    parameters[item.name] = value
                }
            }
        }

        // Parse fragment parameters (Implicit flow)
        if let fragment = url.fragment {
            let fragmentPairs = fragment.components(separatedBy: "&")
            for pair in fragmentPairs {
                let components = pair.components(separatedBy: "=")
                if components.count == 2 {
                    let key = components[0]
                    let value = components[1].removingPercentEncoding ?? components[1]
                    parameters[key] = value
                }
            }
        }

        // Include the full callback URL for reference
        parameters["callback_url"] = url.absoluteString

        return parameters
    }

    private func cleanup() {
        authSession = nil
        completion = nil
        presentingViewController = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

@available(iOS 13.0, *)
extension OAuthHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Try to use the presenting view controller's view window
        if let window = presentingViewController?.view.window {
            return window
        }

        // Fallback to finding the key window
        if #available(iOS 15.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                return windowScene.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
            }
        }

        // iOS 13-14 fallback
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
