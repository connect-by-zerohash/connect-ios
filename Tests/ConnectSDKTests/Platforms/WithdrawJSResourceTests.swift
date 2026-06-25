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
        for fn in ["function enterOtp", "function fillOtpCode", "function pollFor2faResolution",
                   "function moduleState"] {
            XCTAssertTrue(body.contains(fn), "missing driver: \(fn)")
        }
    }
}
