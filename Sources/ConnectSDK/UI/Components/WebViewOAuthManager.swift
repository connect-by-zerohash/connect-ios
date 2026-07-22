//
//  WebViewOAuthManager.swift
//  ConnectSDK
//
//  Manages OAuth flows and external browser navigation for WebViewController
//

import UIKit

@MainActor
protocol WebViewOAuthManagerDelegate: AnyObject {
    func oauthManager(_ manager: WebViewOAuthManager, didCompleteWithConnectionId connectionId: String)
    func oauthManager(_ manager: WebViewOAuthManager, didFailWithError error: String)
}

@MainActor
class WebViewOAuthManager {

    // MARK: - Properties

    weak var delegate: WebViewOAuthManagerDelegate?
    private var oauthHandler: OAuthHandler?
    private let callback: ConnectOAuthCallback

    // MARK: - Initialization

    init(callback: ConnectOAuthCallback = .default) {
        self.callback = callback
    }

    // MARK: - Public Methods

    func handleExternalNavigation(url: String, from viewController: UIViewController, isOauth: Bool) {
        guard let validated = Self.validatedHTTPSURL(url) else {
            let host = URL(string: url)?.host ?? "?"
            Log.bridge.error("rejected external navigation: non-https or invalid URL host=\(host, privacy: .private) isOauth=\(isOauth)")
            return
        }
        if isOauth {
            handleOAuthFlow(url: validated.absoluteString, from: viewController)
        } else {
            openInExternalBrowser(url: validated)
        }
    }

    /// The web app can request `navigate` with an arbitrary URL. We restrict
    /// externally opened URLs and OAuth authorization URLs to `https` so
    /// non-web schemes (`tel:`, custom deep links, `data:`, `javascript:`, …)
    /// and cleartext `http:` cannot ride the trusted-origin `navigate` channel
    /// out to `UIApplication.open` or `ASWebAuthenticationSession`. Host
    /// allow-listing is not applied here because OAuth authorize hosts and
    /// external destinations are third-party by design.
    static func validatedHTTPSURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false
        else { return nil }
        return url
    }

    private func openInExternalBrowser(url: URL) {
        guard UIApplication.shared.canOpenURL(url) else {
            Log.bridge.error("cannot open URL host=\(url.host ?? "?", privacy: .private)")
            return
        }

        // Open in external browser (Safari)
        UIApplication.shared.open(url, options: [:])
    }

    private func handleOAuthFlow(url: String, from viewController: UIViewController) {
        if oauthHandler == nil {
            oauthHandler = OAuthHandler()
        }

        oauthHandler?.authenticate(
            url: url,
            callback: callback,
            from: viewController
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let parameters):
                if let connectionId = parameters["connectionId"] {
                    self.delegate?.oauthManager(self, didCompleteWithConnectionId: connectionId)
                } else {
                    self.delegate?.oauthManager(self, didFailWithError: "Error processing the data.")
                }
            case .failure(let error):
                self.delegate?.oauthManager(self, didFailWithError: error.localizedDescription)
            }
        }
    }
}
