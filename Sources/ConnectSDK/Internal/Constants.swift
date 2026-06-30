//
//  Constants.swift
//  ConnectSDK
//
//  Shared constants used throughout the SDK
//

import UIKit

internal enum Constants {

    // MARK: - Loading Animation

    enum LoadingAnimation {
        static let dotColor = UIColor(red: 252.0/255.0, green: 252.0/255.0, blue: 153.0/255.0, alpha: 1.0) // #FCFC99
        static let dotSize: CGFloat = 16
        static let dotSpacing: CGFloat = 20
        // Center-to-center distance between adjacent dots at full spread.
        // With dotSize 16 this yields a 14pt visible gap, so dots stay equally
        // spaced and never overlap. Single source of truth for both overlays
        // (replaces the previous implicit `dotSpacing * 1.5`).
        static let dotTranslation: CGFloat = 30
        static let animationDuration: TimeInterval = 0.5
        static let animationDelay: TimeInterval = 0.15
        static let animationTranslation: CGFloat = -15
    }

    // MARK: - UI Layout

    enum Layout {
        static let labelHorizontalPadding: CGFloat = 40
        static let loadingLabelTopSpacing: CGFloat = 20
        static let retryButtonTopSpacing: CGFloat = 20
        static let webViewTransitionDuration: TimeInterval = 0.3
        static let webViewTransitionDelay: TimeInterval = 0.1
    }
}
