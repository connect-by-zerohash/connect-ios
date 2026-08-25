//
//  ConnectAllowListTests.swift
//  ConnectSDKTests
//
//  Tests for `ConnectAllowList.contains(host:)` matching and the default list.
//
//  The matcher admits a host when it equals an allow-list entry or is a
//  subdomain of one (i.e. ends with `"." + entry`), case-insensitively. The
//  look-alike cases below are the security-critical part: a trusted label
//  appearing anywhere other than at a dot-delimited suffix boundary must be
//  rejected (mirrors the look-alike guards in `ContentRuleListTests`).
//

import Foundation
import Testing

@testable import ConnectSDK

struct ConnectAllowListTests {

    // MARK: - Exact-host matches

    @Test(
        "admits an exact host match",
        arguments: [
            "connect.xyz",
            "zerohash.com",
            "gemini.com",
            "robinhood.com",
        ])
    func admitsExactHost(host: String) {
        #expect(ConnectAllowList.default.contains(host: host))
    }

    // MARK: - Subdomain matches

    @Test(
        "admits subdomains of an allowed host",
        arguments: [
            "sdk.connect.xyz",
            "api.zerohash.com",
            "www.gemini.com",  // real Gemini host used by the deposit flow
            "login.gemini.com",  // real Gemini sign-in host
            "exchange.gemini.com",
            "www.robinhood.com",
            "a.b.c.connect.xyz",  // arbitrary subdomain depth
        ])
    func admitsSubdomains(host: String) {
        #expect(ConnectAllowList.default.contains(host: host))
    }

    // MARK: - Case-insensitivity

    @Test("matching is case-insensitive on the host argument")
    func caseInsensitiveHost() {
        #expect(ConnectAllowList.default.contains(host: "GEMINI.COM"))
        #expect(ConnectAllowList.default.contains(host: "Login.Gemini.Com"))
        #expect(ConnectAllowList.default.contains(host: "CONNECT.XYZ"))
    }

    @Test("matching is case-insensitive on the allow-list entry")
    func caseInsensitiveEntry() {
        let list = ConnectAllowList(hosts: ["GEMINI.COM"])
        #expect(list.contains(host: "gemini.com"))
        #expect(list.contains(host: "login.gemini.com"))
    }

    // MARK: - Look-alike / spoof rejection

    @Test(
        "rejects look-alike and unrelated hosts",
        arguments: [
            "gemini.com.evil.com",  // trusted label as a non-suffix segment
            "robinhood.com.attacker.io",  // trusted label as a non-suffix segment
            "evilgemini.com",  // shares the suffix but no dot boundary
            "notrobinhood.com",  // shares the suffix but no dot boundary
            "evil-connect.xyz",  // prefix attack, non-dot boundary
            "connectxyz.com",  // missing dot
            "gemini.org",  // wrong TLD
            "coinbase.com",  // handled by CoinbaseHostPolicy, not this list
            "xyz",  // unrelated
            "",  // empty host
        ])
    func rejectsLookAlikes(host: String) {
        #expect(!ConnectAllowList.default.contains(host: host))
    }

    // MARK: - Custom & empty allow-lists

    @Test("an empty allow-list admits nothing")
    func emptyListAdmitsNothing() {
        let list = ConnectAllowList(hosts: [])
        #expect(!list.contains(host: "connect.xyz"))
        #expect(!list.contains(host: "gemini.com"))
    }

    @Test("a custom allow-list only admits its own hosts and their subdomains")
    func customList() {
        let list = ConnectAllowList(hosts: ["example.com"])
        #expect(list.contains(host: "example.com"))
        #expect(list.contains(host: "sub.example.com"))
        #expect(!list.contains(host: "connect.xyz"))
        #expect(!list.contains(host: "gemini.com"))
    }

    @Test("default list includes the SDK shell and partner exchange hosts")
    func defaultListContents() {
        // Regression guard: the AUTH-3864 exchange hosts (Gemini/Robinhood)
        // must stay in the default list alongside the SDK web-shell hosts.
        let expected = [
            "connect.xyz", "zerohash.com", "gemini.com", "robinhood.com",
            "dynamicauth.com", "dynamic-static-assets.com", "dynamic.xyz",
            "walletconnect.org", "walletconnect.com", "web3modal.org",
            "ton.org",
        ]
        for host in expected {
            #expect(ConnectAllowList.default.hosts.contains(host), "missing default host: \(host)")
        }

        // Dynamic serves from subdomains (app./logs./relay.), which the
        // dot-suffix match must cover from the base-domain entry.
        #expect(ConnectAllowList.default.contains(host: "app.dynamicauth.com"))
        #expect(ConnectAllowList.default.contains(host: "config.ton.org"))
        // WalletConnect / Reown reach the relay, verify, pulse, and catalog
        // hosts from subdomains of the base entries.
        #expect(ConnectAllowList.default.contains(host: "relay.walletconnect.org"))
        #expect(ConnectAllowList.default.contains(host: "verify.walletconnect.org"))
        #expect(ConnectAllowList.default.contains(host: "pulse.walletconnect.org"))
        #expect(ConnectAllowList.default.contains(host: "rpc.walletconnect.com"))
        #expect(ConnectAllowList.default.contains(host: "api.web3modal.org"))
    }
}
