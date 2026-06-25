import Testing
@testable import ConnectSDK

@Suite("OverlayOptions")
struct OverlayOptionsTests {

    // The defaults must match DEFAULT_OVERLAY_OPTIONS in the wire contract
    // byte-for-byte, including the curly apostrophe (U+2019) in the subtitle.
    private let defaultSubtitle = "We\u{2019}re securely accessing your account."

    @Test("default mirrors DEFAULT_OVERLAY_OPTIONS exactly")
    func defaultMatchesWireContract() {
        let d = OverlayOptions.default
        #expect(d.titles == ["Almost there"])
        #expect(d.subtitles == [defaultSubtitle])
        #expect(d.cycleMs == 5000)
        #expect(d.brand == .connect)
        #expect(d.colors == Brand.connect.theme.colors)
    }

    @Test("resolving an empty partial yields the defaults")
    func resolveEmptyYieldsDefaults() {
        let resolved = OverlayOptions(resolving: .init())
        #expect(resolved == OverlayOptions.default)
    }

    @Test("resolving a nil partial yields the defaults")
    func resolveNilYieldsDefaults() {
        let resolved = OverlayOptions(resolving: nil)
        #expect(resolved == OverlayOptions.default)
    }

    @Test("titles override but subtitles fall back to default")
    func titlesOverrideSubtitlesDefault() {
        let resolved = OverlayOptions(resolving: .init(titles: ["Hold tight", "One sec"]))
        #expect(resolved.titles == ["Hold tight", "One sec"])
        #expect(resolved.subtitles == [defaultSubtitle])
    }

    @Test("empty arrays count as omitted and fall back to defaults")
    func emptyArraysFallBack() {
        let resolved = OverlayOptions(resolving: .init(titles: [], subtitles: []))
        #expect(resolved.titles == ["Almost there"])
        #expect(resolved.subtitles == [defaultSubtitle])
    }

    @Test("cycleMs override is honored")
    func cycleMsOverride() {
        let resolved = OverlayOptions(resolving: .init(cycleMs: 1234))
        #expect(resolved.cycleMs == 1234)
        // unrelated fields untouched
        #expect(resolved.titles == ["Almost there"])
    }

    @Test("nil cycleMs falls back to default")
    func cycleMsNilFallsBack() {
        let resolved = OverlayOptions(resolving: .init(cycleMs: nil))
        #expect(resolved.cycleMs == 5000)
    }

    @Test("branding selects the brand palette: zerohash")
    func brandingZerohash() {
        let resolved = OverlayOptions(resolving: .init(branding: "zerohash"))
        #expect(resolved.brand == .zerohash)
        #expect(resolved.colors == Brand.zerohash.theme.colors)
        // Copy/timing untouched by branding.
        #expect(resolved.titles == ["Almost there"])
        #expect(resolved.cycleMs == 5000)
    }

    @Test("branding: connect resolves the connect palette")
    func brandingConnect() {
        let resolved = OverlayOptions(resolving: .init(branding: "connect"))
        #expect(resolved.brand == .connect)
        #expect(resolved.colors == Brand.connect.theme.colors)
    }

    @Test("absent branding falls back to the default brand (connect)")
    func brandingAbsentFallsBack() {
        let resolved = OverlayOptions(resolving: .init(branding: nil))
        #expect(resolved.brand == .connect)
        #expect(resolved.colors == Brand.connect.theme.colors)
    }

    @Test("unknown/empty branding coerces to the default brand")
    func brandingUnknownCoercesToDefault() {
        #expect(OverlayOptions(resolving: .init(branding: "zerohsh")).brand == .connect)
        #expect(OverlayOptions(resolving: .init(branding: "")).brand == .connect)
        #expect(OverlayOptions(resolving: .init(branding: "ZeroHash")).brand == .connect)
    }
}
