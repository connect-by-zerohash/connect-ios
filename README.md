# ConnectSDK for iOS

![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2013.0%2B-blue.svg)
![SPM Compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)

A Swift SDK for seamless integration with the [Connect](https://docs.zerohash.com/docs/connect) product.

## Features

- **Secure OAuth2/OIDC Authentication** - Industry-standard authentication flow via embedded WebView
- **Theme Support** - Light, dark, and system theme options to match your app's design
- **iOS 13+ Support** - Compatible with iOS 13 and later versions
- **Real-time Event Callbacks** - Comprehensive event handling the deposit flow
- **Multiple Environments** - Support for both sandbox and production environments
- **Type-Safe** - Full Swift type safety with comprehensive error handling

## Requirements

- iOS 13.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

#### Using Xcode

1. In Xcode, select **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/connect-by-zerohash/connect-ios`
3. Select the version rule you want to use (we recommend up to next major)
4. Click **Add Package**

#### Using Package.swift

Add ConnectSDK as a dependency in your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/connect-by-zerohash/connect-ios", from: "0.0.1")
]
```

Then add `ConnectSDK` to your target's dependencies:

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ConnectSDK"]
    )
]
```

## Getting Started

### Import the SDK

```swift
import ConnectSDK
```

### Obtain JWT Token

Before using the SDK, you'll need to obtain a JWT token from your backend. This token authenticates your app with the Connect platform.

> 📘 **Note:** For detailed instructions on obtaining JWT tokens, please refer to [your company's authentication documentation](#).

### Basic Configuration

```swift
// Configure the auth session
let authSession = ConnectSDK.configureAuth(
    jwt: "your-jwt-token",
    environment: .production,  // or .sandbox for testing
    theme: .system             // matches device theme
)
```

## Usage

### Basic Example

Here's a simple example to get you started with ConnectSDK:

```swift
import UIKit
import ConnectSDK

class ViewController: UIViewController {

    private var authSession: ConnectAuthSession?

    @IBAction func authenticateButtonTapped(_ sender: UIButton) {
        // Configure auth session with minimal setup
        authSession = ConnectSDK.configureAuth(
            jwt: "your-jwt-token",
            callbacks: AuthCallbacks(
                onDeposit: { event in
                    // Handle successful deposit
                    if event.success {
                        print("Deposit successful!")
                        print("Deposit ID: \(event.depositId ?? "N/A")")
                    }
                }
            )
        )

        // Present the authentication UI
        authSession?.present(from: self)
    }
}
```

### Complete Example

Here's a comprehensive example showcasing all available features and callbacks:

```swift
import UIKit
import ConnectSDK

class AuthenticationViewController: UIViewController {

    private var authSession: ConnectAuthSession?

    func startAuthentication() {
        // Configure callbacks for all events
        let callbacks = AuthCallbacks(
            onClose: { [weak self] in
                // Handle session closure
                print("Authentication session closed")
                self?.handleSessionClosed()
            },
            onError: { [weak self] error in
                // Handle errors with detailed information
                print("Error occurred: \(error.message)")
                print("Error code: \(error.code)")

                // Access additional error data if needed
                if let additionalInfo = error.data["additionalInfo"] as? String {
                    print("Additional info: \(additionalInfo)")
                }

                self?.showErrorAlert(message: error.message)
            },
            onEvent: { event in
                // Handle generic events
                print("Event received: \(event.type)")

                // Access event data using convenience methods
                if let userId = event.getString("userId") {
                    print("User ID: \(userId)")
                }

                if let isVerified = event.getBool("verified") {
                    print("Verification status: \(isVerified)")
                }
            },
            onDeposit: { [weak self] deposit in
                // Handle deposit completion
                print("Deposit event received")

                if deposit.success {
                    // Deposit was successful
                    print("✅ Deposit successful!")
                    print("Deposit ID: \(deposit.depositId ?? "N/A")")
                    print("Asset: \(deposit.assetId ?? "N/A")")
                    print("Network: \(deposit.networkId ?? "N/A")")
                    print("Amount: \(deposit.amount ?? "N/A")")

                    self?.handleSuccessfulDeposit(deposit)
                } else {
                    // Deposit failed or is pending
                    print("⏳ Deposit status: \(deposit.status ?? "unknown")")
                }

                // Access raw data if needed
                print("Raw deposit data: \(deposit.jsonString)")
            }
        )

        // Configure auth session with all options
        authSession = ConnectSDK.configureAuth(
            jwt: getJWTToken(),
            environment: isDevelopment ? .sandbox : .production,
            theme: getUserPreferredTheme(),
            callbacks: callbacks
        )

        // Present the authentication UI
        if let session = authSession?.present(from: self) {
            print("Session ID: \(session.id)")
            print("Session created at: \(session.createdAt)")

            // You can check session state
            if session.isActive {
                print("Session is active")
            }
        }
    }

    // Helper methods
    private func getJWTToken() -> String {
        // Fetch JWT from your backend
        return "your-jwt-token"
    }

    private var isDevelopment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private func getUserPreferredTheme() -> Theme {
        // Return user's theme preference
        // This example returns system theme
        return .system
    }

    private func handleSessionClosed() {
        // Clean up after session closes
        authSession = nil
    }

    private func handleSuccessfulDeposit(_ deposit: DepositEvent) {
        // Navigate to success screen or update UI
        // This is called when a deposit is successfully processed
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // Cancel the session if needed
    func cancelAuthentication() {
        authSession?.cancel()
        authSession = nil
    }
}
```

## API Reference

### ConnectSDK

The main entry point for the SDK.

#### `configureAuth(jwt:environment:theme:callbacks:)`

Configures an authentication session that can be presented later.

**Parameters:**
- `jwt: String` - JWT token for authentication
- `environment: Environment` - Target environment (default: `.production`)
  - `.sandbox` - For testing and development
  - `.production` - For production use
- `theme: Theme` - UI theme (default: `.system`)
  - `.light` - Light theme
  - `.dark` - Dark theme
  - `.system` - Follows device theme
- `callbacks: AuthCallbacks` - Event callbacks (default: empty callbacks)

**Returns:** `ConnectAuthSession` - A configured session ready to be presented

### ConnectAuthSession

Manages the authentication session lifecycle.

#### `present(from:)`

Presents the authentication UI from the specified view controller.

**Parameters:**
- `viewController: UIViewController` - The view controller to present from

**Returns:** `ConnectSession?` - The active session if presentation succeeds

#### `cancel()`

Cancels the authentication session if it's active.

#### `isActive`

A boolean property indicating whether the session is currently active.

### Types and Enums

#### Environment

```swift
enum Environment {
    case sandbox    // Testing environment
    case production // Production environment
}
```

#### Theme

```swift
enum Theme {
    case light   // Light theme
    case dark    // Dark theme
    case system  // Follows device theme setting
}
```

#### AuthCallbacks

Structure containing all available callback handlers:

```swift
struct AuthCallbacks {
    var onClose: (() -> Void)?
    var onError: ((ErrorEvent) -> Void)?
    var onEvent: ((GenericEvent) -> Void)?
    var onDeposit: ((DepositEvent) -> Void)?
}
```

## Callbacks and Events

See all callbacks payloads in our [documentation](https://docs.zerohash.com/docs/front-end-implementation-guide#shared-callbacks)

### onDeposit

Called when a deposit event occurs during the authentication flow.

**DepositEvent Properties:**

```swift
deposit.depositId    // String? - Unique deposit identifier
deposit.status       // String? - Current deposit status
deposit.success      // Bool - Whether the deposit was successful
deposit.assetId      // String? - Asset ticker (BTC, ETH, USDC, etc.)
deposit.networkId    // String? - Network/chain used
deposit.amount       // String? - Amount deposited
deposit.data         // [String: Any] - Raw event data
deposit.jsonString   // String - Raw JSON string
```

### onError

Called when an error occurs during the authentication process.

**ErrorEvent Properties:**

```swift
error.code        // String - Error code
error.message     // String - Human-readable error message
error.data        // [String: Any] - Additional error details
error.jsonString  // String - Raw JSON string
error.timestamp   // Date - When the error occurred
```

### onEvent

Called for generic events during the authentication flow. [Documentation](https://docs.zerohash.com/docs/front-end-implementation-guide#shared-callbacks)

**GenericEvent Properties:**

```swift
event.type                    // String - Event type identifier
event.data                    // [String: Any] - Event data
event.getString("key")        // String? - Get string value
event.getInt("key")          // Int? - Get integer value
event.getBool("key")         // Bool? - Get boolean value
event.getObject("key")       // [String: Any]? - Get nested object
event.getDouble("key")       // Double? - Get double value
```

### onClose

Called when the authentication session is closed by the user or programmatically.

## Themes and Customization

### Setting Theme

The SDK supports three theme options:

```swift
// Light theme
let session = ConnectSDK.configureAuth(jwt: token, theme: .light)

// Dark theme
let session = ConnectSDK.configureAuth(jwt: token, theme: .dark)

// System theme (default) - automatically matches device settings
let session = ConnectSDK.configureAuth(jwt: token, theme: .system)
```

### Theme Behavior

- **`.system`** - Automatically switches between light and dark based on device settings
- **`.light`** - Forces light theme regardless of device settings
- **`.dark`** - Forces dark theme regardless of device settings

The theme affects the WebView content and navigation bar appearance.

## Contact

For additional support or questions about the Connect platform:
- [Technical Support](https://zerohash.com/)
- [Documentation](https://docs.zerohash.com/docs/connect)
