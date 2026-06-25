import Testing
import UIKit
import WebKit
@testable import ConnectSDK

@MainActor
@Suite("AutomatedWebViewController")
struct AutomatedWebViewControllerTests {

    // MARK: - Helpers

    private func makeVC(
        timeoutMs: Int = 30_000,
        showOverlay: Bool = true,
        settle: @escaping @MainActor (URL) -> OffscreenSettleDecision = { _ in .waitMore }
    ) -> AutomatedWebViewController {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        return AutomatedWebViewController(
            url: URL(string: "https://www.coinbase.com/")!,
            settle: settle,
            script: "(async () => 'ignored')()",
            overlay: .default,
            showOverlay: showOverlay,
            sharedConfig: cfg,
            timeoutMs: timeoutMs
        )
    }

    // MARK: - Lifecycle / construction

    @Test("Instantiates cleanly and installs an overlay subview")
    func instantiatesWithOverlay() async {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        let hasOverlay = vc.view.subviews.contains { $0 is LoadingOverlayView }
        #expect(hasOverlay)
    }

    @Test("showOverlay:false suppresses the loading overlay so the user watches the page")
    func suppressesOverlayWhenShowOverlayFalse() async {
        let vc = makeVC(showOverlay: false)
        vc.loadViewIfNeeded()
        let hasOverlay = vc.view.subviews.contains { $0 is LoadingOverlayView }
        #expect(!hasOverlay)
    }

    // MARK: - Result paths

    @Test("runToResult returns the value when the run completes with a result")
    func returnsResult() async throws {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        Task { @MainActor in vc.testComplete(withResult: "abc123") }
        let result = try await vc.runToResult()
        #expect(result as? String == "abc123")
    }

    @Test("settle .answer completes the run with that value (no script)")
    func answerCompletesWithValue() async throws {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        Task { @MainActor in
            vc.testTriggerSettle(decision: .answer(nil), url: URL(string: "https://login.coinbase.com/")!)
        }
        let result = try await vc.runToResult()
        #expect(result == nil)
    }

    @Test("runToResult awaited AFTER completion returns the stored outcome")
    func awaitedAfterCompletion() async throws {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        vc.testComplete(withResult: 42)
        let result = try await vc.runToResult()
        #expect(result as? Int == 42)
    }

    // MARK: - Error paths

    @Test("runToResult throws on timeout with a useful message")
    func throwsOnTimeout() async {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        vc.testTriggerTimeout()
        do {
            _ = try await vc.runToResult()
            Issue.record("expected throw")
        } catch {
            #expect(error.localizedDescription.lowercased().contains("timeout"))
        }
    }

    @Test("runToResult throws a JSException whose message is preserved")
    func preservesJSExceptionMessage() async {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        Task { @MainActor in
            vc.testComplete(throwing: JSException(message: "requires an amount"))
        }
        do {
            _ = try await vc.runToResult()
            Issue.record("expected throw")
        } catch {
            #expect(error.localizedDescription == "requires an amount")
        }
    }

    @Test("runToResult throws .loadFailed on a load failure")
    func throwsOnLoadFailure() async {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        Task { @MainActor in vc.testTriggerLoadFailure("boom") }
        do {
            _ = try await vc.runToResult()
            Issue.record("expected throw")
        } catch {
            #expect(error.localizedDescription.contains("boom"))
        }
    }

    // MARK: - Idempotency

    @Test("Triggering completion twice resolves the waiter once and does not crash")
    func idempotentCompletion() async throws {
        let vc = makeVC()
        vc.loadViewIfNeeded()
        vc.testComplete(withResult: "first")
        // A second completion is a no-op; the stored outcome stays "first".
        vc.testComplete(withResult: "second")
        vc.testTriggerTimeout()
        let result = try await vc.runToResult()
        #expect(result as? String == "first")
    }
}
