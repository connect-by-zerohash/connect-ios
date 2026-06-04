//
//  ContentRuleListTests.swift
//  ConnectSDKTests
//
//  Tests for ContentRuleList: allow-list rule generation and the
//  fail-closed compile path.
//
//  In debug builds the compile-failure path hits `assertionFailure`, which
//  would kill the test process. To get around that, these tests set
//  `failureReporterOverride`, which stands in for the assertion so we can check
//  that the path hands `nil` back to the completion and reports the failure.

import Foundation
import Testing
import WebKit
@testable import ConnectSDK

@MainActor
struct ContentRuleListTests {

    // MARK: - Helpers

    /// Parses the encoded rule JSON into a typed structure for assertions.
    private func parseRules(_ json: String) throws -> [[String: Any]] {
        let data = try #require(json.data(using: .utf8))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }

    private func urlFilter(_ rule: [String: Any]) -> String? {
        (rule["trigger"] as? [String: Any])?["url-filter"] as? String
    }

    private func actionType(_ rule: [String: Any]) -> String? {
        (rule["action"] as? [String: Any])?["type"] as? String
    }

    // MARK: - Rule generation (encodedRules)

    @Test("first rule blocks everything")
    func testEncodedRules_BlocksEverythingFirst() throws {
        let rules = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz"]))
        let first = try #require(rules.first)
        #expect(urlFilter(first) == ".*")
        #expect(actionType(first) == "block")
    }

    @Test("emits two allow rules per scheme per host")
    func testEncodedRules_RuleCount() throws {
        // 1 block-all + (2 schemes * 2 suffixes) per host.
        let oneHost = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz"]))
        #expect(oneHost.count == 1 + 4)

        let twoHosts = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz", "zerohash.com"]))
        #expect(twoHosts.count == 1 + 8)

        let empty = try parseRules(ContentRuleList.encodedRules(for: []))
        #expect(empty.count == 1)
    }

    @Test("allow rules use ignore-previous-rules")
    func testEncodedRules_AllowRulesIgnorePrevious() throws {
        let rules = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz"]))
        for rule in rules.dropFirst() {
            #expect(actionType(rule) == "ignore-previous-rules")
        }
    }

    @Test("no allow rule uses an end-anchor inside an alternation group")
    func testEncodedRules_NoDollarInsideAlternation() throws {
        // This is the exact pattern WebKit rejects (WKErrorDomain error 6).
        // Guard against it ever coming back.
        let rules = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz"]))
        for rule in rules {
            let filter = urlFilter(rule) ?? ""
            #expect(!filter.contains("|$)"))
        }
    }

    @Test("allow rules anchor the host with a delimiter or end-of-string")
    func testEncodedRules_HostBoundaryEnforced() throws {
        // Each allow rule must end in a path/port/query/fragment delimiter
        // class or a bare end-of-string anchor. That is what rejects
        // look-alike hosts such as `connect.xyz.evil.com`.
        let rules = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz"]))
        for rule in rules.dropFirst() {
            let filter = try #require(urlFilter(rule))
            #expect(filter.hasSuffix("[/:?#]") || filter.hasSuffix("$"))
            #expect(filter.contains("connect\\.xyz"))
        }
    }

    @Test("covers both http(s) and ws(s) schemes")
    func testEncodedRules_BothSchemes() throws {
        let rules = try parseRules(ContentRuleList.encodedRules(for: ["connect.xyz"]))
        let filters = rules.compactMap(urlFilter)
        #expect(filters.contains { $0.contains("^https?://") })
        #expect(filters.contains { $0.contains("^wss?://") })
    }

    @Test("regex-special characters in hosts are escaped")
    func testEncodedRules_EscapesSpecialCharacters() throws {
        // A literal dot must be escaped so it can't match an arbitrary char.
        let rules = try parseRules(ContentRuleList.encodedRules(for: ["a.b.com"]))
        let filters = rules.compactMap(urlFilter)
        #expect(filters.allSatisfy { !$0.contains("a.b.com") || $0.contains("a\\.b\\.com") })
        #expect(filters.contains { $0.contains("a\\.b\\.com") })
    }

    // MARK: - Host-matching behavior

    /// Returns true if the encoded allow-list would let `urlString` through,
    /// meaning any allow rule (everything after the leading block-all) matches.
    /// This mirrors WebKit's `ignore-previous-rules` behavior: the block-all
    /// fires first, and one matching allow rule overrides it.
    ///
    /// One caveat. WebKit's content-rule regex engine is not
    /// `NSRegularExpression`, and that gap is what hid the original
    /// `$`-in-alternation compile bug (the `testCompile_*` tests cover that
    /// against the real store). So this oracle only checks host-matching
    /// behavior. The patterns it runs use anchors, character classes, and one
    /// optional group, all of which both engines handle the same way, so it is
    /// a fair check of the look-alike-rejection property.
    private func allowListAllows(_ urlString: String, hosts: [String]) throws -> Bool {
        let rules = try parseRules(ContentRuleList.encodedRules(for: hosts))
        for rule in rules.dropFirst() where actionType(rule) == "ignore-previous-rules" {
            let pattern = try #require(urlFilter(rule))
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(urlString.startIndex..., in: urlString)
            if regex.firstMatch(in: urlString, range: range) != nil {
                return true
            }
        }
        return false
    }

    @Test("allow-list admits the exact host and its subdomains")
    func testMatching_AdmitsLegitimateHosts() throws {
        let allowed = [
            "https://connect.xyz",
            "https://connect.xyz/",
            "https://connect.xyz/mobile/#auth",
            "https://sdk.connect.xyz/path",
            "https://connect.xyz:443/x",
            "https://connect.xyz?q=1",
            "https://connect.xyz#frag",
            "wss://connect.xyz/socket",
        ]
        for url in allowed {
            #expect(try allowListAllows(url, hosts: ["connect.xyz"]) == true, "expected ALLOW: \(url)")
        }
    }

    @Test("allow-list rejects look-alike and unrelated hosts")
    func testMatching_RejectsLookAlikeHosts() throws {
        let denied = [
            "https://connect.xyz.evil.com/",       // suffix attack
            "https://evil-connect.xyz/",           // prefix attack
            "https://connectxyz.com/",             // missing dot
            "https://notconnect.xyz/",             // substring host
            "https://connect.xyzz/",               // trailing chars
            "https://evil.com/connect.xyz",        // host in path
            "ftp://connect.xyz/",                  // disallowed scheme
        ]
        for url in denied {
            #expect(try allowListAllows(url, hosts: ["connect.xyz"]) == false, "expected DENY: \(url)")
        }
    }

    // MARK: - Compilation (happy path against the real store)

    /// Awaits `compile`. The completion is invoked on the main actor (the
    /// test type is `@MainActor`), so no cross-actor hop is needed. The
    /// `.timeLimit` trait guards against a hang if the completion never fires.
    private func compile(_ allowList: ConnectAllowList) async -> WKContentRuleList? {
        await withCheckedContinuation { continuation in
            ContentRuleList.compile(for: allowList) { continuation.resume(returning: $0) }
        }
    }

    @Test("compile returns a rule list for the default allow-list", .timeLimit(.minutes(1)))
    func testCompile_ValidAllowList_ReturnsRuleList() async {
        // Regression guard for the `$`-in-alternation compile bug: the default
        // allow-list must actually compile against the real WKContentRuleListStore.
        let ruleList = await compile(.default)
        #expect(ruleList != nil)
    }

    @Test("compile returns a rule list for multiple hosts", .timeLimit(.minutes(1)))
    func testCompile_MultipleHosts_ReturnsRuleList() async {
        let ruleList = await compile(ConnectAllowList(hosts: ["connect.xyz", "zerohash.com", "example.com"]))
        #expect(ruleList != nil)
    }

    // MARK: - Fail-closed path

    @Test("compile fails closed (returns nil) and reports when the rules are invalid", .timeLimit(.minutes(1)))
    func testCompile_InvalidRules_FailsClosedAndReports() async {
        var reportCount = 0
        ContentRuleList.failureReporterOverride = { _ in reportCount += 1 }
        defer { ContentRuleList.failureReporterOverride = nil }

        // Not a valid WKContentRuleList JSON document, so WebKit's compile
        // step rejects it, which runs the fail-closed path against the real store.
        let invalid = "{ not a valid content rule list }"
        let ruleList: WKContentRuleList? = await withCheckedContinuation { continuation in
            ContentRuleList.compileForTesting(encoded: invalid) { continuation.resume(returning: $0) }
        }

        #expect(ruleList == nil)        // fail closed
        #expect(reportCount == 1)       // failure was reported
    }
}
