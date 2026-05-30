//
//  ConnectWithdrawalSession.swift
//  ConnectSDK
//
//  Manages withdrawal session configuration and presentation
//

import UIKit

/// A configured withdrawal session that can be presented when ready
@MainActor
public class ConnectWithdrawalSession {

    // MARK: - Properties

    private let jwt: String
    private let environment: Environment
    private let theme: Theme
    private let callbacks: WithdrawalCallbacks
    private let allowList: ConnectAllowList
    private let oauthCallback: ConnectOAuthCallback
    private var isPresented: Bool = false
    private var activeSession: ConnectSession?

    // MARK: - Initialization

    internal init(jwt: String, environment: Environment, theme: Theme, callbacks: WithdrawalCallbacks, allowList: ConnectAllowList = .default, oauthCallback: ConnectOAuthCallback = .default) {
        self.jwt = jwt
        self.environment = environment
        self.theme = theme
        self.callbacks = callbacks
        self.allowList = allowList
        self.oauthCallback = oauthCallback
    }

    // MARK: - Public Methods

    /// Presents the withdrawal UI from the specified view controller
    /// - Parameter viewController: The view controller to present from
    /// - Returns: The active ConnectSession if presentation succeeds
    @discardableResult
    public func present(from viewController: UIViewController) -> ConnectSession? {
        guard !isPresented else {
            return activeSession
        }

        guard !jwt.isEmpty else {
            Log.error("JWT token is empty")
            return nil
        }

        let callbackHandler = WithdrawalCallbackHandler(callbacks: callbacks)

        let webVC = WebViewController(
            urlString: ConnectApp.withdrawal.baseURL(for: environment),
            jwt: jwt,
            environment: environment,
            theme: theme.rawValue,
            callbackHandler: callbackHandler,
            allowList: allowList,
            oauthCallback: oauthCallback
        )

        let nav = UINavigationController(rootViewController: webVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalPresentationCapturesStatusBarAppearance = true

        if theme.shouldUseDarkMode(in: nav.traitCollection) {
            nav.view.backgroundColor = Theme.darkBackgroundColor
        } else {
            nav.view.backgroundColor = .systemBackground
        }

        if let navigationBar = nav.navigationBar as UINavigationBar? {
            theme.configureNavigationBar(navigationBar, traitCollection: nav.traitCollection)
        }

        let session = ConnectSession(app: .withdrawal, viewController: nav)
        webVC.session = session
        activeSession = session
        isPresented = true

        viewController.present(nav, animated: true)

        return session
    }

    /// Cancels the session if it's active
    public func cancel() {
        activeSession?.cancel()
        activeSession = nil
        isPresented = false
    }

    // MARK: - Computed Properties

    /// Whether this session is currently active
    public var isActive: Bool {
        return activeSession?.isActive ?? false
    }
}
