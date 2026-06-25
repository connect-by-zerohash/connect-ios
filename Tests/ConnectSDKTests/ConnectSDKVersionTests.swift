import Testing
@testable import ConnectSDK

@Suite("ConnectSDK.version")
struct ConnectSDKVersionTests {
    @Test("version is non-empty and starts with a digit")
    func versionIsSensible() {
        let v = ConnectSDK.version
        #expect(!v.isEmpty)
        #expect(v.first?.isNumber == true)
    }
}
