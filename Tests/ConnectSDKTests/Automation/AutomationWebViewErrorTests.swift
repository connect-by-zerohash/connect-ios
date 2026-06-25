import Testing
@testable import ConnectSDK

@Suite("AutomationWebViewError retryable")
struct AutomationWebViewErrorTests {

    @Test("BALANCES_INDETERMINATE is retryable")
    func indeterminateRetryable() {
        let e = AutomationWebViewError.platformThrew(
            "BALANCES_INDETERMINATE: CryptoQuery — could not load a complete response")
        #expect(e.retryable == true)
    }

    @Test("CHALLENGE_UNSOLVED is retryable")
    func challengeRetryable() {
        #expect(AutomationWebViewError.platformThrew("CHALLENGE_UNSOLVED").retryable == true)
    }

    @Test("NOT_LOGGED_IN and other errors are not retryable")
    func othersNotRetryable() {
        #expect(AutomationWebViewError.platformThrew("not logged in").retryable == false)
        #expect(AutomationWebViewError.cancelled.retryable == false)
        #expect(AutomationWebViewError.invalidEnvelope.retryable == false)
    }
}
