import Foundation

/// A generic auto-close rule for a modal WebView. While the modal is open the
/// supplied JavaScript is evaluated on an interval; the modal force-closes with
/// `ModalCloseReason.conditionMet` once the script returns `true` for
/// `requiredHits` consecutive reads.
///
/// Platform-agnostic by design: the caller supplies the probe script and
/// decides what a `.conditionMet` close means (e.g. Coinbase maps it to a
/// passkey-only `auth.login` outcome). The interval doubles as the confirm gap
/// between reads, so a transient/half-rendered DOM state can't trigger a close.
public struct ModalAutoClose: Sendable {
    /// JS evaluated against the live page; must evaluate to a `Bool`.
    public let probeJS: String
    /// Delay between successive reads (and the confirm gap between hits).
    public let intervalMs: Int
    /// Consecutive positive reads required before closing.
    public let requiredHits: Int

    public init(probeJS: String, intervalMs: Int = 250, requiredHits: Int = 2) {
        self.probeJS = probeJS
        self.intervalMs = intervalMs
        self.requiredHits = requiredHits
    }
}
