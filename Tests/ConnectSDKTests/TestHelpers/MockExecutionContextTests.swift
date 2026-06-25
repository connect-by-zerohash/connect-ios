import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("MockExecutionContext.runVisibleWebView")
struct MockExecutionContextTests {

    @Test("records a VisibleCall with the forwarded args and returns visibleResult")
    func recordsAndReturns() async throws {
        let mock = MockExecutionContext()
        mock.visibleResult = "0xADDRESS"

        let url = URL(string: "https://www.coinbase.com/receive")!
        let overlay = OverlayOptions.default
        let result = try await mock.runVisibleWebView(
            url: url,
            settle: { _ in .evaluate },
            injectedScript: "automation();",
            overlay: overlay,
            showOverlay: true,
            timeoutMs: 30_000
        )

        #expect(result as? String == "0xADDRESS")
        #expect(mock.visibleCalls.count == 1)
        let call = mock.visibleCalls[0]
        #expect(call.url == url)
        #expect(call.script == "automation();")
        #expect(call.overlay == overlay)
        #expect(call.showOverlay == true)
        #expect(call.timeoutMs == 30_000)
        // The forwarded settle predicate is callable.
        if case .evaluate = call.settle(url) {} else {
            Issue.record("expected .evaluate from forwarded settle")
        }
    }

    @Test("throws visibleError when set")
    func throwsWhenErrorSet() async {
        struct Boom: Error {}
        let mock = MockExecutionContext()
        mock.visibleError = Boom()

        await #expect(throws: Boom.self) {
            _ = try await mock.runVisibleWebView(
                url: URL(string: "https://www.coinbase.com/")!,
                settle: { _ in .evaluate },
                injectedScript: "x",
                overlay: .default,
                showOverlay: true,
                timeoutMs: 1000
            )
        }
        // The call is still recorded before throwing.
        #expect(mock.visibleCalls.count == 1)
    }
}
