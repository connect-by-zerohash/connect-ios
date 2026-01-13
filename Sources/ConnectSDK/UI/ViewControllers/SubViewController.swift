//
//  SubViewController.swift
//  ConnectSDK
//
//  Created by Michael Sampietro on 14/08/25.
//

import UIKit
import WebKit

class SubViewController: UIViewController, WKNavigationDelegate {

    // MARK: - Properties

    private var webView: WKWebView!
    private let urlString: String
    private let theme: Theme
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Initialization

    init(urlString: String, theme: Theme = .system) {
        self.urlString = urlString
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Loading..."

        // Set background based on theme
        if theme.shouldUseDarkMode(in: traitCollection) {
            view.backgroundColor = Theme.darkBackgroundColor
        } else {
            view.backgroundColor = .systemBackground
        }

        setupWebView()
        setupActivityIndicator()
        loadWebsite()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure navigation bar is visible in SubViewController
        navigationController?.setNavigationBarHidden(false, animated: animated)

        // Configure navigation bar appearance
        if let navigationBar = navigationController?.navigationBar {
            theme.configureNavigationBar(navigationBar, traitCollection: traitCollection)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()

        // Update navigation bar title with the page title
        if let pageTitle = webView.title, !pageTitle.isEmpty {
            self.title = pageTitle
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        // Optionally, show an error alert to the user
    }

    // MARK: - Theme Configuration

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if theme == .system && traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            // Update colors when system theme changes
            if theme.shouldUseDarkMode(in: traitCollection) {
                view.backgroundColor = Theme.darkBackgroundColor
            } else {
                view.backgroundColor = .systemBackground
            }

            // Update navigation bar
            if let navigationBar = navigationController?.navigationBar {
                theme.configureNavigationBar(navigationBar, traitCollection: traitCollection)
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if theme.shouldUseDarkMode(in: traitCollection) {
            return .lightContent  // White status bar for dark mode
        } else {
            return .default  // Black status bar for light mode
        }
    }

    // MARK: - Private Methods

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)

        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.center = view.center
    }

    private func loadWebsite() {
        guard let url = URL(string: urlString) else {
            return
        }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
