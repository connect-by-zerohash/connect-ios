import UIKit

public class ConnectSDK {

    // MARK: - Public API

    /// Configures an auth session that can be presented later
    /// Configure while fetching JWT, then present instantly for optimal UX
    /// - Parameters:
    ///   - jwt: JWT token for authentication
    ///   - environment: Environment to use (defaults to production)
    ///   - theme: UI theme (defaults to system)
    ///   - callbacks: Optional callbacks for auth events
    /// - Returns: A ConnectAuthSession that can be presented when ready
    @MainActor
    public static func configureAuth(
        jwt: String,
        environment: Environment = .production,
        theme: Theme = .system,
        callbacks: AuthCallbacks = AuthCallbacks()
    ) -> ConnectAuthSession {
        return ConnectAuthSession(jwt: jwt, environment: environment, theme: theme, callbacks: callbacks)
    }
}
