import Foundation
import UIKit
import WebKit
@testable import ConnectSDK

// Test-only hooks that drive production view controllers and helpers without
// real WebKit navigations or timers. These live in the test target (not in
// Sources) so production code is never dirtied with test utilities. They reach
// into `internal` members via `@testable import ConnectSDK`.

// MARK: - AutomatedWebViewController

@MainActor
extension AutomatedWebViewController {
    /// Complete the run with a successful result, as if the script returned it.
    func testComplete(withResult result: Any?) {
        complete(.success(result))
    }

    /// Complete the run by throwing, as if the script (or load) failed.
    func testComplete(throwing error: Error) {
        complete(.failure(error))
    }

    /// Drive a settle decision as if a `didFinish` arrived for `url`, without
    /// a real navigation. `.evaluate` cannot run without a live page, so this
    /// hook only exercises the `.waitMore` / `.answer` branches.
    func testTriggerSettle(decision: OffscreenSettleDecision, url: URL) {
        guard !didComplete, !didStartEvaluation else { return }
        switch decision {
        case .waitMore:
            return
        case .answer(let value):
            didStartEvaluation = true
            complete(.success(value))
        case .evaluate:
            // No live WebView in tests; treat as a no-op so tests stay
            // deterministic. Real evaluation is covered via testComplete.
            didStartEvaluation = true
        }
    }

    /// Exercise the timeout completion path without waiting for the timer.
    func testTriggerTimeout() {
        complete(.failure(AutomatedRunError.timeout))
    }

    /// Exercise the load-failure completion path without a real navigation.
    func testTriggerLoadFailure(_ detail: String) {
        complete(.failure(AutomatedRunError.loadFailed(detail)))
    }
}

// MARK: - ModalViewController

@MainActor
extension ModalViewController {
    /// Test-only entry point that exercises the cancel pathway without
    /// requiring a UIBarButtonItem tap.
    func testTriggerCancel() {
        dismissModal(reason: .userClosed)
    }

    /// Test-only entry point that simulates the "navigated to host" event
    /// without a real WebKit navigation. Delegates to the production decision.
    func testTriggerNavigationOff(host newHost: String) {
        evaluateDismiss(forHost: newHost)
    }

    /// Test-only entry point that exercises the timeout pathway without
    /// waiting for the real timer to fire.
    func testTriggerTimeout() {
        dismissModal(reason: .timeout)
    }

    /// Test-only entry point that simulates an auto-close probe matching
    /// without driving the real DOM poll. (AUTH-3285)
    func testTriggerConditionMet(code: String = "test") {
        dismissModal(reason: .conditionMet(code))
    }

    /// Test-only: exercise popup presentation/tracking without a real
    /// window.open. Returns the controller so the test can drive its lifecycle.
    @discardableResult
    func testTriggerOpenPopup(title: String?) -> PopupWebViewController {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        return presentPopup(webView: web, title: title)
    }
}

// MARK: - PopupWebViewController

@MainActor
extension PopupWebViewController {
    /// Test-only entry point that exercises the Cancel pathway without a real
    /// UIBarButtonItem tap. Fires the configured cancel action, driving the same
    /// production code path (`onCancelTapped` → `close()`).
    func testTriggerCancel() {
        guard let item = navigationItem.leftBarButtonItem,
              let action = item.action,
              let target = item.target as? NSObject else { return }
        target.perform(action)
    }

    /// Test-only: simulate the popup navigating to `url` and run rejection
    /// detection without a real WebKit load. Drives the SAME production method
    /// (`checkRejection`) the `didCommit` delegate calls, so the test can't drift.
    func testTriggerNavigation(to url: URL) {
        checkRejection(url)
    }
}

// MARK: - LoadingOverlayView

extension LoadingOverlayView {
    var currentTitleText: String? { titleLabel.text }
    var currentSubtitleText: String? { subtitleLabel.text }
}

// MARK: - ContentRuleList

extension ContentRuleList {
    /// Test-only entry point that compiles a caller-supplied encoded rule
    /// string and skips `encodedRules`. Feeding it deliberately invalid JSON
    /// makes the real `WKContentRuleListStore` fail to compile, which runs the
    /// fail-closed path against WebKit itself rather than a mock.
    @MainActor
    static func compileForTesting(
        encoded: String,
        completion: @escaping @MainActor (WKContentRuleList?) -> Void
    ) {
        guard let store = WKContentRuleListStore.default() else {
            reportCompileFailure("content rule list store unavailable")
            completion(nil)
            return
        }
        store.compileContentRuleList(
            forIdentifier: identifier(for: encoded),
            encodedContentRuleList: encoded
        ) { list, error in
            Task { @MainActor in
                if list == nil {
                    reportCompileFailure("content rule list compile failed: \(error?.localizedDescription ?? "unknown error")")
                }
                completion(list)
            }
        }
    }
}
