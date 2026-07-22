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

// MARK: - Website Data

extension ConnectSDK {

    /// Clears all website data (cookies, localStorage, IndexedDB, caches, service
    /// workers, …) from the SDK's private `WKWebsiteDataStore`.
    ///
    /// The SDK uses a persistent store, isolated from the host app's own
    /// `WKWebView` storage, so that third-party session state (e.g. a exchange
    /// login) can be reused by the offscreen `auth.status` runner and the modal
    /// login flow. That state survives app relaunches by design.
    ///
    /// Call this on user sign-out from your app, or from a "clear cache"
    /// affordance, to remove that persisted state. Calling during an active
    /// session invalidates cookies and storage the running session may depend on.
    @MainActor
    public static func clearWebsiteData() async {
        let store = WKWebsiteDataStore(forIdentifier: SDKDataStoreIdentifier.shared)
        await store.removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
    }
}

// MARK: - SDK Version

extension ConnectSDK {
    public static let version: String = "0.1.0"
}
