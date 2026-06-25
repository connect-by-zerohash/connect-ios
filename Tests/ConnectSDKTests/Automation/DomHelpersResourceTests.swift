import XCTest
@testable import ConnectSDK

/// Verifies the shared dom-helpers.js resource ships in the SDK bundle and
/// exposes the expected window.__zhDom surface. (Static string assertions —
/// no WebView/JS execution, which xcodebuild-tests can't reliably evaluate.)
final class DomHelpersResourceTests: XCTestCase {
    /// Loads the bundled dom-helpers.js via the SDK's own resource bundle.
    ///
    /// The resource lives in the ConnectSDK (main) target, so the test target's
    /// `Bundle.module` does not contain it. `Coinbase.resourceBundle` returns the
    /// SDK target's `Bundle.module` — the exact bundle the production loaders use —
    /// so this test exercises the real resource path without hardcoding the
    /// SwiftPM-generated bundle name.
    private func loadHelpers() throws -> String {
        let url = try XCTUnwrap(
            Coinbase.resourceBundle.url(forResource: "dom-helpers", withExtension: "js"),
            "dom-helpers.js must be bundled (Package.swift .process)"
        )
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testResourceIsBundled() throws {
        let body = try loadHelpers()
        XCTAssertFalse(body.isEmpty)
    }

    func testDefinesZhDomNamespace() throws {
        let body = try loadHelpers()
        XCTAssertTrue(body.contains("window.__zhDom ="))
    }

    func testExposesExpectedHelpers() throws {
        let body = try loadHelpers()
        for key in ["sleep:", "waitUntil:", "waitFor:", "realisticClick:",
                    "findButtonByText:", "clickableAncestor:"] {
            XCTAssertTrue(body.contains(key), "missing helper export: \(key)")
        }
    }
}
