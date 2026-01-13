//
//  WebViewLoadingManager.swift
//  ConnectSDK
//
//  Manages the loading view and animations for WebViewController
//

import UIKit
import WebKit

@MainActor
protocol WebViewLoadingManagerDelegate: AnyObject {
    func loadingManagerDidRequestRetry(_ manager: WebViewLoadingManager)
    func loadingManagerDidRequestClose(_ manager: WebViewLoadingManager)
}

@MainActor
class WebViewLoadingManager {

    // MARK: - Properties

    weak var delegate: WebViewLoadingManagerDelegate?

    private weak var parentView: UIView?
    private var loadingContainerView: UIView!
    private var loadingLabel: UILabel!
    private var dotsContainer: UIView!
    private var dots: [UIView] = []
    private var closeButton: UIButton!
    private let theme: Theme
    private var animationTimer: Timer?

    // MARK: - Initialization

    init(parentView: UIView, theme: Theme) {
        self.parentView = parentView
        self.theme = theme
    }

    // MARK: - Public Methods

    func setupLoadingView(in traitCollection: UITraitCollection) {
        guard let parentView = parentView else { return }

        // Create container for loading view
        loadingContainerView = UIView()
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false

        // Set background based on theme
        if theme.shouldUseDarkMode(in: traitCollection) {
            loadingContainerView.backgroundColor = Theme.darkBackgroundColor
        } else {
            loadingContainerView.backgroundColor = .systemBackground
        }

        // Create dots container
        dotsContainer = UIView()
        dotsContainer.translatesAutoresizingMaskIntoConstraints = false

        // Create three dots with different colors for visualization
        let dotSize = Constants.LoadingAnimation.dotSize
        let dotColors = [
            UIColor(red: 252.0/255.0, green: 252.0/255.0, blue: 153.0/255.0, alpha: 1.0),  // Dot 1 - #FCFC99
            UIColor(red: 242.0/255.0, green: 240.0/255.0, blue: 125.0/255.0, alpha: 1.0),  // Dot 2 - #F2F07D
            UIColor(red: 240.0/255.0, green: 213.0/255.0, blue: 62.0/255.0, alpha: 1.0)    // Dot 3 - #F0D53E
        ]

        for i in 0..<3 {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = dotColors[i]
            dot.layer.cornerRadius = dotSize / 2
            dot.alpha = i == 0 ? 1.0 : 0.0  // Only first dot visible initially
            dots.append(dot)
            dotsContainer.addSubview(dot)

            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: dotSize),
                dot.heightAnchor.constraint(equalToConstant: dotSize),
                dot.centerYAnchor.constraint(equalTo: dotsContainer.centerYAnchor),
                dot.centerXAnchor.constraint(equalTo: dotsContainer.centerXAnchor) // All start at center
            ])
        }

        // Create loading label
        loadingLabel = UILabel()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = ""
        loadingLabel.textColor = theme.shouldUseDarkMode(in: traitCollection) ? .white : .label
        loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textAlignment = .center

        // Create close button
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = theme.shouldUseDarkMode(in: traitCollection) ? .white : .label
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // Add subviews
        parentView.addSubview(loadingContainerView)
        loadingContainerView.addSubview(dotsContainer)
        loadingContainerView.addSubview(loadingLabel)
        loadingContainerView.addSubview(closeButton)

        // Set constraints
        NSLayoutConstraint.activate([
            // Container fills entire view
            loadingContainerView.topAnchor.constraint(equalTo: parentView.topAnchor),
            loadingContainerView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            loadingContainerView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            loadingContainerView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),

            // Dots container centered
            dotsContainer.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            dotsContainer.centerYAnchor.constraint(equalTo: loadingContainerView.centerYAnchor, constant: -20),
            dotsContainer.widthAnchor.constraint(equalToConstant: dotSize * 3 + Constants.LoadingAnimation.dotSpacing * 2),
            dotsContainer.heightAnchor.constraint(equalToConstant: dotSize + 20), // Extra height for animation

            // Label below dots
            loadingLabel.topAnchor.constraint(equalTo: dotsContainer.bottomAnchor, constant: Constants.Layout.loadingLabelTopSpacing),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: loadingContainerView.leadingAnchor, constant: Constants.Layout.labelHorizontalPadding),
            loadingLabel.trailingAnchor.constraint(lessThanOrEqualTo: loadingContainerView.trailingAnchor, constant: -Constants.Layout.labelHorizontalPadding),

            // Close button in top-right corner
            closeButton.topAnchor.constraint(equalTo: loadingContainerView.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: loadingContainerView.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Start three-step animation
        startThreeStepAnimation()
    }

    func transitionToWebView(webView: WKWebView, completion: (() -> Void)? = nil) {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Only transition once
            guard self.loadingContainerView?.superview != nil else { return }

            // Animate the transition
            UIView.animate(
                withDuration: Constants.Layout.webViewTransitionDuration,
                delay: Constants.Layout.webViewTransitionDelay,
                options: [.curveEaseInOut],
                animations: {
                    // Fade out loading view
                    self.loadingContainerView.alpha = 0.0
                    // Fade in WebView
                    webView.alpha = 1.0
                },
                completion: { _ in
                    // Clean up
                    self.stopThreeStepAnimation()
                    self.loadingContainerView.removeFromSuperview()
                    webView.isUserInteractionEnabled = true
                    completion?()
                }
            )
        }
    }

    func showError(in traitCollection: UITraitCollection) {
        // Update loading view to show error
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Only show error if still loading
            guard self.loadingContainerView?.superview != nil else { return }

            self.stopThreeStepAnimation()
            self.loadingLabel.text = "Failed to load"

            // Add retry button
            let retryButton = UIButton(type: .system)
            retryButton.translatesAutoresizingMaskIntoConstraints = false
            retryButton.setTitle("Retry", for: .normal)
            retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            retryButton.addTarget(self, action: #selector(self.retryTapped), for: .touchUpInside)

            // Set button color based on theme
            retryButton.tintColor = self.theme.shouldUseDarkMode(in: traitCollection) ? .white : .systemBlue

            self.loadingContainerView.addSubview(retryButton)

            NSLayoutConstraint.activate([
                retryButton.topAnchor.constraint(equalTo: self.loadingLabel.bottomAnchor, constant: Constants.Layout.retryButtonTopSpacing),
                retryButton.centerXAnchor.constraint(equalTo: self.loadingContainerView.centerXAnchor)
            ])
        }
    }

    func resetForRetry() {
        // Reset loading view
        loadingLabel.text = ""

        // Reset dots to initial state
        for (index, dot) in dots.enumerated() {
            dot.alpha = index == 0 ? 1.0 : 0.0
            dot.transform = .identity
        }

        startThreeStepAnimation()

        // Remove retry button
        loadingContainerView.subviews.forEach { view in
            if view is UIButton {
                view.removeFromSuperview()
            }
        }
    }

    func updateTheme(for traitCollection: UITraitCollection) {
        guard loadingContainerView?.superview != nil else { return }

        let isDark = theme.shouldUseDarkMode(in: traitCollection)
        loadingContainerView?.backgroundColor = isDark ? Theme.darkBackgroundColor : .systemBackground

        // Keep dots with their specific yellow gradient colors
        // Don't change dot colors as they are part of the animation design

        loadingLabel?.textColor = isDark ? .white : .label

        // Update close button color
        closeButton?.tintColor = isDark ? .white : .label

        // Update retry button color if visible
        for subview in loadingContainerView?.subviews ?? [] {
            if let button = subview as? UIButton, button != closeButton {
                button.tintColor = isDark ? .white : .systemBlue
            }
        }
    }

    // MARK: - Private Methods

    private func startThreeStepAnimation() {
        // Start the animation sequence
        animateStep1()
    }

    private func animateStep1() {
        // Step 1: Move first dot to left
        guard dots.count >= 1 else { return }

        let firstDot = dots[0]
        let dotSpacing = Constants.LoadingAnimation.dotSpacing

        UIView.animate(withDuration: 0.4, delay: 0.3, options: [.curveEaseInOut], animations: {
            firstDot.transform = CGAffineTransform(translationX: -(dotSpacing * 1.5), y: 0)
        }) { _ in
            self.animateStep2()
        }
    }

    private func animateStep2() {
        // Step 2: Fade in the other two dots sequentially over 600ms
        guard dots.count >= 3 else { return }

        let dotSpacing = Constants.LoadingAnimation.dotSpacing

        // Position dots
        dots[1].transform = CGAffineTransform(translationX: 0, y: 0)
        dots[2].transform = CGAffineTransform(translationX: dotSpacing * 1.5, y: 0)

        // Fade in second dot first
        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut], animations: {
            self.dots[1].alpha = 1.0
        }) { _ in
            // Then fade in third dot after 300ms
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut], animations: {
                self.dots[2].alpha = 1.0
            }) { _ in
                // Wait 300ms after all dots are visible before grouping
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.animateStep3()
                }
            }
        }
    }

    private func animateStep3() {
        // Step 3: Group all dots back to center
        guard dots.count >= 3 else { return }

        // Bring first dot (lightest) to front so it's visible when stacked
        dotsContainer.bringSubviewToFront(dots[0])

        UIView.animate(withDuration: 0.4, delay: 0, options: [.curveEaseInOut], animations: {
            // Move all dots back to center
            for dot in self.dots {
                dot.transform = .identity
            }
        }) { _ in
            // Fade out the other two dots
            UIView.animate(withDuration: 0.3, animations: {
                self.dots[1].alpha = 0.0
                self.dots[2].alpha = 0.0
            }) { _ in
                // Wait before repeating
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    // Check if animation should continue
                    if self.loadingContainerView?.superview != nil {
                        self.animateStep1()
                    }
                }
            }
        }
    }

    private func stopThreeStepAnimation() {
        // Bring first dot to front before grouping
        if dots.count >= 1 {
            dotsContainer.bringSubviewToFront(dots[0])
        }

        // First group all dots at center before stopping
        UIView.animate(withDuration: 0.3, animations: {
            for dot in self.dots {
                dot.transform = .identity
            }
            self.dots[1].alpha = 0.0
            self.dots[2].alpha = 0.0
        }) { _ in
            // Remove all animations
            for dot in self.dots {
                dot.layer.removeAllAnimations()
            }
        }
    }

    @objc private func retryTapped() {
        delegate?.loadingManagerDidRequestRetry(self)
    }

    @objc private func closeTapped() {
        delegate?.loadingManagerDidRequestClose(self)
    }
}
