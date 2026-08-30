//
//  OAuthHandler.swift
//  ConnectSDK
//
//  Handles OAuth authentication flows using ASWebAuthenticationSession with a
//  custom-scheme callback, matching zerohash-ios and both Android SDKs.
//
//  The scheme needs no Info.plist registration and cannot be hijacked here:
//  ASWebAuthenticationSession claims the redirect in-process, inside the session
//  it started, so the system URL router is never consulted and no other app can
//  register to receive it. That is only true of this delivery mechanism. An app
//  receiving the same scheme via `application(_:open:)` would be interceptable.
//
//  The Universal Link callback this replaces required every integrator to own a
//  domain, serve an AASA naming their bundle ID, and have the Connect backend
//  redirect there. The backend redirects to a fixed host per environment instead,
//  so that flow could never complete.
//

import Foundation
import AuthenticationServices

class OAuthHandler: NSObject {

    // MARK: - Constants

    /// Callback scheme the session claims. Shared with zerohash-ios and the
    /// Android SDKs, and with the `oauth-callback` web page that navigates to it.
    static let oauthCallbackScheme = "connectsdk-oauth"

    /// Host the callback URL must use, i.e. `connectsdk-oauth://callback`.
    private static let expectedCallbackHost = "callback"

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
                return "Invalid callback URL received: \(url). Expected: "
                    + "\(OAuthHandler.oauthCallbackScheme)://\(OAuthHandler.expectedCallbackHost)"
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

    /// Initiates the OAuth flow.
    /// - Parameters:
    ///   - url: The OAuth authorization URL.
    ///   - presentingViewController: View controller to present the auth session from.
    ///   - prefersEphemeralSession: Whether to use an ephemeral browser session.
    ///                              Defaults to `true` for security (no SSO with Safari).
    ///   - completion: Invoked with the parsed callback parameters or an error.
    func authenticate(
        url: String,
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

        authSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: Self.oauthCallbackScheme
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

        guard Self.isExpectedCallback(callbackURL) else {
            let host = callbackURL.host ?? "?"
            Log.bridge.error("rejected OAuth callback from unexpected URL host=\(host, privacy: .private) scheme=\(callbackURL.scheme ?? "?", privacy: .private)")
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

    /// The session only ever hands back URLs on the configured scheme, so this is
    /// belt-and-braces against a provider appending an unexpected host.
    static func isExpectedCallback(_ url: URL) -> Bool {
        url.scheme?.lowercased() == oauthCallbackScheme
            && url.host?.lowercased() == expectedCallbackHost
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
