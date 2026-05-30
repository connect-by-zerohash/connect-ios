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
            completion(nil)
            return
        }
        let encoded = encodedRules(for: allowList.hosts)
        let identifier = self.identifier(for: encoded)
        store.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: encoded
        ) { list, _ in
            Task { @MainActor in completion(list) }
        }
    }

    private static func identifier(for encoded: String) -> String {
        let digest = SHA256.hash(data: Data(encoded.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "ConnectSDKAllowlist-\(hex.prefix(16))"
    }

    private static func encodedRules(for hosts: [String]) -> String {
        var rules: [[String: Any]] = [
            [
                "trigger": ["url-filter": ".*"],
                "action": ["type": "block"],
            ]
        ]
        for host in hosts {
            let escaped = NSRegularExpression.escapedPattern(for: host)
            for scheme in ["https?", "wss?"] {
                let pattern = "^\(scheme)://([^/]+\\.)?\(escaped)([/:?#]|$)"
                rules.append([
                    "trigger": ["url-filter": pattern],
                    "action": ["type": "ignore-previous-rules"],
                ])
            }
        }
        let data = (try? JSONSerialization.data(withJSONObject: rules)) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
