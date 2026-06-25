import UIKit
import WebKit

public class ConnectSDK {

    // MARK: - Public API

    /// Configures an auth session that can be presented later
    /// Configure while fetching JWT, then present instantly for optimal UX
    /// - Parameters:
    ///   - jwt: JWT token for authentication
    ///   - environment: Environment to use (defaults to production)
    ///   - theme: UI theme (defaults to system)
    ///   - callbacks: Optional callbacks for auth events
    ///   - allowList: Hosts permitted for navigation and resource loads (defaults to the SDK's built-in list)
    ///   - oauthCallback: Universal Link callback for the OAuth flow. Required — the integrator's app must
    ///                    declare `applinks:<host>` and `webcredentials:<host>` in Associated Domains and
    ///                    the host must serve a matching AASA. See `docs/UNIVERSAL_LINKS.md`.
    /// - Returns: A ConnectAuthSession that can be presented when ready
    @MainActor
    public static func configureAuth(
        jwt: String,
        environment: Environment = .production,
        theme: Theme = .system,
        callbacks: AuthCallbacks = AuthCallbacks(),
        allowList: ConnectAllowList = .default,
        oauthCallback: ConnectOAuthCallback
    ) -> ConnectAuthSession {
        return ConnectAuthSession(jwt: jwt, environment: environment, theme: theme, callbacks: callbacks, allowList: allowList, oauthCallback: oauthCallback)
    }

    /// Configures a recovery session that can be presented later
    /// - Parameters:
    ///   - jwt: JWT token for authentication
    ///   - environment: Environment to use (defaults to production)
    ///   - theme: UI theme (defaults to system)
    ///   - callbacks: Optional callbacks for recovery events
    ///   - allowList: Hosts permitted for navigation and resource loads (defaults to the SDK's built-in list)
    ///   - oauthCallback: Universal Link callback for the OAuth flow. Required — see `configureAuth` docs.
    /// - Returns: A ConnectRecoverySession that can be presented when ready
    @MainActor
    public static func configureRecovery(
        jwt: String,
        environment: Environment = .production,
        theme: Theme = .system,
        callbacks: RecoveryCallbacks = RecoveryCallbacks(),
        allowList: ConnectAllowList = .default,
        oauthCallback: ConnectOAuthCallback
    ) -> ConnectRecoverySession {
        return ConnectRecoverySession(jwt: jwt, environment: environment, theme: theme, callbacks: callbacks, allowList: allowList, oauthCallback: oauthCallback)
    }

    /// Configures a withdrawal session that can be presented later
    /// - Parameters:
    ///   - jwt: JWT token for authentication
    ///   - environment: Environment to use (defaults to production)
    ///   - theme: UI theme (defaults to system)
    ///   - callbacks: Optional callbacks for withdrawal events
    ///   - allowList: Hosts permitted for navigation and resource loads (defaults to the SDK's built-in list)
    ///   - oauthCallback: Universal Link callback for the OAuth flow. Required — see `configureAuth` docs.
    /// - Returns: A ConnectWithdrawalSession that can be presented when ready
    @MainActor
    public static func configureWithdrawal(
        jwt: String,
        environment: Environment = .production,
        theme: Theme = .system,
        callbacks: WithdrawalCallbacks = WithdrawalCallbacks(),
        allowList: ConnectAllowList = .default,
        oauthCallback: ConnectOAuthCallback
    ) -> ConnectWithdrawalSession {
        return ConnectWithdrawalSession(jwt: jwt, environment: environment, theme: theme, callbacks: callbacks, allowList: allowList, oauthCallback: oauthCallback)
    }
}

// MARK: - SDK Version

extension ConnectSDK {
    public static let version: String = "0.1.0"
}
