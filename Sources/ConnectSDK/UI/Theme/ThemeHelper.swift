//
//  ThemeHelper.swift
//  ConnectSDK
//
//  Handles theme appearance and color management
//

import UIKit

extension Theme {
    /// Dark background color matching website (#111113)
    static let darkBackgroundColor = UIColor(red: 17.0/255.0, green: 17.0/255.0, blue: 19.0/255.0, alpha: 1.0) // #111113

    /// Determines if dark mode should be used based on theme and system settings
    func shouldUseDarkMode(in traitCollection: UITraitCollection) -> Bool {
        switch self {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return traitCollection.userInterfaceStyle == .dark
        }
    }

    /// Returns the appropriate background color for navigation bars
    func navigationBarBackgroundColor(in traitCollection: UITraitCollection) -> UIColor {
        return shouldUseDarkMode(in: traitCollection) ? Theme.darkBackgroundColor : .systemBackground
    }

    /// Returns the appropriate tint color for navigation items
    func navigationBarTintColor(in traitCollection: UITraitCollection) -> UIColor {
        return shouldUseDarkMode(in: traitCollection) ? .white : .label
    }

    /// Configures navigation bar appearance
    func configureNavigationBar(_ navigationBar: UINavigationBar, traitCollection: UITraitCollection) {
        let appearance = UINavigationBarAppearance()

        if shouldUseDarkMode(in: traitCollection) {
            // Dark mode configuration
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = Theme.darkBackgroundColor
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

            navigationBar.tintColor = .white // Back button and items
            navigationBar.barStyle = .black // Makes status bar light
        } else {
            // Light mode configuration
            appearance.configureWithDefaultBackground()
            appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

            navigationBar.tintColor = .systemBlue
            navigationBar.barStyle = .default
        }

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
}
