import Foundation
import UIKit
import WebKit
@testable import ConnectSDK

/// Mock for the user-driven login modal (`ModalWebViewHandle`).
@MainActor
final class MockModalHandle: ModalWebViewHandle {
    var currentURL: URL?
    var closeReason: ModalCloseReason = .success
    private(set) var dismissed = false
    var defaultEvaluateResult: Any? = nil
    private(set) var evaluatedScripts: [String] = []

    func dismiss() async { dismissed = true }
    func evaluate(_ js: String) async throws -> Any? {
        evaluatedScripts.append(js)
        return defaultEvaluateResult
    }
    func waitForClose() async -> ModalCloseReason { closeReason }
}

/// Mock for the long-lived automation session (`AutomationSessionHandle`) used by
/// withdraw. Scripts `evaluateAsync` results and records the choreography calls.
@MainActor
final class MockAutomationSessionHandle: AutomationSessionHandle {
    var currentURL: URL?
    private(set) var dismissed = false
    /// FIFO of results returned by successive `evaluateAsync` calls. When empty,
    /// returns `defaultEvaluateResult`. Lets a test script a multi-step withdraw
    /// conversation (start → continue → terminal).
    var evaluateResults: [Result<Any?, Error>] = []
    var defaultEvaluateResult: Any? = nil
    /// Scripts passed to `evaluateAsync`, in order — so tests can assert payload
    /// (e.g. an OTP code) reached the injected script.
    private(set) var evaluatedScripts: [String] = []
    /// Arguments dictionaries passed to `evaluateAsync`, in order — so tests can
    /// assert request data was passed as bound arguments (not interpolated).
    private(set) var evaluatedArguments: [[String: Any]] = []

    func dismiss() async { dismissed = true }

    func awaitInitialLoad() async {}

    private(set) var overlayRevealed: Bool?
    func revealOverlay(_ revealed: Bool) { overlayRevealed = revealed }

    private(set) var stepAsideCount = 0
    private(set) var resumeCount = 0
    func stepAside() async { stepAsideCount += 1 }
    func resume() async { resumeCount += 1 }

    private(set) var pauseTimeoutCount = 0
    private(set) var restartTimeoutCount = 0
    func pauseTimeout() { pauseTimeoutCount += 1 }
    func restartTimeout() { restartTimeoutCount += 1 }

    func evaluateAsync(_ js: String, arguments: [String: Any]) async throws -> Any? {
        evaluatedScripts.append(js)
        evaluatedArguments.append(arguments)
        if !evaluateResults.isEmpty {
            switch evaluateResults.removeFirst() {
            case .success(let v): return v
            case .failure(let e): throw e
            }
        }
        return defaultEvaluateResult
    }
}

@MainActor
final class MockExecutionContext: ExecutionContext {
    struct ModalCall {
        let url: URL
        let policy: ModalHostPolicy
        let title: String?
        let autoClose: ModalAutoClose?
        let documentStartJS: String?
    }
    struct AutomationCall { let url: URL; let overlay: OverlayOptions; let showOverlay: Bool }
    struct OffscreenCall {
        let url: URL
        let script: String
        /// Bound arguments passed to WebKit (never interpolated into the source)
        /// — tests assert request data travels this channel (.
        let arguments: [String: Any]
        let timeoutMs: Int
        /// The settle predicate the platform passed in. Tests can call this
        /// to probe the behaviour for specific URLs.
        let settle: @MainActor (URL) -> OffscreenSettleDecision
    }
    struct VisibleCall {
        let url: URL
        let script: String
        /// Bound arguments passed to WebKit (never interpolated into the source)
        /// — tests assert request data travels this channel.
        let arguments: [String: Any]
        let overlay: OverlayOptions
        let showOverlay: Bool
        let waitForChallengeClearance: Bool
        let timeoutMs: Int
        /// The settle predicate the platform passed in. Tests can call this
        /// to probe the behaviour for specific URLs.
        let settle: @MainActor (URL) -> OffscreenSettleDecision
    }

    var modalCalls: [ModalCall] = []
    var automationCalls: [AutomationCall] = []
    var offscreenCalls: [OffscreenCall] = []
    var offscreenResult: Any? = nil
    var visibleCalls: [VisibleCall] = []
    var visibleResult: Any? = nil
    /// When set, the next `runVisibleWebView` call throws this instead of
    /// returning `visibleResult` — lets tests exercise the throwing path.
    var visibleError: Error? = nil
    /// FIFO outcomes for successive runVisibleWebView calls. When non-empty,
    /// each call pops the next outcome (returning a value or throwing). Falls
    /// back to visibleError/visibleResult when empty.
    var visibleOutcomes: [Result<Any?, Error>] = []
    /// Reason the next presented modal will report from `waitForClose()`.
    var modalCloseReason: ModalCloseReason = .success
    /// When set, `presentModalWebView` returns THIS handle (stamping its
    /// `currentURL`) instead of a fresh one.
    var modalHandleToReturn: MockModalHandle? = nil
    /// When set, `presentAutomationSession` returns THIS handle (stamping its
    /// `currentURL`) instead of a fresh one — lets a test pre-configure the
    /// handle's `evaluateResults` before the call that creates it.
    var automationHandleToReturn: MockAutomationSessionHandle? = nil
    var dataStore: WKWebsiteDataStore { WKWebsiteDataStore.default() }

    func presentModalWebView(
        url: URL,
        hostPolicy: ModalHostPolicy,
        title: String?,
        autoClose: ModalAutoClose?,
        documentStartJS: String?
    ) async throws -> ModalWebViewHandle {
        modalCalls.append(.init(url: url, policy: hostPolicy, title: title,
                                autoClose: autoClose, documentStartJS: documentStartJS))
        if let injected = modalHandleToReturn {
            injected.currentURL = url
            return injected
        }
        let h = MockModalHandle(); h.currentURL = url
        h.closeReason = modalCloseReason
        return h
    }

    func presentAutomationSession(
        url: URL,
        overlay: OverlayOptions,
        showOverlay: Bool
    ) async throws -> AutomationSessionHandle {
        automationCalls.append(.init(url: url, overlay: overlay, showOverlay: showOverlay))
        if let injected = automationHandleToReturn {
            injected.currentURL = url
            return injected
        }
        let h = MockAutomationSessionHandle(); h.currentURL = url
        return h
    }

    func runOffscreenWebView(
        url: URL,
        settle: @MainActor @escaping (URL) -> OffscreenSettleDecision,
        injectedScript: String,
        arguments: [String: Any] = [:],
        timeoutMs: Int
    ) async throws -> Any? {
        offscreenCalls.append(.init(
            url: url,
            script: injectedScript,
            arguments: arguments,
            timeoutMs: timeoutMs,
            settle: settle
        ))
        return offscreenResult
    }

    func runVisibleWebView(
        url: URL,
        settle: @MainActor @escaping (URL) -> OffscreenSettleDecision,
        injectedScript: String,
        arguments: [String: Any] = [:],
        overlay: OverlayOptions,
        showOverlay: Bool,
        waitForChallengeClearance: Bool = false,
        timeoutMs: Int
    ) async throws -> Any? {
        visibleCalls.append(.init(
            url: url,
            script: injectedScript,
            arguments: arguments,
            overlay: overlay,
            showOverlay: showOverlay,
            waitForChallengeClearance: waitForChallengeClearance,
            timeoutMs: timeoutMs,
            settle: settle
        ))
        if !visibleOutcomes.isEmpty {
            switch visibleOutcomes.removeFirst() {
            case .success(let v): return v
            case .failure(let e): throw e
            }
        }
        if let visibleError { throw visibleError }
        return visibleResult
    }
}
