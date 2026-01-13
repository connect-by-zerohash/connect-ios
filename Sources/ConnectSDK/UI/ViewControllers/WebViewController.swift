//
//  WebViewController.swift
//  ConnectSDK
//
//  Created by Michael Sampietro on 14/08/25.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate,
    WKUIDelegate, WebViewLoadingManagerDelegate, WebViewMessageHandlerDelegate, WebViewOAuthManagerDelegate
{

    private var webView: WKWebView!
    private var urlString: String
    private var jwt: String
    internal var environment: Environment  // Made internal so you can access it for posting messages
    private var theme: String
    private var themeEnum: Theme
    private var isInitialLoad = true

    // Managers
    private var loadingManager: WebViewLoadingManager!
    private var messageHandler: WebViewMessageHandler!
    private var oauthManager: WebViewOAuthManager!

    // Properties for typed callbacks
    internal var callbackHandler: CallbackHandler
    internal weak var session: ConnectSession?

    // Initializer with callback handler
    init(urlString: String, jwt: String, environment: Environment, theme: String, callbackHandler: CallbackHandler) {
        self.urlString = urlString
        self.jwt = jwt
        self.environment = environment
        self.theme = theme
        self.themeEnum = Theme(rawValue: theme) ?? .system
        self.callbackHandler = callbackHandler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure view controller to extend behind status bar and home indicator
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = .all

        // Set view background based on theme - this will show in safe areas
        if themeEnum.shouldUseDarkMode(in: traitCollection) {
            view.backgroundColor = Theme.darkBackgroundColor
            // Also set the navigation controller's view background
            navigationController?.view.backgroundColor = Theme.darkBackgroundColor
        } else {
            view.backgroundColor = .systemBackground
            navigationController?.view.backgroundColor = .systemBackground
        }

        setupWebView()        // WebView starts hidden
        setupLoadingManager() // Setup loading manager
        setupOAuthManager()   // Setup OAuth manager
        loadWebsite()         // Begin loading

        // Hide navigation bar for the main WebViewController
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Hide navigation bar when returning to this view
        navigationController?.setNavigationBarHidden(true, animated: animated)

        // Configure navigation bar appearance
        if let navigationBar = navigationController?.navigationBar {
            themeEnum.configureNavigationBar(navigationBar, traitCollection: traitCollection)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Mark session as inactive when view is dismissed
        if isBeingDismissed || isMovingFromParent {
            session?.isActive = false
        }
    }

    // MARK: - Theme Configuration

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if themeEnum == .system && traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            let isDark = themeEnum.shouldUseDarkMode(in: traitCollection)

            // Update colors when system theme changes
            if isDark {
                view.backgroundColor = Theme.darkBackgroundColor
                navigationController?.view.backgroundColor = Theme.darkBackgroundColor
                webView?.backgroundColor = Theme.darkBackgroundColor
                webView?.scrollView.backgroundColor = Theme.darkBackgroundColor
            } else {
                view.backgroundColor = .systemBackground
                navigationController?.view.backgroundColor = .systemBackground
                webView?.backgroundColor = .systemBackground
                webView?.scrollView.backgroundColor = .systemBackground
            }

            // Update loading view theme if still visible
            loadingManager?.updateTheme(for: traitCollection)

            // Update navigation bar if visible
            if let navigationBar = navigationController?.navigationBar {
                themeEnum.configureNavigationBar(navigationBar, traitCollection: traitCollection)
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if themeEnum.shouldUseDarkMode(in: traitCollection) {
            return .lightContent  // White status bar for dark mode
        } else {
            return .default  // Black status bar for light mode
        }
    }

    // MARK: - WebView Delegate Methods

    func webView(
        _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // After initial load, cancel all navigations
        // Navigation should happen through message handlers only
        decisionHandler(.cancel)
    }


    private func setupWebView() {
        let contentController = WKUserContentController()

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = self
        webView.navigationDelegate = self

        // Setup message handler
        messageHandler = WebViewMessageHandler(webView: webView, jwt: jwt, theme: theme, environment: environment)
        messageHandler.delegate = self
        messageHandler.setupMessageHandlers()

        // Set WebView background to match theme
        webView.isOpaque = false
        if themeEnum.shouldUseDarkMode(in: traitCollection) {
            webView.backgroundColor = Theme.darkBackgroundColor
            webView.scrollView.backgroundColor = Theme.darkBackgroundColor
        } else {
            webView.backgroundColor = .systemBackground
            webView.scrollView.backgroundColor = .systemBackground
        }

        // Initially hide WebView until page is ready
        webView.alpha = 0.0
        webView.isUserInteractionEnabled = false

        navigationItem.titleView?.backgroundColor = UIColor.clear
        navigationItem.title = ""
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupLoadingManager() {
        loadingManager = WebViewLoadingManager(parentView: view, theme: themeEnum)
        loadingManager.delegate = self
        loadingManager.setupLoadingView(in: traitCollection)
    }

    private func setupOAuthManager() {
        oauthManager = WebViewOAuthManager()
        oauthManager.delegate = self
    }


    private func loadWebsite() {
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    private func transitionToWebView() {
        loadingManager.transitionToWebView(webView: webView)
    }

    func handleExternalNavigation(url: String, isOauth: Bool) {
        oauthManager.handleExternalNavigation(url: url, from: self, isOauth: isOauth)
    }

    // MARK: - WebViewMessageHandlerDelegate

    func messageHandlerDidReceivePageReady(_ handler: WebViewMessageHandler) {
        // Page ready is handled internally by the message handler
    }

    func messageHandlerDidReceiveContentReady(_ handler: WebViewMessageHandler) {
        transitionToWebView()
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveNavigate url: String, mobileTarget: String?) {
        // Determine navigation behavior based on mobileTarget
        if mobileTarget == "in_app" {
            // Open in SubViewController (in-app browser)
            // Show navigation bar before pushing the new view controller.
            // This allows back button to be visible and web page title.
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            let newWebViewController = SubViewController(urlString: url, theme: themeEnum)
            self.navigationController?.pushViewController(newWebViewController, animated: true)
        } else if mobileTarget == "oauth" {
            // Open in external browser for any other value or if not specified
            self.handleExternalNavigation(url: url, isOauth: true)
        } else {
            self.handleExternalNavigation(url: url, isOauth: false)
        }
    }

    func messageHandlerDidReceiveClose(_ handler: WebViewMessageHandler) {
        callbackHandler.handleClose()
        dismiss(animated: true)
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveError data: [String: Any], jsonString: String) {
        if let handler = callbackHandler as? AuthCallbackHandler {
            handler.handleErrorEvent(data, jsonString: jsonString)
        }
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveEvent data: [String: Any], jsonString: String) {
        if let handler = callbackHandler as? AuthCallbackHandler {
            handler.handleGenericEvent(data, jsonString: jsonString)
        }
    }

    func messageHandler(_ handler: WebViewMessageHandler, didReceiveDeposit data: [String: Any], jsonString: String) {
        if let handler = callbackHandler as? AuthCallbackHandler {
            handler.handleDepositEvent(data, jsonString: jsonString)
        }
    }

    // MARK: - WebViewLoadingManagerDelegate

    func loadingManagerDidRequestRetry(_ manager: WebViewLoadingManager) {
        manager.resetForRetry()
        loadWebsite()
    }

    func loadingManagerDidRequestClose(_ manager: WebViewLoadingManager) {
        // Close the WebView
        callbackHandler.handleClose()
        dismiss(animated: true)
    }

    // MARK: - WebViewOAuthManagerDelegate

    func oauthManager(_ manager: WebViewOAuthManager, didCompleteWithConnectionId connectionId: String) {
        messageHandler.sendOAuthResult(success: true, connectionId: connectionId)
    }

    func oauthManager(_ manager: WebViewOAuthManager, didFailWithError error: String) {
        messageHandler.sendOAuthResult(success: false, error: error)
    }
}
