# Changelog

All notable changes to ConnectSDK for iOS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] – 2026-06-04

### Fixed

- The WebView host allow-list now fails closed when it can't be compiled.
  Before, if `WKContentRuleListStore` was unavailable or the rules failed
  to compile, `ContentRuleList.compile` returned `nil` silently and the
  WebView loaded with no allow-list, so XHR-style requests could reach any
  host. The SDK now logs the failure in every build and calls
  `assertionFailure` in debug builds so a regression is caught during
  development. The load is refused either way.
- Fixed the default allow-list never compiling. WebKit's content-rule regex
  engine rejects an end-of-string anchor inside an alternation group
  (`([/:?#]|$)` fails with `WKErrorDomain` error 6), so the rules silently
  failed to compile and the WebView fell back to loading with no
  restrictions. Each host now emits two rules per scheme, one ending in
  `[/:?#]` and one ending in `$`, which keeps the "delimiter or end of
  string" boundary that rejects look-alike hosts such as
  `connect.xyz.evil.com`.

## [1.0.0] – 2026-05-31

First stable release. This is a **major** version that addresses every item
from a security review of the SDK and replaces the hijackable
`connectsdk-oauth://` custom URL scheme with a Universal Link OAuth callback.
Integrators upgrading from `0.x` will need to make changes — see the
**Breaking changes** section below.

### Breaking changes

- **Minimum deployment target raised to iOS 17.4** (was iOS 13). Required
  by `ASWebAuthenticationSession.Callback.https(host:path:)`, which is the
  iOS API that enforces Universal Link routing inside the auth session.
  Integrators on a lower deployment target cannot consume this SDK
  version.
- **`oauthCallback: ConnectOAuthCallback` is now a required argument** on
  `ConnectSDK.configureAuth`, `configureRecovery`, and
  `configureWithdrawal`. There is no default — any call site that doesn't
  supply one will fail to compile. The argument is uniformly required on
  all three configure entry points regardless of which specific
  integrations the integrator exposes (OAuth-driven flows like Gemini or
  Coinbase, or non-OAuth ones like wallet connect, scraping, manual).
  Integrators must:
    1. Pick a Universal Link host they control.
    2. Add `applinks:<host>` and `webcredentials:<host>` (plus the
       `?mode=developer` variants for dev builds) to their app's
       `Associated Domains` entitlement. The `webcredentials:` entry is
       mandatory — plain `applinks:` alone produces an "Application is
       not associated with domain …" runtime error.
    3. Serve an `apple-app-site-association` file at
       `https://<host>/.well-known/apple-app-site-association` declaring
       their bundle identifier under both `applinks` and `webcredentials`.
    4. Pass `ConnectOAuthCallback(host: "<host>", path: "<path>")` to every
       `configure*` call.
    5. Register the host with zerohash so it is allow-listed on the
       Connect backend.
  See the README's "Universal Link Setup" section for the full procedure.
- **`connectsdk-oauth://` custom URL scheme fully removed.** No
  deprecation, no fallback. The constants (`oauthCallbackScheme`,
  `expectedCallbackHost`), the custom-scheme branches in
  `OAuthHandler.authenticate` and `validateCallbackURL`, and the
  `OAuthError.unexpectedRedirect` error case have all been deleted.
  Migrate to the Universal Link flow.
- **`WKWebsiteDataStore.nonPersistent()` is now used on both embedded
  `WKWebView` instances.** Cookies, localStorage, IndexedDB, and the
  HTTP cache are scoped to the live `WKWebView` and discarded on
  dismissal. Integrators relying on session persistence within the
  embedded web app will see that state disappear.
- **`WKContentRuleList` is now enforced on every WebView resource load.**
  Top-level navigations, subresources, fetch/XHR, and WebSocket loads
  are blocked unless the host is in the configured `ConnectAllowList`.
  Default allow-list is `["connect.xyz", "zerohash.com"]` (exact-host or
  dot-suffix match). Integrators whose deployments relied on the SDK
  loading anything from outside those hosts will see those loads fail —
  mitigable by passing a custom `ConnectAllowList` to the configure call.
- **`SubViewController` enforces the allow-list on every navigation**
  via `webView(_:decidePolicyFor:decisionHandler:)`. Previously the
  allow-list was only checked on the initial URL load and used a buggy
  `hasSuffix` match that allowed sibling hosts (e.g. `evilconnect.xyz`
  matched `connect.xyz`). Any flow that lands on a non-allow-listed host
  post-initial-load (e.g. via server-side redirect) will now be
  cancelled.

### Added

- Public `ConnectAllowList` type. Integrators can supply their own
  allow-list (e.g. fetched over-the-air) via the `allowList:` parameter
  on the configure methods. Defaults to
  `["connect.xyz", "zerohash.com"]` if not provided. Host matching is
  exact-or-dot-suffix.
- Public `ConnectOAuthCallback` type for configuring the Universal Link
  OAuth callback. See README for setup.
- `PrivacyInfo.xcprivacy` privacy manifest declaring no tracking, no
  data collection, and no required-reason API usage. Bundled as a
  resource on the SDK target.
- Internal `os_log`-backed logging under subsystem
  `com.zerohash.connect.sdk`. Calls are `#if DEBUG`-gated and compile
  to no-ops in release builds.

### Removed

- `print()` calls. Every diagnostic site now routes through the internal
  `Log` helper, which is silent in release builds.
- `OAuthHandler.OAuthError.unexpectedRedirect` enum case.

### Security

- All client feedback items from the security review are addressed:
  `WKContentRuleList` enforcement, per-navigation allow-list checks with
  exact-host-or-dot-suffix matching, configurable allow-list, privacy
  manifest, no `print()` in release, non-persistent WebView storage, and
  Universal Link OAuth replacing the hijackable custom URL scheme.
- The `SubViewController` rejects disallowed hosts at three independent
  layers — `decidePolicyFor`, the initial-URL guard in `loadWebsite()`,
  and the `WKContentRuleList` at the network layer — so server-side
  redirects, programmatic `fetch()`, and direct navigation are all
  covered.
