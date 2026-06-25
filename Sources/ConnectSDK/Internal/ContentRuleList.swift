//
//  ContentRuleList.swift
//  ConnectSDK
//
//  Compiles a WKContentRuleList that blocks every resource load
//  (top-level navigations, subresources, fetch/XHR, and WebSockets)
//  unless the host matches an entry in the supplied allow-list.
//

import CryptoKit
import WebKit

internal enum ContentRuleList {

    @MainActor
    static func compile(
        for allowList: ConnectAllowList,
        completion: @escaping @MainActor (WKContentRuleList?) -> Void
    ) {
        guard let store = WKContentRuleListStore.default() else {
            reportCompileFailure("content rule list store unavailable")
            completion(nil)
            return
        }
        let encoded = encodedRules(for: allowList.hosts)
        let identifier = self.identifier(for: encoded)
        store.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: encoded
        ) { list, error in
            Task { @MainActor in
                if list == nil {
                    reportCompileFailure("content rule list compile failed: \(error?.localizedDescription ?? "unknown error")")
                }
                completion(list)
            }
        }
    }

    /// Called when no allow-list could be produced, either because the store
    /// was unavailable or the rules failed to compile. `compile` returns `nil`
    /// here, and callers fail closed: they refuse the load instead of showing a
    /// WebView with no host restrictions. The log line runs in every build,
    /// since that is the only signal we get from a shipped app. Debug builds
    /// also hit `assertionFailure` so a regression surfaces during development.
    @MainActor
    static func reportCompileFailure(_ reason: String) {
        #if DEBUG
        // Test seam: when set, unit tests can exercise the fail-closed path
        // without the `assertionFailure` below crashing the test process.
        // Never set outside tests.
        if let reporter = failureReporterOverride {
            reporter(reason)
            return
        }
        #endif
        Log.error("ContentRuleList could not be compiled: \(reason). The load will be refused (fail closed).")
        assertionFailure("ContentRuleList could not be compiled: \(reason)")
    }

    #if DEBUG
    /// Test-only override for `reportCompileFailure`. When set, a test can run
    /// the fail-closed path without `assertionFailure` killing the test process,
    /// and check that the failure was reported. Leave it nil outside tests.
    @MainActor
    internal static var failureReporterOverride: ((String) -> Void)?
    #endif

    static func identifier(for encoded: String) -> String {
        let digest = SHA256.hash(data: Data(encoded.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "ConnectSDKAllowlist-\(hex.prefix(16))"
    }

    internal static func encodedRules(for hosts: [String]) -> String {
        // Block everything first, then re-allow each configured host.
        var rules: [[String: Any]] = [
            [
                "trigger": ["url-filter": ".*"],
                "action": ["type": "block"],
            ]
        ]
        for host in hosts {
            let escaped = NSRegularExpression.escapedPattern(for: host)
            for scheme in ["https?", "wss?"] {
                // The host has to be followed by a path/port/query/fragment
                // delimiter, or be the end of the string. That is what rejects
                // look-alike hosts such as `connect.xyz.evil.com`.
                //
                // WebKit's content-rule regex engine won't accept an
                // end-of-string anchor inside an alternation group: `([/:?#]|$)`
                // fails to compile with WKErrorDomain error 6. So we emit two
                // separate rules per scheme instead of one alternation.
                let prefix = "^\(scheme)://([^/]+\\.)?\(escaped)"
                for suffix in ["[/:?#]", "$"] {
                    rules.append([
                        "trigger": ["url-filter": "\(prefix)\(suffix)"],
                        "action": ["type": "ignore-previous-rules"],
                    ])
                }
            }
        }
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
