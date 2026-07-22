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
- **Secure OAuth2/OIDC Authentication** — Universal Link callbacks via `ASWebAuthenticationSession`
- **Configurable host allow-list** — restrict the hosts the embedded WebView is allowed to navigate to or load resources from
- **Theme Support** — Light, dark, and system theme options to match your app's design
- **Real-time Event Callbacks** — Typed callbacks for each app flow
- **Multiple Environments** — Sandbox and production environments
- **Type-Safe** — Full Swift type safety with comprehensive error handling

## Requirements

- iOS 17.4+
- Swift 6.0+
- Xcode 15.3+

> The minimum deployment target is **iOS 17.4** because the SDK relies on
> `ASWebAuthenticationSession.Callback.https(host:path:)` to enforce
> Universal Link routing for the OAuth callback. See
> [Universal Link Setup](#universal-link-setup) for the full integration
> requirements.

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

> Upgrading from a `0.x` version? See [CHANGELOG.md](CHANGELOG.md) — the
> `1.0.0` release contains several intentional breaking changes
> (iOS 17.4 deployment minimum, required `oauthCallback` argument,
> Universal Link OAuth replacing the removed `connectsdk-oauth://`
> scheme).

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

### Configure the OAuth callback

All three apps require a `ConnectOAuthCallback` describing the Universal
Link iOS will route the OAuth callback to at the end of the authentication
flow. The callback **must** be backed by an `apple-app-site-association`
(AASA) file on the host you supply, and the host must be communicated to
zerohash so it can be allow-listed on the Connect backend. See
[Universal Link Setup](#universal-link-setup) for the full setup.

```swift
let oauthCallback = ConnectOAuthCallback(
    host: "links.your-app.com",
    path: "/connect/oauth-callback"
)
```

### (Optional) Configure the host allow-list

The SDK ships with a built-in allow-list that permits navigations and
resource loads to `connect.xyz`, `zerohash.com`, and their subdomains.
You can supply your own list — for example to add a host that hosts your
Universal Link, or to limit the SDK to a subset of hosts — via
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
            allowList: .default,
            oauthCallback: ConnectOAuthCallback(
                host: "links.your-app.com",
                path: "/connect/oauth-callback"
            )
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
            allowList: .default,
            oauthCallback: ConnectOAuthCallback(
                host: "links.your-app.com",
                path: "/connect/oauth-callback"
            )
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
            allowList: .default,
            oauthCallback: ConnectOAuthCallback(
                host: "links.your-app.com",
                path: "/connect/oauth-callback"
            )
        )

        withdrawalSession?.present(from: self)
    }
}
```

## Universal Link Setup

OAuth flows in ConnectSDK terminate at a **Universal Link**. Unlike
custom URL schemes, iOS will only deliver the callback URL to the app
declared in the `apple-app-site-association` (AASA) file served by the
callback host — another app cannot register itself to intercept the
callback. This is the routing model the SDK enforces via
`ASWebAuthenticationSession.Callback.https(host:path:)` (iOS 17.4+).

To finish the OAuth flow successfully, you must complete every step
below. **Skipping any step will surface as an "Application is not
associated with domain …" error or as a callback that never returns to
the app.**

### 1. Pick a callback host and path

Choose a host that you control and that you can serve an AASA file from
over HTTPS — for example `links.your-app.com`. Pick a path prefix that
is unique to the Connect OAuth callback, for example
`/connect/oauth-callback`.

You will use the same `host` and `path` values in your entitlement, in
your AASA file, in the `ConnectOAuthCallback` you pass to the SDK, and
when communicating the host to zerohash.

### 2. Add the Associated Domains entitlement

In your app target's **Signing & Capabilities**, add the **Associated
Domains** capability and declare two entries for the callback host —
`applinks:` for Universal Link routing and `webcredentials:` (required
by `ASWebAuthenticationSession.Callback.https`; without it the auth
session fails with "Application is not associated with domain …" at
runtime):

```
applinks:links.your-app.com
webcredentials:links.your-app.com
```

For development builds you can also include the `?mode=developer`
variants so `swcd` bypasses Apple's AASA CDN and fetches your AASA
directly during testing — production-signed builds (TestFlight / App
Store) ignore the `?mode=developer` form, so include both:

```
applinks:links.your-app.com
applinks:links.your-app.com?mode=developer
webcredentials:links.your-app.com
webcredentials:links.your-app.com?mode=developer
```

### 3. Serve an AASA file from the callback host

The callback host must serve an `apple-app-site-association` file at:

```
https://links.your-app.com/.well-known/apple-app-site-association
```

Requirements:

- HTTP 200, no redirects
- `Content-Type: application/json`
- Body declares your app's bundle identifier under both `applinks` and
  `webcredentials`, and the `applinks.details[].components` entry
  matches the path prefix you'll pass to `ConnectOAuthCallback`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["TEAMID.com.your.bundle.id"],
        "components": [
          { "/": "/connect/oauth-callback*" }
        ]
      }
    ]
  },
  "webcredentials": {
    "apps": ["TEAMID.com.your.bundle.id"]
  }
}
```

Replace `TEAMID` with your Apple Developer Team ID and
`com.your.bundle.id` with your app's bundle identifier. The path inside
`components` must match the `path` value you supply to
`ConnectOAuthCallback` (the trailing `*` allows any suffix appended by
the OAuth provider).

### 4. Pass the callback to the SDK

The `host` and `path` you pass here **must match the AASA file and the
Associated Domains entitlement exactly**, otherwise iOS won't route the
callback to your app:

```swift
let oauthCallback = ConnectOAuthCallback(
    host: "links.your-app.com",
    path: "/connect/oauth-callback"
)

let session = ConnectSDK.configureAuth(
    jwt: jwt,
    oauthCallback: oauthCallback
)
```

`ConnectOAuthCallback` is a required parameter on
`configureAuth`, `configureRecovery`, and `configureWithdrawal` — there
is no default and the call will fail to compile without it.

### 5. Communicate the callback host to zerohash

The Connect backend enforces an allow-list of permitted OAuth callback
hosts. Before your integration can complete an OAuth flow in either
sandbox or production, you must send zerohash:

- The **callback host** (e.g. `links.your-app.com`)
- The **callback path** (e.g. `/connect/oauth-callback`)
- The **environment(s)** the host should be enabled in (sandbox,
  production, or both)
- Your **Apple Team ID** and **bundle identifier**, so the values can be
  cross-checked against your AASA file

Reach out via your usual zerohash integration channel (your account
manager, integration Slack channel, or
[support](https://zerohash.com/)) and include the items above. Until
the host is registered server-side, the Connect backend will not redirect
to it at the end of the OAuth flow.

### 6. (Recommended) Add the callback host to the SDK allow-list

If your callback host is outside the default `connect.xyz` /
`zerohash.com` allow-list, add it to the `ConnectAllowList` you pass to
the SDK so navigations to it are not blocked by the embedded WebView:

```swift
let allowList = ConnectAllowList(hosts: [
    "connect.xyz",
    "zerohash.com",
    "links.your-app.com"
])
```

### Validation

The SDK validates every callback URL before delivering it to the OAuth
result handler. A callback is accepted only when:

- the scheme is `https`,
- the URL's host equals the configured host exactly, or ends with
  `"." + host` (exact-host-or-dot-suffix), **and**
- the URL's path begins with the configured path.

Failures are logged via `os_log` under the subsystem
`com.zerohash.connect.sdk` and surfaced as an `invalidCallbackURL`
error.

## API Reference

### ConnectSDK

The main entry point for the SDK. All three configure methods follow the
same shape; only the callbacks struct and the returned session type
differ.

#### `configureAuth(jwt:environment:theme:callbacks:allowList:oauthCallback:)`

Configures an Auth session that can be presented later. Returns a
`ConnectAuthSession`.

#### `configureRecovery(jwt:environment:theme:callbacks:allowList:oauthCallback:)`

Configures a Recovery session that can be presented later. Returns a
`ConnectRecoverySession`.

#### `configureWithdrawal(jwt:environment:theme:callbacks:allowList:oauthCallback:)`

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
| `oauthCallback` | `ConnectOAuthCallback` | — (required) | Universal Link the OAuth flow returns to |

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

#### ConnectOAuthCallback

```swift
public struct ConnectOAuthCallback {
    public let host: String
    public let path: String

    public init(host: String, path: String = "/oauth-callback")
}
```

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

```swift
deposit.depositId    // String? - Unique deposit identifier
deposit.status       // String? - Current deposit status
deposit.success      // Bool   - True when status.value == "processed"
deposit.assetId      // String? - Asset ticker (BTC, ETH, USDC, etc.)
deposit.networkId    // String? - Network/chain used
deposit.amount       // String? - Amount deposited
deposit.data         // [String: Any] - Raw event data
deposit.jsonString   // String - Raw JSON string
```

### onWithdrawal (Recovery and Withdrawal)

Called when a withdrawal event occurs during the Recovery or Withdrawal flow.

```swift
withdrawal.withdrawalId  // String? - Unique withdrawal identifier
withdrawal.status        // String? - Current withdrawal status
withdrawal.success       // Bool   - True when status.value == "processed"
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
ConnectSDK.configureAuth(jwt: token, theme: .light, oauthCallback: callback)

// Dark theme
ConnectSDK.configureAuth(jwt: token, theme: .dark, oauthCallback: callback)

// System theme (default) — matches device settings
ConnectSDK.configureAuth(jwt: token, theme: .system, oauthCallback: callback)
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
