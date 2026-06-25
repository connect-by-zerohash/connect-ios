import Testing
import Foundation
@testable import ConnectSDK

@Suite("Environment")
struct EnvironmentTests {
    @Test("sandbox.rawValue is 'sandbox'")
    func sandboxRaw() {
        #expect(Environment.sandbox.rawValue == "sandbox")
    }
    @Test("production.rawValue is 'production'")
    func productionRaw() {
        #expect(Environment.production.rawValue == "production")
    }
    @Test("localDev.rawValue is 'localDev'")
    func localDevRaw() {
        let url = URL(string: "http://192.168.1.42:5181")!
        #expect(Environment.localDev(url).rawValue == "localDev")
    }
}

@Suite("ConnectApp.baseURL(for:)")
struct ConnectAppBaseURLTests {
    @Test(".auth resolves to https://sdk.sandbox.connect.xyz/mobile/#auth on sandbox")
    func authSandbox() {
        let u = ConnectApp.auth.baseURL(for: .sandbox)
        #expect(u == "https://sdk.sandbox.connect.xyz/mobile/#auth")
    }
    @Test(".auth resolves to localDev URL when environment is localDev")
    func authLocalDev() {
        let local = URL(string: "http://192.168.1.42:5181")!
        let u = ConnectApp.auth.baseURL(for: .localDev(local))
        #expect(u == "http://192.168.1.42:5181")
    }
    @Test(".withdrawal resolves correctly on production")
    func withdrawProd() {
        let u = ConnectApp.withdrawal.baseURL(for: .production)
        #expect(u == "https://sdk.connect.xyz/mobile/#withdraw")
    }
}
