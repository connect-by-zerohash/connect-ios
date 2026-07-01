import Testing
import WebKit
@testable import ConnectSDK

/// Fixture tests for Coinbase's login auto-close probe (`loginProbeJS`), which
/// embeds the signup and unsupported-2FA detectors. Runs the real bundled JS
/// against minimal DOM fixtures via the offscreen runner and asserts the
/// resolved condition code. Guards the false-positive fixed here: SMS+passkey
/// accounts must NOT resolve `passkey-only`.
@MainActor
@Suite("Coinbase auth detection")
struct CoinbaseAuthDetectionTests {

    /// Runs the login probe against a `<body>` fragment on the login host and
    /// returns the resolved condition code (nil when the probe returns null).
    private func probe(body: String) async throws -> String? {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let html = "<html><body>\(body)</body></html>"
        let result = try await runner.runHTML(
            html: html,
            baseURL: URL(string: "https://login.coinbase.com/signin")!,
            script: Coinbase.loginProbeJS,
            timeoutMs: 5_000
        )
        return result as? String
    }

    // MARK: - Genuinely unsupported → passkey-only

    @Test("old-design passkey-verify screen resolves passkey-only")
    func oldDesignPasskeyVerify() async throws {
        let code = try await probe(body: #"<button data-testid="passkey-verify-button"></button>"#)
        #expect(code == "passkey-only")
    }

    @Test("new-design passkey screen with no fallback resolves passkey-only")
    func newDesignPasskeyNoFallback() async throws {
        let code = try await probe(
            body: #"<div data-testid="identity-multi-content-layout-content-wrapper-passkey-auth-x"></div>"#
        )
        #expect(code == "passkey-only")
    }

    // MARK: - SMS+passkey (the fixed false positive) → NOT passkey-only

    @Test("passkey screen with an unexpanded try-another-way tray is not passkey-only")
    func passkeyWithClosedTray() async throws {
        let code = try await probe(body: """
        <div data-testid="identity-multi-content-layout-content-wrapper-passkey-auth-x"></div>
        <button data-testid="try-another-way-button"></button>
        """)
        #expect(code == nil)
    }

    @Test("passkey screen with an expanded tray exposing SMS is not passkey-only")
    func passkeyWithExpandedTraySms() async throws {
        let code = try await probe(body: """
        <div data-testid="identity-multi-content-layout-content-wrapper-passkey-auth-x"></div>
        <button data-testid="try-another-way-button"></button>
        <div data-testid="tray">
          <button data-testid="two-factor-button-SMS"></button>
          <button data-testid="two-factor-button-SMS-cell-pressable"></button>
        </div>
        """)
        #expect(code == nil)
    }

    // MARK: - Other supported states → NOT passkey-only

    @Test("SMS OTP entry screen is not passkey-only")
    func smsPrimaryScreen() async throws {
        let code = try await probe(body: """
        <div data-testid="sms-input-code"></div>
        <button data-testid="try-another-way-button"></button>
        """)
        #expect(code == nil)
    }

    @Test("passkey screen with a password fallback is not passkey-only")
    func passkeyWithPassword() async throws {
        let code = try await probe(body: """
        <div data-testid="identity-multi-content-layout-content-wrapper-passkey-auth-x"></div>
        <input type="password" />
        """)
        #expect(code == nil)
    }
}
