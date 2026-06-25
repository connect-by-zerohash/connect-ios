import Testing
import UIKit
import WebKit
@testable import ConnectSDK

@MainActor
@Suite("ModalViewController")
struct ModalViewControllerTests {

    @Test("Cancel button reports .userClosed exactly once")
    func cancelReportsUserClosed() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: "Sign in",
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerCancel()
        vc.testTriggerCancel()
        #expect(reasons == [.userClosed])
    }

    @Test("Auto-dismiss on navigation off host reports .success")
    func autoDismissReportsSuccess() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerNavigationOff(host: "www.coinbase.com")
        #expect(reasons == [.success])
    }

    @Test("First close reason wins; subsequent closes are ignored")
    func firstCloseWins() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerNavigationOff(host: "www.coinbase.com")
        vc.testTriggerCancel()
        #expect(reasons == [.success])
    }

    @Test("Timeout reports .timeout exactly once")
    func timeoutReportsTimeout() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerTimeout()
        vc.testTriggerTimeout()
        #expect(reasons == [.timeout])
    }

    @Test("A close before timeout wins; later timeout is ignored")
    func closeBeforeTimeoutWins() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerCancel()
        vc.testTriggerTimeout()
        #expect(reasons == [.userClosed])
    }

    @Test("Auto-close probe match reports .conditionMet exactly once")
    func conditionMetReportsConditionMet() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerConditionMet()
        vc.testTriggerConditionMet()
        #expect(reasons == [.conditionMet])
    }

    @Test("A close before the probe match wins; later .conditionMet is ignored")
    func closeBeforeConditionMetWins() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerNavigationOff(host: "www.coinbase.com")
        vc.testTriggerConditionMet()
        #expect(reasons == [.success])
    }

    @Test("currentURL reflects the underlying WKWebView")
    func currentURLDelegates() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let url = URL(string: "https://login.coinbase.com/signin")!
        let vc = ModalViewController(
            url: url, hostPolicy: ModalHostPolicy(legacyDismissAwayFromHost: "login.coinbase.com"),
            title: nil, sharedConfig: cfg
        )
        // Before viewDidLoad, the webView is nil and currentURL is nil.
        #expect(vc.currentURL == nil)
        vc.loadViewIfNeeded()
        // After load() is dispatched, WKWebView.url reflects the requested URL.
        #expect(vc.currentURL == url)
    }

    @Test("documentStartJS installs a documentStart user script on the config")
    func documentStartJSInstallsUserScript() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let js = "/* hide social */ void 0;"
        _ = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(stayOpenHosts: ["login.coinbase.com"],
                                        successHosts: ["www.coinbase.com"]),
            title: nil,
            sharedConfig: cfg,
            documentStartJS: js
        )
        let scripts = cfg.userContentController.userScripts
        #expect(scripts.contains { $0.source == js && $0.injectionTime == .atDocumentStart })
    }

    @Test("IdP host keeps the modal open (no premature dismiss)")
    func idpHostStaysOpen() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(
                stayOpenHosts: ["login.coinbase.com", "accounts.google.com", "appleid.apple.com"],
                successHosts: ["www.coinbase.com"]),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerNavigationOff(host: "accounts.google.com")
        vc.testTriggerNavigationOff(host: "appleid.apple.com")
        #expect(reasons.isEmpty)
    }

    @Test("success host closes .success under a policy")
    func successHostClosesUnderPolicy() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(
                stayOpenHosts: ["login.coinbase.com", "accounts.google.com"],
                successHosts: ["www.coinbase.com"]),
            title: nil,
            sharedConfig: cfg
        )
        vc.loadViewIfNeeded()

        var reasons: [ModalCloseReason] = []
        vc.onClose = { reasons.append($0) }
        vc.testTriggerNavigationOff(host: "accounts.google.com") // stays open
        vc.testTriggerNavigationOff(host: "www.coinbase.com")    // closes
        #expect(reasons == [.success])
    }

    @Test("opening a popup is tracked, and closing it clears the reference")
    func popupLifecycle() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let vc = ModalViewController(
            url: URL(string: "https://login.coinbase.com/signin")!,
            hostPolicy: ModalHostPolicy(stayOpenHosts: ["login.coinbase.com"],
                                        successHosts: ["www.coinbase.com"]),
            title: "Sign in to Coinbase", sharedConfig: cfg)
        vc.loadViewIfNeeded()
        let popup = vc.testTriggerOpenPopup(title: "Continue with Google")
        #expect(vc.debugHasLivePopup == true)
        popup.loadViewIfNeeded()
        popup.webViewDidClose(WKWebView(frame: .zero, configuration: WKWebViewConfiguration()))
        #expect(vc.debugHasLivePopup == false)
    }
}
