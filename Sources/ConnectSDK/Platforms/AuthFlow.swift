import Foundation

// MARK: - Result types (Codable so they round-trip into JSONValue cleanly)

public struct AuthLoginResult: Codable, Equatable, Sendable {
    /// Definitive logged-in state, folded from an auth.status check on the
    /// success path. False for user-closed / timeout outcomes.
    public let loggedIn: Bool
    /// Discriminant for UI messaging:
    /// "success" | "user-closed" | "timeout" | "passkey-only".
    public let outcome: String
    public init(loggedIn: Bool, outcome: String) {
        self.loggedIn = loggedIn
        self.outcome = outcome
    }
}

public struct AuthStatusResult: Codable, Equatable, Sendable {
    public let loggedIn: Bool
    public init(loggedIn: Bool) { self.loggedIn = loggedIn }
}

// MARK: - Flow protocol

public protocol AuthFlow: PlatformIdentity {
    @MainActor func login(ctx: ExecutionContext) async throws -> AuthLoginResult
    @MainActor func status(ctx: ExecutionContext) async throws -> AuthStatusResult
}
