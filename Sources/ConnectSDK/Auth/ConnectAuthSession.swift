//
//  ConnectAuthSession.swift
//  ConnectSDK
//
//  Manages auth session configuration and presentation
//

import UIKit

/// A configured auth session that can be presented when ready
@MainActor
public class ConnectAuthSession {

    // MARK: - Properties

    /// JWT token for authentication
    private let jwt: String

    /// Environment
    private let environment: Environment

    /// UI theme
    private let theme: Theme

    /// Callbacks for auth events
    private let callbacks: AuthCallbacks

    /// Whether the session has been presented
    private var isPresented: Bool = false

    /// The actual session once presented
    private var activeSession: ConnectSession?

    // MARK: - Initialization

    /// Creates a new auth session configuration
    internal init(jwt: String, environment: Environment, theme: Theme, callbacks: AuthCallbacks) {
        self.jwt = jwt
        self.environment = environment
        self.theme = theme
        self.callbacks = callbacks
    }

    // MARK: - Public Methods

    /// Presents the auth UI from the specified view controller
    /// - Parameter viewController: The view controller to present from
    /// - Returns: The active ConnectSession if presentation succeeds
    @discardableResult
    public func present(from viewController: UIViewController) -> ConnectSession? {
        guard !isPresented else {
            return activeSession
        }

        // Validate JWT has basic structure (header.payload.signature)
        guard !jwt.isEmpty else {
            print("ConnectSDK Error: JWT token is empty")
            return nil
        }

        // Create callback handler
        let callbackHandler = AuthCallbackHandler(callbacks: callbacks)

        // Create the web view controller
        let webVC = WebViewController(
            urlString: ConnectApp.auth.baseURL,
            jwt: jwt,
            environment: environment,
            theme: theme.rawValue,
            callbackHandler: callbackHandler
        )

        // Create navigation controller
        let nav = UINavigationController(rootViewController: webVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalPresentationCapturesStatusBarAppearance = true

        // Set navigation controller view background based on theme
        if theme.shouldUseDarkMode(in: nav.traitCollection) {
            nav.view.backgroundColor = Theme.darkBackgroundColor
        } else {
            nav.view.backgroundColor = .systemBackground
        }

        // Configure navigation bar appearance based on theme
        if let navigationBar = nav.navigationBar as UINavigationBar? {
            theme.configureNavigationBar(navigationBar, traitCollection: nav.traitCollection)
        }

        // Create session
        let session = ConnectSession(app: .auth, viewController: nav)

        // Store session reference in web view controller
        webVC.session = session

        // Store our reference
        activeSession = session
        isPresented = true

        // Present the view controller
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
