import Testing
@testable import ConnectSDK

@Suite("PlatformRegistry.shared")
struct PlatformRegistrySharedTests {
    @Test("Default-registered registry contains Coinbase")
    func sharedHasCoinbase() {
        #expect(PlatformRegistry.shared["coinbase"] != nil)
    }
}
