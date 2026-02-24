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
    // NOTE: Custom URL schemes can be hijacked by malicious apps. For production use,
    // consider using Universal Links (https://) which are more secure and cannot be intercepted.
    // Universal Links require Associated Domains configuration in your app.
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
    ///   - callbackURLPrefix: Optional HTTPS callback URL prefix for Universal Links (e.g., "https://yourdomain.com/oauth").
    ///                        If nil, uses the default custom URL scheme (less secure, but no server config required).
    ///                        Universal Links are recommended for production as they cannot be hijacked by other apps.
    ///   - presentingViewController: The view controller to present the authentication session from
    ///   - prefersEphemeralSession: Whether to use an ephemeral browser session. Defaults to true for security.
    ///                              Set to false to enable SSO with Safari cookies (less secure on shared devices).
    ///   - completion: Called when authentication completes with parameters or error
    func authenticate(
        url: String,
        callbackURLPrefix: String? = nil,
        from presentingViewController: UIViewController,
        prefersEphemeralSession: Bool = true,
        completion: @escaping OAuthCompletion
    ) {
        // Determine callback scheme - prefer Universal Links if provided
        let callbackScheme: String

        if let callbackPrefix = callbackURLPrefix,
           let url = URL(string: callbackPrefix),
           url.scheme == "https" {
            // Use Universal Link (more secure)
            callbackScheme = "https"
        } else {
            // Fallback to custom URL scheme
            callbackScheme = Self.oauthCallbackScheme
        }
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
            // Configure ephemeral session preference (defaults to true for security)
            // When true: Session cookies don't persist, no SSO with Safari (more secure)
            // When false: Enables SSO with Safari cookies (convenience vs security tradeoff)
            authSession?.prefersEphemeralWebBrowserSession = prefersEphemeralSession
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
        // Support both custom URL schemes and Universal Links (HTTPS)
        if url.scheme == "https" {
            // For Universal Links, validate against known trusted domains
            // This provides better security as Universal Links cannot be hijacked
            let trustedDomains = ["connect.xyz", "zerohash.com"]
            if let host = url.host {
                return trustedDomains.contains(where: { host.hasSuffix($0) })
            }
            return false
        } else if url.scheme == Self.oauthCallbackScheme {
            // For custom URL scheme, validate scheme and host
            // Note: Custom URL schemes can potentially be hijacked by malicious apps
            let hostMatches = url.host == Self.expectedCallbackHost
            return hostMatches
        }

        // Reject any other schemes
        return false
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
