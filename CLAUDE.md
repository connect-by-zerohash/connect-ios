# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ConnectSDK is an iOS Swift SDK that provides OAuth2/OIDC authentication and deposit functionality for the Connect platform. The SDK embeds a WebView to present the Connect web application and uses JavaScript message handlers for bidirectional communication between native iOS code and the web app.

## Development Commands

### Building
```bash
# Build the package
swift build

# Build for a specific platform (iOS required)
xcodebuild -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Testing
```bash
# Run all tests
swift test

# List all tests
swift test list

# Run a specific test
swift test --filter ConnectSDKTests.testSpecificFunction
```

Note: Testing requires an iOS simulator or device since UIKit is required. The command `swift test` will fail on macOS targets because the SDK imports UIKit and is iOS-only.

### Code Structure
```
Sources/ConnectSDK/
├── Core/           # Public API and base types
├── Auth/           # Authentication-specific types and session management
├── UI/             # View controllers, WebView managers, and theme helpers
│   ├── Components/ # WebView message handlers and managers
│   ├── ViewControllers/ # Main and sub-view controllers
│   └── Theme/      # Theme configuration helpers
└── Internal/       # Internal constants and utilities

Tests/ConnectSDKTests/  # Unit tests with mocks
```

## Architecture

### Entry Point
- **ConnectSDK** (`Core/ConnectSDK.swift`): Single public entry point with `configureAuth()` method
- Returns a `ConnectAuthSession` that can be presented later for optimal UX

### Session Flow
1. User calls `ConnectSDK.configureAuth()` with JWT, environment, theme, and callbacks
2. This creates a `ConnectAuthSession` (not yet presented)
3. User calls `session.present(from: viewController)` when ready
4. SDK creates `WebViewController` wrapped in `UINavigationController`
5. WebView loads `https://sdk.connect.xyz/mobile/#auth`
6. JavaScript message handlers enable communication between native and web

### WebView Communication
- **Channel**: One `WKScriptMessageHandler` registered as `NativeIOS`. All inbound messages from the web side (UIWebView `{type, data}` and ZeroAuth ScrapingWebView envelopes) come through this channel.
- **Routing**: `NativeIOSMessageHandler` decodes the body and dispatches by `role`:
  - `role === "zeroauth-host"` → `ScrapingWebViewMessageRouter.dispatch` (operations like `auth.login`, `auth.status`, `core.ping`).
  - otherwise → `UIWebViewMessageRouter.handle` (types: `page-ready`, `content-ready`, `navigate`, `close`, `error`, `event`, `deposit`, `withdrawal`).
- **Origin Validation**: Only accepts messages from `sdk.connect.xyz` (or the configured local-dev host) for security.
- **Native to Web**: Always uses `window.postMessage(...)`. UIWebView types pass through unchanged. ScrapingWebView replies arrive as `{type: "scraping-webview-response", data: <ZeroAuthResponse>}` and out-of-band events as `{type: "scraping-webview-event", data: <BridgeEvent>}`.
- **Web to Native**: Uses `window.webkit.messageHandlers.NativeIOS.postMessage(...)` — payload is either a JSON-stringified UIWebView message or a JS object envelope.

### Key Components

#### WebViewController (`UI/ViewControllers/WebViewController.swift`)
- Main view controller hosting the WKWebView
- Manages loading state with `WebViewLoadingManager`
- Delegates message handling to `NativeIOSMessageHandler`
- Handles OAuth flows via `WebViewOAuthManager`
- Hides navigation bar initially, shows it for sub-navigation (in-app browser)

#### SubViewController (`UI/ViewControllers/SubViewController.swift`)
- In-app browser for navigation with `mobileTarget: "in_app"`
- Shows navigation bar with back button and page title
- Used for external links that should stay in-app

#### NativeIOSMessageHandler (`Bridge/NativeIOSMessageHandler.swift`)
- The single `WKScriptMessageHandler` registered on the `NativeIOS` channel.
- Validates message origins against the allowlist.
- Decodes the body and routes by `role`:
  - `UIWebViewMessageRouter` for `{type, data}` shapes.
  - `ScrapingWebViewMessageRouter` for `ZeroAuthRequest` envelopes.

#### PostMessageReplySink (`Bridge/PostMessageReplySink.swift`)
- The single outbound writer. All native-to-web traffic goes through `webView.evaluateJavaScript("window.postMessage(...)")`.
- Reserved ScrapingWebView types: `scraping-webview-response`, `scraping-webview-event`. All other type strings are UIWebView messages.
- Sanitises UIWebView `type` strings (only `[A-Za-z0-9-]` allowed) and uses `JSONSerialization` to prevent injection.

#### OAuthHandler (`Auth/OAuthHandler.swift`)
- Uses `ASWebAuthenticationSession` for secure OAuth flows
- Supports both custom URL schemes (`connectsdk-oauth://`) and Universal Links (HTTPS)
- Validates callback URLs against trusted domains
- Ephemeral session by default for security (no SSO with Safari)

### Navigation Patterns
- **`mobileTarget: "in_app"`**: Opens URL in SubViewController (in-app browser with nav bar)
- **`mobileTarget: "oauth"`**: Opens URL in ASWebAuthenticationSession (system OAuth browser)
- **Default**: Opens URL in external Safari browser

### Theme System
- Three modes: `.light`, `.dark`, `.system`
- `Theme` enum in `Core/ConnectSDKTypes.swift` with helper methods
- `ThemeHelper` provides navigation bar and status bar configuration
- WebView and native chrome colors are synchronized
- System theme automatically updates on trait collection changes

### Event Callbacks
- **AuthCallbacks**: Typed struct with optional closures for each event type
- **Event Wrappers**: `ErrorEvent`, `GenericEvent`, `DepositEvent` parse raw JSON into typed objects
- **DepositEvent.success**: Checks if `status.value == "processed"`
- All callbacks receive raw JSON string for debugging/forwarding

## Important Patterns

### Security Considerations
- Always validate message origins from WebView (only `sdk.connect.xyz`)
- Validate OAuth callback URLs against trusted domains
- Use JSON serialization (not string interpolation) to prevent injection
- Default to ephemeral OAuth sessions (no persistent cookies)
- JWT tokens are passed to WebView but never stored persistently

### Testing Approach
- Unit tests use mock objects (`Tests/ConnectSDKTests/TestHelpers/`)
- `MockWebView` and `MockAuthSession` avoid UIKit dependencies where possible
- Test callback invocation and data parsing separately
- Lifecycle tests verify session state transitions

### Code Conventions
- Use `@MainActor` for UI-related classes (WebViewController, ConnectAuthSession)
- Internal protocols like `CallbackHandler` bridge public and internal APIs
- Weak references for delegates to avoid retain cycles
- All public types are in `Core/` or `Auth/` folders
- UI implementation details are internal

## Common Issues

### UIKit Import Errors
The SDK is iOS-only. Building or testing on macOS will fail with "no such module 'UIKit'". Use iOS simulator or device for development and testing.

### Message Not Received from WebView
Check that the web page origin is `sdk.connect.xyz`. Messages from other origins are rejected for security.

### OAuth Callback Not Working
Verify callback URL scheme matches expected format:
- Custom: `connectsdk-oauth://callback`
- Universal Links: `https://connect.xyz/*` or `https://zerohash.com/*`

### Theme Not Applied
Ensure theme is set before presentation. Theme changes after presentation require manual navigation bar updates via `traitCollectionDidChange`.

## Repository Sync

This repository syncs to `connect-by-zerohash/connect-ios` via GitHub Actions workflow. The workflow:
- Triggers on pushes to `main` branch
- Squashes all new commits into a single commit
- Pushes to the public repository
- Only runs when source repo is NOT the public repo (prevents loops)
