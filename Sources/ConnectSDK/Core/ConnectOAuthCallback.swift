//
//  ConnectOAuthCallback.swift
//  ConnectSDK
//
//  Public configuration for the Universal Link that ASWebAuthenticationSession
//  returns to at the end of the OAuth flow. The integrator's app must declare
//  `applinks:<host>` in its Associated Domains entitlement, and the host must
//  serve an `apple-app-site-association` file claiming the configured path
//  for the integrator's bundle identifier.
//

import Foundation

public struct ConnectOAuthCallback: Sendable, Equatable {

    /// Host portion of the Universal Link, e.g. `"sdk.connect.xyz"`.
    public let host: String

    /// Path prefix the OAuth callback URL must start with, e.g. `"/oauth-callback"`.
    public let path: String

    public init(host: String, path: String = "/oauth-callback") {
        self.host = host
        self.path = path
    }

    /// Sentinel placeholder used only by the SDK's internal initializers and
    /// test fixtures so they can compile without requiring an explicit value.
    /// The host is deliberately invalid (`unconfigured.invalid` — the `.invalid`
    /// TLD is reserved by RFC 2606 and can never resolve) so any OAuth flow
    /// that actually reaches this value will fail at the ASWebAuthenticationSession
    /// stage, surfacing the misconfiguration loudly rather than silently. The
    /// public `ConnectSDK.configureAuth/Recovery/Withdrawal` entry points do
    /// NOT default to this value — integrators are required to supply their own
    /// `ConnectOAuthCallback`.
    public static let `default` = ConnectOAuthCallback(
        host: "unconfigured.invalid",
        path: "/unconfigured"
    )

    /// Convenience for callers that need the full URL prefix (e.g. for logging).
    public var urlPrefix: String { "https://\(host)\(path)" }

    /// Returns `true` if `url` is a permissible OAuth callback under this
    /// configuration: HTTPS scheme, host matches exactly or is a subdomain via
    /// dot-suffix (`sub.host`), and path begins with the configured path.
    public func matches(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        guard let urlHost = url.host?.lowercased() else { return false }
        let target = host.lowercased()
        let hostOK = urlHost == target || urlHost.hasSuffix("." + target)
        guard hostOK else { return false }
        return url.path.hasPrefix(path)
    }
}
