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

    // MARK: - Public Methods

    func handleExternalNavigation(url: String, from viewController: UIViewController, isOauth: Bool) {
        if isOauth {
            handleOAuthFlow(url: url, from: viewController)
        } else {
            openInExternalBrowser(url: url)
        }
    }
    
    private func openInExternalBrowser(url: String) {
        guard let url = URL(string: url) else {
            print("Invalid URL: \(url)")
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            print("Cannot open URL: \(url)")
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
            callbackURLPrefix: nil,
            from: viewController
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let parameters):
                if let connectionId = parameters["connectionId"] as? String {
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
