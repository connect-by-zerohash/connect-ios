import Testing
@testable import ConnectSDK

@Suite("PlatformRegistry")
struct PlatformRegistryTests {

    private struct StubPlatform: PlatformIdentity {
        let id: String
    }

    @Test("Empty registry returns nil for unknown id")
    func emptyLookup() {
        let r = PlatformRegistry()
        #expect(r["cbase"] == nil)
    }

    @Test("Default-seeded registry exposes seeded platforms")
    func defaultSeeds() {
        let r = PlatformRegistry(default: [StubPlatform(id: "alpha"), StubPlatform(id: "beta")])
        #expect(r["alpha"] != nil)
        #expect(r["beta"] != nil)
        #expect(r["gamma"] == nil)
    }

    @Test("register overwrites")
    func registerOverwrites() {
        let r = PlatformRegistry(default: [StubPlatform(id: "alpha")])
        r.register(StubPlatform(id: "alpha"))
        #expect(r["alpha"] != nil)
    }
}
