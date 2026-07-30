import XCTest
@testable import ConnectSDK

/// Verifies withdraw.js ships in the SDK bundle and exposes the expected
/// `window.__zhWithdraw` surface + a sampling of ported selectors. Static string
/// assertions only — no WebView/JS execution (xcodebuild tests can't reliably
/// evaluate JS). Mirrors DomHelpersResourceTests.
final class WithdrawJSResourceTests: XCTestCase {
    private func loadWithdraw() throws -> String {
        let url = try XCTUnwrap(
            Coinbase.resourceBundle.url(forResource: "withdraw", withExtension: "js"),
            "withdraw.js must be bundled (Package.swift .process)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testResourceIsBundled() throws {
        XCTAssertFalse(try loadWithdraw().isEmpty)
    }

    func testInstallsZhWithdrawNamespace() throws {
        XCTAssertTrue(try loadWithdraw().contains("window.__zhWithdraw ="))
    }

    func testExposesEntryPoints() throws {
        let body = try loadWithdraw()
        for key in ["start:", "continue:", "cancel:"] {
            XCTAssertTrue(body.contains(key), "missing entry point: \(key)")
        }
    }

    func testIncludesKeySelectors() throws {
        let body = try loadWithdraw()
        for selector in ["quick-action-send", "recipient-search-input",
                         "preview-send-button", "send-now-button", "#one-time-code"] {
            XCTAssertTrue(body.contains(selector), "missing selector: \(selector)")
        }
    }

    func testIncludesWithdrawLocalHelpers() throws {
        let body = try loadWithdraw()
        for helper in ["queryVisible", "waitForAny", "pollUntil",
                       "setReactValue", "typeLikeHuman", "waitForButtonByText"] {
            XCTAssertTrue(body.contains(helper), "missing helper: \(helper)")
        }
    }

    func testIncludesSendModalDrivers() throws {
        let body = try loadWithdraw()
        for fn in ["function openSendModal", "openSendModalStandard", "openSendModalAdvance"] {
            XCTAssertTrue(body.contains(fn), "missing driver: \(fn)")
        }
    }

    func testIncludesSelectionAndAmountDrivers() throws {
        let body = try loadWithdraw()
        for fn in ["function enterRecipient", "function detectNextScreen", "function selectCoin",
                   "function selectNetwork", "function enterAmount", "function ensureCurrencyMode",
                   "function runSelectionPhase", "function readActiveStep"] {
            XCTAssertTrue(body.contains(fn), "missing driver: \(fn)")
        }
    }

    func testIncludesConfirmAndTwoFaDrivers() throws {
        let body = try loadWithdraw()
        for fn in ["function confirmAndSend", "function detectAndHandle2fa", "function waitForResult",
                   "function fillTravelRule", "function fillTransferDetails", "function dismissNetworkWarning"] {
            XCTAssertTrue(body.contains(fn), "missing driver: \(fn)")
        }
    }

    func testIncludesContinuePathDrivers() throws {
        let body = try loadWithdraw()
        for fn in ["function enterOtp", "function fillOtpCode", "function moduleState"] {
            XCTAssertTrue(body.contains(fn), "missing driver: \(fn)")
        }
    }

    /// The post-confirm detection split: a DOM reader, a pure classifier, a polling
    /// loop, and the latch that keeps a reported hold from decaying into success.
    /// `start` and `continue({kind:"poll"})` both settle through `settlePostConfirm`,
    /// which replaced `pollFor2faResolution` and the fixed 1500 ms sleep.
    func testIncludesPostConfirmDetection() throws {
        let body = try loadWithdraw()
        for fn in ["function probePostConfirm", "function classifyPostConfirm",
                   "function settlePostConfirm", "function rememberOutcome"] {
            XCTAssertTrue(body.contains(fn), "missing driver: \(fn)")
        }
    }

    /// Structural guards on the two invariants that carry the fix. These are
    /// defence in depth, not the primary guard — `withdraw-classify.test.mjs`
    /// exercises both behaviourally, and inverting the latch ordering does fail
    /// "a session that saw a hold never falls back to none" there. What these add
    /// is a signal from the *bundled* artifact, which the JS suite never reads.
    func testFixedSleepAndStickyLatchInvariants() throws {
        let body = try loadWithdraw()
        XCTAssertFalse(body.contains("D.sleep(1500)"),
                       "the fixed post-confirm sleep is the root cause; it must not return")
        let latch = try XCTUnwrap(body.range(of: "if (p.sawIdVerification)"))
        let fallback = try XCTUnwrap(body.range(of: "if (!p.overlay)"))
        XCTAssertTrue(latch.lowerBound < fallback.lowerBound,
                      "the sticky hold latch must be checked BEFORE the modal-gone fallback, "
                      + "or a held send can still report submitted")
    }

    /// `start` and `continue({kind:"poll"})` must both settle through
    /// `settlePostConfirm`, on their own budgets. Nothing else in either suite pins
    /// these two constants: unify them by accident and no test notices, while host
    /// poll latency silently triples.
    func testPostConfirmBudgets() throws {
        let body = try loadWithdraw()
        XCTAssertTrue(body.contains("settlePostConfirm(30000)"), "start budget changed")
        XCTAssertTrue(body.contains("settlePostConfirm(10000)"), "poll budget changed")
    }

    /// The risk screen is matched by data-testid, never by button text — the captured
    /// account renders it in Portuguese, so the old English lookups never matched.
    ///
    /// The dead-text check runs against CODE ONLY. Comments legitimately discuss
    /// Coinbase's "Cancel transfer" button, and coupling the assertion to prose
    /// would redden the suite on a harmless comment edit.
    func testRiskScreenSelectorsAreTestIdBased() throws {
        let body = try loadWithdraw()
        for selector in ["step-riskSelfServeStep-active", "start-challenge-button",
                         "step-idVerification-active", "id-capture-reskinned-failure-view",
                         "verify_access_loader", "status-animation-success"] {
            XCTAssertTrue(body.contains(selector), "missing selector: \(selector)")
        }
        let code = body
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String($0) }
            .joined(separator: "\n")
        for dead in ["\"Start ID check\"", "\"Cancel transfer\""] {
            XCTAssertFalse(code.contains(dead),
                           "localized button text must not be matched in code: \(dead)")
        }
    }
}
