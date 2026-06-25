import Testing
import UIKit
import WebKit
@testable import ConnectSDK

@MainActor
@Suite("PopupWebViewController")
struct PopupWebViewControllerTests {

    @Test("webViewDidClose invokes onClose exactly once")
    func closeOnce() {
        let cfg = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: cfg)
        let vc = PopupWebViewController(webView: web, title: "Sign in")
        vc.loadViewIfNeeded()
        var closes = 0
        vc.onClose = { closes += 1 }
        vc.webViewDidClose(web)
        vc.webViewDidClose(web)
        #expect(closes == 1)
    }

    @Test("Cancel reports close")
    func cancelCloses() {
        let cfg = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: cfg)
        let vc = PopupWebViewController(webView: web, title: nil)
        vc.loadViewIfNeeded()
        var closes = 0
        vc.onClose = { closes += 1 }
        vc.testTriggerCancel()
        #expect(closes == 1)
    }

    @Test("disallowed_useragent URL triggers onIdPRejection")
    func detectsRejection() {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let vc = PopupWebViewController(webView: web, title: nil)
        vc.loadViewIfNeeded()
        var rejected: URL?
        vc.onIdPRejection = { rejected = $0 }
        let url = URL(string: "https://accounts.google.com/signin/rejected?error=disallowed_useragent")!
        vc.testTriggerNavigation(to: url)
        #expect(rejected?.absoluteString.contains("disallowed_useragent") == true)
    }

    @Test("normal IdP URL does not trigger rejection")
    func noFalsePositive() {
        let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let vc = PopupWebViewController(webView: web, title: nil)
        vc.loadViewIfNeeded()
        var rejected: URL?
        vc.onIdPRejection = { rejected = $0 }
        vc.testTriggerNavigation(to: URL(string: "https://accounts.google.com/o/oauth2/v2/auth?client_id=x")!)
        #expect(rejected == nil)
    }
}
