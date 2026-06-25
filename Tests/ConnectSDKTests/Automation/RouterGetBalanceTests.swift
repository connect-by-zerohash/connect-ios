import Testing
import Foundation
@testable import ConnectSDK

@MainActor
@Suite("Router getBalance dispatch")
struct RouterGetBalanceTests {

    @Test("getBalance is coalescable")
    func coalescable() {
        #expect(AutomationWebViewMessageRouter.isCoalescable(operation: "getBalance") == true)
        #expect(AutomationWebViewMessageRouter.isCoalescable(operation: "auth.status") == true)
        #expect(AutomationWebViewMessageRouter.isCoalescable(operation: "getDepositAddress") == false)
    }
}
