//
//  OAuthHandler.swift
//  ConnectSDK
//
//  Handles OAuth authentication flows using ASWebAuthenticationSession with a
//  Universal Link callback. The custom URL scheme used in earlier versions has
//  been removed: custom schemes are not unique to one app and can be hijacked
//  by other apps shipping the same SDK. The integrator's app must declare an
//  `applinks:<host>` Associated Domains entitlement matching the configured
//  ConnectOAuthCallback, and the host must serve an `apple-app-site-association`
//  file claiming the configured path for that bundle identifier.
//

import Foundation
import AuthenticationServices

class OAuthHandler: NSObject {

    // MARK: - Types

    enum OAuthError: LocalizedError {
        case userCancelled
        case invalidURL
        case missingCallback
        case missingParameters
        case sessionFailed(String)
        case invalidCallbackURL(String)

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
                return "Invalid callback URL received: \(url)"
            }
        }
    }

    typealias OAuthResult = Result<[String: String], Error>
    typealias OAuthCompletion = (OAuthResult) -> Void

    // MARK: - Properties

    private var authSession: ASWebAuthenticationSession?
    private var completion: OAuthCompletion?
    private weak var presentingViewController: UIViewController?
    private var callback: ConnectOAuthCallback?

    // MARK: - Public Methods

    /// Initiates the OAuth flow.
    /// - Parameters:
    ///   - url: The OAuth authorization URL.
    ///   - callback: Universal Link callback configuration. The integrator's app
    ///               must declare `applinks:<callback.host>` in Associated Domains
    ///               and the host must serve a matching AASA file.
    ///   - presentingViewController: View controller to present the auth session from.
    ///   - prefersEphemeralSession: Whether to use an ephemeral browser session.
    ///                              Defaults to `true` for security (no SSO with Safari).
    ///   - completion: Invoked with the parsed callback parameters or an error.
    func authenticate(
        url: String,
        callback: ConnectOAuthCallback,
        from presentingViewController: UIViewController,
        prefersEphemeralSession: Bool = true,
        completion: @escaping OAuthCompletion
    ) {
        guard let authURL = URL(string: url) else {
            completion(.failure(OAuthError.invalidURL))
            return
        }

        self.completion = completion
        self.presentingViewController = presentingViewController
        self.callback = callback

        authSession = ASWebAuthenticationSession(
            url: authURL,
            callback: .https(host: callback.host, path: callback.path)
        ) { [weak self] callbackURL, error in
            self?.handleAuthenticationResult(callbackURL: callbackURL, error: error)
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = prefersEphemeralSession

        let started = authSession?.start() ?? false
        if !started {
            completion(.failure(OAuthError.sessionFailed("Failed to start authentication session")))
            cleanup()
        }
    }

    /// Cancels any ongoing authentication session.
    func cancel() {
        authSession?.cancel()
        completion?(.failure(OAuthError.userCancelled))
        cleanup()
    }

    // MARK: - Private Methods

    private func handleAuthenticationResult(callbackURL: URL?, error: Error?) {
        defer { cleanup() }

        if let error = error {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                completion?(.failure(OAuthError.userCancelled))
            } else {
                completion?(.failure(error))
            }
            return
        }

        guard let callbackURL = callbackURL else {
            completion?(.failure(OAuthError.missingCallback))
            return
        }

        guard let callback = callback, callback.matches(callbackURL) else {
            let host = callbackURL.host ?? "?"
            Log.bridge.error("rejected OAuth callback from unexpected URL host=\(host, privacy: .private) path=\(callbackURL.path, privacy: .private)")
            completion?(.failure(OAuthError.invalidCallbackURL(callbackURL.absoluteString)))
            return
        }

        let parameters = parseOAuthParameters(from: callbackURL)
        if parameters.isEmpty {
            completion?(.failure(OAuthError.missingParameters))
        } else {
            completion?(.success(parameters))
        }
    }

    private func parseOAuthParameters(from url: URL) -> [String: String] {
        var parameters: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems {
                if let value = item.value {
                    parameters[item.name] = value
                }
            }
        }

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

        parameters["callback_url"] = url.absoluteString
        return parameters
    }

    private func cleanup() {
        authSession = nil
        completion = nil
        presentingViewController = nil
        callback = nil
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OAuthHandler: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window = presentingViewController?.view.window {
            return window
        }

        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            return windowScene.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }

        return ASPresentationAnchor()
    }
}
