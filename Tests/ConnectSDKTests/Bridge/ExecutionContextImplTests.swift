import Testing
import UIKit
import WebKit
@testable import ConnectSDK

/// Captures emitEvent calls so we can assert on cancellation routing.
final class TestEventRecorder: BridgeEventEmitting {
    private(set) var events: [(String, String)] = []
    func emitEvent(correlationId: String, type: String) {
        events.append((correlationId, type))
    }
}

@MainActor
@Suite("ExecutionContextImpl")
struct ExecutionContextImplTests {

    @Test("dataStore matches the SharedWebViewConfiguration's store, not .default()")
    func dataStoreMatchesShared() {
        let host = UIViewController()
        let shared = SharedWebViewConfiguration()
        let recorder = TestEventRecorder()
        let ctx = ExecutionContextImpl(
            host: host, shared: shared,
            currentRequestId: "r1",
            eventEmitter: recorder
        )
        #expect(ctx.dataStore === shared.dataStore)
        #expect(ctx.dataStore !== WKWebsiteDataStore.default())
    }

    @Test("Modal cancel resolves waitForClose with .userClosed and emits no event")
    func cancelResolvesUserClosed() async {
        let host = UIViewController()
        // Push host into a window so present() doesn't no-op against nil.
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = host
        win.makeKeyAndVisible()

        let shared = SharedWebViewConfiguration()
        let recorder = TestEventRecorder()
        let ctx = ExecutionContextImpl(
            host: host, shared: shared,
            currentRequestId: "REQ-42",
            eventEmitter: recorder
        )

        let handle = try? await ctx.presentModalWebView(
            url: URL(string: "https://login.coinbase.com/signin")!,
            dismissOnNavigateAwayFromHost: "login.coinbase.com",
            title: "Sign in"
        )
        let modal = handle as? ModalViewController
        #expect(modal != nil)

        let waiter = Task { @MainActor in await handle!.waitForClose() }
        modal?.testTriggerCancel()
        #expect(await waiter.value == .userClosed)
        // The reason now rides the auth.login response; no out-of-band event.
        #expect(recorder.events.isEmpty)
    }

    @Test("Navigation off host resolves waitForClose with .success")
    func navigationOffResolvesSuccess() async {
        let host = UIViewController()
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = host
        win.makeKeyAndVisible()

        let shared = SharedWebViewConfiguration()
        let recorder = TestEventRecorder()
        let ctx = ExecutionContextImpl(
            host: host, shared: shared,
            currentRequestId: "REQ-7",
            eventEmitter: recorder
        )

        let handle = try? await ctx.presentModalWebView(
            url: URL(string: "https://login.coinbase.com/signin")!,
            dismissOnNavigateAwayFromHost: "login.coinbase.com",
            title: nil
        )
        let modal = handle as? ModalViewController
        #expect(modal != nil)

        let waiter = Task { @MainActor in await handle!.waitForClose() }
        modal?.testTriggerNavigationOff(host: "www.coinbase.com")
        #expect(await waiter.value == .success)
        #expect(recorder.events.isEmpty)
    }

    @Test("runVisibleWebView throws hostUnavailable when host is nil")
    func visibleThrowsWhenHostNil() async {
        let shared = SharedWebViewConfiguration()
        let recorder = TestEventRecorder()
        // host is a local that deallocates immediately; the impl holds it
        // weakly, so by the time we call, `host` is nil.
        let ctx: ExecutionContextImpl = {
            let host = UIViewController()
            return ExecutionContextImpl(
                host: host, shared: shared,
                currentRequestId: "REQ-V0",
                eventEmitter: recorder
            )
        }()

        await #expect(throws: ContextError.hostUnavailable) {
            _ = try await ctx.runVisibleWebView(
                url: URL(string: "https://www.coinbase.com/")!,
                settle: { _ in .evaluate },
                injectedScript: "true",
                overlay: .default,
                showOverlay: true,
                waitForChallengeClearance: false,
                timeoutMs: 30_000
            )
        }
    }

    @Test("runVisibleWebView presents a full-screen AutomatedWebViewController")
    func visiblePresentsAutomatedVC() async {
        let host = UIViewController()
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = host
        win.makeKeyAndVisible()

        let shared = SharedWebViewConfiguration()
        let recorder = TestEventRecorder()
        let ctx = ExecutionContextImpl(
            host: host, shared: shared,
            currentRequestId: "REQ-V1",
            eventEmitter: recorder
        )

        // Kick off the call; it awaits a real load that never completes here,
        // so run it in a detached Task and inspect the presentation
        // synchronously. We never await the call's result.
        let runTask = Task { @MainActor in
            _ = try? await ctx.runVisibleWebView(
                url: URL(string: "https://www.coinbase.com/")!,
                settle: { _ in .evaluate },
                injectedScript: "true",
                overlay: .default,
                showOverlay: true,
                waitForChallengeClearance: false,
                timeoutMs: 30_000
            )
        }
        // Let the present() run.
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000)

        let presented = host.presentedViewController
        #expect(presented is AutomatedWebViewController)
        #expect(presented?.modalPresentationStyle == .fullScreen)

        runTask.cancel()
    }

    @Test("presentModalWebView(hostPolicy:) keeps modal open on IdP host, closes on success host")
    func policyOverloadDrivesDismiss() async throws {
        let host = UIViewController()
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = host
        win.makeKeyAndVisible()

        let shared = SharedWebViewConfiguration()
        let recorder = TestEventRecorder()
        let ctx = ExecutionContextImpl(
            host: host, shared: shared,
            currentRequestId: "REQ-POLICY",
            eventEmitter: recorder
        )

        let handle = try await ctx.presentModalWebView(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(
                stayOpenHosts: ["login.coinbase.com", "accounts.google.com"],
                successHosts: ["www.coinbase.com"]),
            title: "Sign in to Coinbase")
        let modal = handle as? ModalViewController
        modal?.loadViewIfNeeded()
        modal?.testTriggerNavigationOff(host: "accounts.google.com") // stay open
        modal?.testTriggerNavigationOff(host: "www.coinbase.com")    // close
        let reason = await handle.waitForClose()
        #expect(reason == .success)
    }
}
