# ConnectSDK for iOS

![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange.svg)
![Platform](https://img.shields.io/badge/Platform-iOS%2017.4%2B-blue.svg)
![SPM Compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)

A Swift SDK for seamless integration with the [Connect](https://docs.zerohash.com/docs/connect) product.

The SDK exposes three apps that can be presented from your iOS application:

- **Auth** — onboarding, KYC, and deposit flow
- **Recovery** — account recovery flow with terminal withdrawal
- **Withdrawal** — standalone withdrawal flow

## Features

- **Three Connect apps** — Auth, Recovery, and Withdrawal exposed through a single SDK
- **Secure OAuth2/OIDC Authentication** — system-browser OAuth via `ASWebAuthenticationSession`, no host-app configuration required
- **Configurable host allow-list** — restrict the hosts the embedded WebView is allowed to navigate to or load resources from
- **Theme Support** — Light, dark, and system theme options to match your app's design
- **Real-time Event Callbacks** — Typed callbacks for each app flow
- **Multiple Environments** — Sandbox and production environments
- **Type-Safe** — Full Swift type safety with comprehensive error handling

## Requirements

- iOS 17.4+
- Swift 6.0+
- Xcode 15.3+


### Required Info.plist keys

Crypto transactions in the Auth SDK can be held by the exchange for an identity check, which the
user completes inside the SDK's WebView using the camera. Your app must declare
both keys below.

| Key | Why |
| --- | --- |
| `NSCameraUsageDescription` | Liveness / document capture during the identity check |
| `NSMicrophoneUsageDescription` | Requested alongside the camera by the identity check |


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
    .package(url: "https://github.com/connect-by-zerohash/connect-ios", from: "1.0.0")
]
```

> Upgrading? See [CHANGELOG.md](CHANGELOG.md). `1.2.0` fixes OAuth and makes the
> `oauthCallback` argument redundant. No source changes are required. When
> convenient, delete the argument from your `configure*` calls and drop the
> Associated Domains entitlement and AASA file it needed.

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

### Obtain a JWT Token

Before presenting any of the apps, you'll need to obtain a JWT token from
your backend. This token authenticates the end user with the Connect
platform.

> **Note:** For detailed instructions on obtaining JWT tokens, please refer to the [Connect documentation](https://docs.zerohash.com/docs/connect).

### OAuth requires no configuration

OAuth flows run in `ASWebAuthenticationSession` and return on the
`connectsdk-oauth://callback` scheme. The session claims that redirect
in-process, so there is nothing to register in your `Info.plist`, no
Associated Domains entitlement, and no `apple-app-site-association` file to
host.

### (Optional) Configure the host allow-list

The SDK ships with a built-in allow-list that permits navigations and
resource loads to `connect.xyz`, `zerohash.com`, `gemini.com`,
`robinhood.com`, and their subdomains.
You can supply your own list — for example to reach an additional host, or
to limit the SDK to a subset of hosts — via
`ConnectAllowList`. Host matching is exact or via dot-suffix subdomain.

```swift
let allowList = ConnectAllowList(hosts: [
    "connect.xyz",
    "zerohash.com",
    "links.your-app.com"
])
```

If you don't pass `allowList`, the SDK uses `ConnectAllowList.default`.

## Usage

### Auth

The Auth app handles onboarding, KYC, and the deposit flow. Use
`onDeposit` to react to deposit events.

```swift
import UIKit
import ConnectSDK

class AuthViewController: UIViewController {

    private var authSession: ConnectAuthSession?

    @IBAction func startAuthTapped(_ sender: UIButton) {
        let callbacks = AuthCallbacks(
            onClose: { print("Auth closed") },
            onError: { error in
                print("Auth error \(error.code): \(error.message)")
            },
            onEvent: { event in
                print("Auth event: \(event.type)")
            },
            onDeposit: { deposit in
                if deposit.success {
                    print("Deposit \(deposit.depositId ?? "?") processed")
                } else {
                    print("Deposit status: \(deposit.status ?? "unknown")")
                }
            }
        )

        authSession = ConnectSDK.configureAuth(
            jwt: "your-jwt-token",
            environment: .production,
            theme: .system,
            callbacks: callbacks,
            allowList: .default
        )

        authSession?.present(from: self)
    }
}
```

### Recovery

The Recovery app drives the account-recovery experience and emits a
withdrawal event when the recovering user completes the terminal
withdrawal step.

```swift
import UIKit
import ConnectSDK

class RecoveryViewController: UIViewController {

    private var recoverySession: ConnectRecoverySession?

    @IBAction func startRecoveryTapped(_ sender: UIButton) {
        let callbacks = RecoveryCallbacks(
            onClose: { print("Recovery closed") },
            onError: { error in
                print("Recovery error \(error.code): \(error.message)")
            },
            onEvent: { event in
                print("Recovery event: \(event.type)")
            },
            onWithdrawal: { withdrawal in
                if withdrawal.success {
                    print("Recovery withdrawal \(withdrawal.withdrawalId ?? "?") processed")
                } else {
                    print("Recovery withdrawal status: \(withdrawal.status ?? "unknown")")
                }
            }
        )

        recoverySession = ConnectSDK.configureRecovery(
            jwt: "your-jwt-token",
            environment: .production,
            theme: .system,
            callbacks: callbacks,
            allowList: .default
        )

        recoverySession?.present(from: self)
    }
}
```

### Withdrawal

The Withdrawal app is the standalone withdrawal flow. It shares the
`WithdrawalEvent` payload with Recovery.

```swift
import UIKit
import ConnectSDK

class WithdrawalViewController: UIViewController {

    private var withdrawalSession: ConnectWithdrawalSession?

    @IBAction func startWithdrawalTapped(_ sender: UIButton) {
        let callbacks = WithdrawalCallbacks(
            onClose: { print("Withdrawal closed") },
            onError: { error in
                print("Withdrawal error \(error.code): \(error.message)")
            },
            onEvent: { event in
                print("Withdrawal event: \(event.type)")
            },
            onWithdrawal: { withdrawal in
                if withdrawal.success {
                    print("Withdrawal \(withdrawal.withdrawalId ?? "?") processed")
                    print("Asset: \(withdrawal.assetId ?? "N/A")")
                    print("Network: \(withdrawal.networkId ?? "N/A")")
                    print("Amount: \(withdrawal.amount ?? "N/A")")
                } else {
                    print("Withdrawal status: \(withdrawal.status ?? "unknown")")
                }
            }
        )

        withdrawalSession = ConnectSDK.configureWithdrawal(
            jwt: "your-jwt-token",
            environment: .production,
            theme: .system,
            callbacks: callbacks,
            allowList: .default
        )

        withdrawalSession?.present(from: self)
    }
}
```

## API Reference

### ConnectSDK

The main entry point for the SDK. All three configure methods follow the
same shape; only the callbacks struct and the returned session type
differ.

#### `configureAuth(jwt:environment:theme:callbacks:allowList:)`

Configures an Auth session that can be presented later. Returns a
`ConnectAuthSession`.

#### `configureRecovery(jwt:environment:theme:callbacks:allowList:)`

Configures a Recovery session that can be presented later. Returns a
`ConnectRecoverySession`.

#### `configureWithdrawal(jwt:environment:theme:callbacks:allowList:)`

Configures a Withdrawal session that can be presented later. Returns a
`ConnectWithdrawalSession`.

#### `clearWebsiteData()` `async`

Clears all website data (cookies, localStorage, IndexedDB, caches, service
workers) from the SDK-private `WKWebsiteDataStore`. The SDK uses a
persistent store, isolated from the host app's other `WKWebView`
storage, so third-party session state (e.g. a exchange login) can be
reused between offscreen and modal runs and survives app relaunches.

Call this on user sign-out or from a "clear cache" affordance in your app.
Calling during an active session invalidates cookies and storage the
running session may depend on.

```swift
Task { await ConnectSDK.clearWebsiteData() }
```

**Shared parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `jwt` | `String` | — | JWT token authenticating the end user |
| `environment` | `Environment` | `.production` | `.sandbox` or `.production` |
| `theme` | `Theme` | `.system` | `.light`, `.dark`, or `.system` |
| `callbacks` | `AuthCallbacks` / `RecoveryCallbacks` / `WithdrawalCallbacks` | empty | App-specific event callbacks |
| `allowList` | `ConnectAllowList` | `.default` | Hosts the WebView may navigate to / load resources from |

### Session types

All three session types (`ConnectAuthSession`, `ConnectRecoverySession`,
`ConnectWithdrawalSession`) share the same lifecycle:

#### `present(from:)`

Presents the UI from the specified view controller.

- **Parameter** `viewController: UIViewController` — the view controller to present from
- **Returns** `ConnectSession?` — the active session if presentation succeeded

#### `cancel()`

Cancels the session if it is active.

#### `isActive`

A boolean indicating whether the session is currently active.

### Types

#### Environment

```swift
enum Environment {
    case sandbox     // Testing environment
    case production  // Production environment
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

#### ConnectAllowList

```swift
public struct ConnectAllowList {
    public let hosts: [String]

    public init(hosts: [String])

    /// Default allow-list shipped with the SDK: connect.xyz + zerohash.com
    public static let `default`: ConnectAllowList
}
```

Host matching is exact, or via dot-suffix subdomain — `connect.xyz`
matches `sdk.connect.xyz` but not `evilconnect.xyz`.

#### AuthCallbacks

```swift
struct AuthCallbacks {
    var onClose: (() -> Void)?
    var onError: ((ErrorEvent) -> Void)?
    var onEvent: ((GenericEvent) -> Void)?
    var onDeposit: ((DepositEvent) -> Void)?
}
```

#### RecoveryCallbacks

```swift
struct RecoveryCallbacks {
    var onClose: (() -> Void)?
    var onError: ((ErrorEvent) -> Void)?
    var onEvent: ((GenericEvent) -> Void)?
    var onWithdrawal: ((WithdrawalEvent) -> Void)?
}
```

#### WithdrawalCallbacks

```swift
struct WithdrawalCallbacks {
    var onClose: (() -> Void)?
    var onError: ((ErrorEvent) -> Void)?
    var onEvent: ((GenericEvent) -> Void)?
    var onWithdrawal: ((WithdrawalEvent) -> Void)?
}
```

## Callbacks and Events

See all callback payloads in the
[Connect documentation](https://docs.zerohash.com/docs/front-end-implementation-guide#shared-callbacks).

### onDeposit (Auth only)

Called when a deposit event occurs during the Auth flow.

`onDeposit` is a **status, not an outcome**. It also fires while account matching
is verifying, and can arrive more than once for the same deposit, so read the
outcome off `success` rather than treating the call itself as completion.

```swift
deposit.depositId              // String? - Unique deposit identifier
deposit.status                 // String? - "CONFIRMED", "PROCESSED", "PENDING", "FAILED", ...
deposit.success                // Bool   - True at "CONFIRMED" or "PROCESSED", unless
                               //          account matching is PENDING/INVALID/ERROR
deposit.assetId                // String? - Asset ticker (BTC, ETH, USDC, etc.)
deposit.networkId              // String? - Network/chain used
deposit.amount                 // String? - Amount deposited
deposit.accountMatchingStatus  // String? - "PENDING", "VALID", "INVALID", "ERROR"
deposit.accountMatchingReason  // String? - Why account matching failed
deposit.data                   // [String: Any] - Raw event data
deposit.jsonString             // String - Raw JSON string
```

A successful deposit reports `CONFIRMED` on most platforms and `PROCESSED` on
platforms running zerohash with auto-convert; both count as success.

### onWithdrawal (Recovery and Withdrawal)

Called when a withdrawal event occurs during the Recovery or Withdrawal flow.

```swift
withdrawal.withdrawalId  // String? - Unique withdrawal identifier
withdrawal.status        // String? - Current withdrawal status
withdrawal.success       // Bool   - True at "CONFIRMED" or "PROCESSED"
withdrawal.assetId       // String? - Asset ticker (BTC, ETH, USDC, etc.)
withdrawal.networkId     // String? - Network/chain used
withdrawal.amount        // String? - Amount withdrawn
withdrawal.data          // [String: Any] - Raw event data
withdrawal.jsonString    // String - Raw JSON string
```

### onError

Called when an error occurs during any of the flows.

```swift
error.code        // String - Error code
error.message     // String - Human-readable error message
error.data        // [String: Any] - Additional error details
error.jsonString  // String - Raw JSON string
error.timestamp   // Date - When the error occurred
```

### onEvent

Called for generic events during the flow. [Documentation](https://docs.zerohash.com/docs/front-end-implementation-guide#shared-callbacks).

```swift
event.type                // String - Event type identifier
event.data                // [String: Any] - Event data
event.getString("key")    // String? - Get string value
event.getInt("key")       // Int? - Get integer value
event.getBool("key")      // Bool? - Get boolean value
event.getObject("key")    // [String: Any]? - Get nested object
event.getDouble("key")    // Double? - Get double value
```

### onClose

Called when the session is closed by the user or programmatically via
`cancel()`.

## Themes and Customization

### Setting Theme

The SDK supports three theme options across all three apps:

```swift
// Light theme
ConnectSDK.configureAuth(jwt: token, theme: .light)

// Dark theme
ConnectSDK.configureAuth(jwt: token, theme: .dark)

// System theme (default) — matches device settings
ConnectSDK.configureAuth(jwt: token, theme: .system)
```

### Theme Behavior

- **`.system`** — Automatically switches between light and dark based on device settings
- **`.light`** — Forces light theme regardless of device settings
- **`.dark`** — Forces dark theme regardless of device settings

The theme applies to the WebView content and the navigation bar
appearance.

## Contact

For additional support or questions about the Connect platform:
- [Technical Support](https://zerohash.com/)
- [Documentation](https://docs.zerohash.com/docs/connect)

## Contributing

### Versioning

ConnectSDK follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

- **MAJOR** (e.g. `2.0.0`) — breaking changes that require consumers to update
  their integration.
- **MINOR** (e.g. `1.1.0`) — new functionality that is backwards compatible;
  existing integrations keep working without changes.
- **PATCH** (e.g. `1.0.1`) — backwards-compatible bug fixes only.

Record every notable change in [`CHANGELOG.md`](CHANGELOG.md) under the version
it ships in.

### Publishing a release

Swift Package Manager resolves releases from **Git version tags**, not from
branches — merging to `main` does not publish a new version on its own. A new
version becomes available to consumers only once it is tagged:

1. Make sure the changes are merged to `main` and `CHANGELOG.md` has an entry
   for the new version.
2. Choose the next version number following Semantic Versioning above.
3. Tag the commit with the bare version number (**no `v` prefix**) and push the
   tag:

   ```bash
   git checkout main && git pull
   git tag -a 1.1.0 -m "Release 1.1.0"
   git push origin 1.1.0
   ```

4. Once the tag is published, consumers on a version rule such as
   `from: "1.0.0"` pick up the release on their next package resolve/update.
