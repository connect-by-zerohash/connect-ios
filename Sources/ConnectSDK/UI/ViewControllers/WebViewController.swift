//
//  WebViewController.swift
//  ConnectSDK
//
//  Created by Michael Sampietro on 14/08/25.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKNavigationDelegate,
    WKUIDelegate, WebViewLoadingManagerDelegate, UIWebViewMessageRouterDelegate, WebViewOAuthManagerDelegate
{

    private var webView: WKWebView!
    private var urlString: String
    private var jwt: String
    internal var environment: Environment  // Made internal so you can access it for posting messages
    private var theme: String
    private var themeEnum: Theme
    private var isInitialLoad = true
    private let allowList: ConnectAllowList
    private let oauthCallback: ConnectOAuthCallback

    // Managers
    private var loadingManager: WebViewLoadingManager!
    private var oauthManager: WebViewOAuthManager!

    // Unified bridge wiring
    private lazy var sharedConfig = SharedWebViewConfiguration()
    private var nativeIOSHandler: NativeIOSMessageHandler!
    private var uiWebViewRouter: UIWebViewMessageRouter!
    private var automationWebViewRouter: AutomationWebViewMessageRouter!
    private var replySink: PostMessageReplySink!

    // Properties for typed callbacks
    internal var callbackHandler: CallbackHandler
    internal weak var session: ConnectSession?

    // Initializer with callback handler
    init(urlString: String, jwt: String, environment: Environment, theme: String, callbackHandler: CallbackHandler, allowList: ConnectAllowList = .default, oauthCallback: ConnectOAuthCallback = .default) {
        self.urlString = urlString
        self.jwt = jwt
        self.environment = environment
        self.theme = theme
        self.themeEnum = Theme(rawValue: theme) ?? .system
        self.callbackHandler = callbackHandler
        self.allowList = allowList
        self.oauthCallback = oauthCallback
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
        let config = WKWebViewConfiguration()
        config.processPool = sharedConfig.processPool
        // Use the shared persistent data store (not `.nonPersistent()`) so the
        // Coinbase login session/cookies are reused across the offscreen
        // `auth.status` runner and the modal login flow.
        config.websiteDataStore = sharedConfig.dataStore
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = self
        webView.navigationDelegate = self

        // Build the unified bridge.
        let originHost = URL(string: urlString)?.host ?? "sdk.connect.xyz"
        let allowed: Set<String> = [originHost]

        replySink = PostMessageReplySink(webView: webView)

        let initialJWT = self.jwt
        let initialEnv = self.environment
        let initialTheme = self.theme

        uiWebViewRouter = UIWebViewMessageRouter(
            initialMessages: { [
                ("jwt",    ["token": initialJWT, "env": initialEnv.rawValue]),
                ("config", ["theme": initialTheme]),
            ] },
            send: { [weak self] msg in
                // `msg` is `[String: Any]` shaped `{type, data}`. Forward to the sink
                // by extracting the canonical fields.
                guard let self = self,
                      let type = msg["type"] as? String,
                      let data = msg["data"] as? [String: Any] else { return }
                self.replySink.sendUIWebViewMessage(type: type, data: data)
            }
        )
        uiWebViewRouter.delegate = self

        automationWebViewRouter = AutomationWebViewMessageRouter(
            registry: PlatformRegistry.shared,
            sink: replySink,
            executionContextFactory: { [weak self] requestId in
                guard let self = self else {
                    fatalError("ExecutionContext factory invoked without owning controller")
                }
                return ExecutionContextImpl(
                    host: self,
                    shared: self.sharedConfig,
                    currentRequestId: requestId,
                    eventEmitter: self.automationWebViewRouter
                )
            }
        )

        nativeIOSHandler = NativeIOSMessageHandler(
            uiWebView: uiWebViewRouter,
            automationWebView: automationWebViewRouter,
            allowedOrigins: allowed
        )

        // Register exactly one message-handler channel on the live config.
        webView.configuration.userContentController.add(nativeIOSHandler, name: "NativeIOS")

        // WebView styling (unchanged from previous implementation).
        webView.isOpaque = false

        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif

        if themeEnum.shouldUseDarkMode(in: traitCollection) {
            webView.backgroundColor = Theme.darkBackgroundColor
            webView.scrollView.backgroundColor = Theme.darkBackgroundColor
        } else {
            webView.backgroundColor = .systemBackground
            webView.scrollView.backgroundColor = .systemBackground
        }
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
        oauthManager = WebViewOAuthManager(callback: oauthCallback)
        oauthManager.delegate = self
    }


    private func loadWebsite() {
        guard let url = URL(string: urlString) else { return }
        // For `.localDev`, the LAN dev-server host is not part of the default
        // allow-list. Add it so the ContentRuleList does not block the local
        // shell. Sandbox/production keep the integrator-supplied allow-list.
        let effectiveAllowList: ConnectAllowList = {
            if case .localDev(let devURL) = environment, let host = devURL.host {
                return ConnectAllowList(hosts: allowList.hosts + [host])
            }
            return allowList
        }()
        ContentRuleList.compile(for: effectiveAllowList) { [weak self] ruleList in
            guard let self = self else { return }
            if let ruleList = ruleList {
                self.webView.configuration.userContentController.add(ruleList)
            }
            self.webView.load(URLRequest(url: url))
        }
    }

    private func transitionToWebView() {
        loadingManager.transitionToWebView(webView: webView)
    }

    func handleExternalNavigation(url: String, isOauth: Bool) {
        oauthManager.handleExternalNavigation(url: url, from: self, isOauth: isOauth)
    }

    // MARK: - UIWebViewMessageRouterDelegate

    func uiWebViewRouterDidReceiveContentReady(_ router: UIWebViewMessageRouter) {
        transitionToWebView()
    }

    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveNavigate url: String, mobileTarget: String?) {
        if mobileTarget == "in_app" {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            let newWebViewController = SubViewController(urlString: url, theme: themeEnum, allowList: allowList)
            self.navigationController?.pushViewController(newWebViewController, animated: true)
        } else if mobileTarget == "oauth" {
            self.handleExternalNavigation(url: url, isOauth: true)
        } else {
            self.handleExternalNavigation(url: url, isOauth: false)
        }
    }

    func uiWebViewRouterDidReceiveClose(_ router: UIWebViewMessageRouter) {
        callbackHandler.handleClose()
        dismiss(animated: true)
    }

    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveError data: [String: Any], jsonString: String) {
        if let handler = callbackHandler as? AuthCallbackHandler {
            handler.handleErrorEvent(data, jsonString: jsonString)
        }
    }

    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveEvent data: [String: Any], jsonString: String) {
        if let handler = callbackHandler as? AuthCallbackHandler {
            handler.handleGenericEvent(data, jsonString: jsonString)
        }
    }

    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveDeposit data: [String: Any], jsonString: String) {
        if let handler = callbackHandler as? AuthCallbackHandler {
            handler.handleDepositEvent(data, jsonString: jsonString)
        }
    }

    func uiWebViewRouter(_ router: UIWebViewMessageRouter, didReceiveWithdrawal data: [String: Any], jsonString: String) {
        callbackHandler.handleWithdrawalEvent(data, jsonString: jsonString)
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
        replySink.sendOAuthResult(success: true, connectionId: connectionId)
    }

    func oauthManager(_ manager: WebViewOAuthManager, didFailWithError error: String) {
        replySink.sendOAuthResult(success: false, error: error)
    }
}
