import Testing
import Foundation
@testable import ConnectSDK

@Suite("ZeroAuthRequest decoding")
struct ZeroAuthRequestDecodingTests {

    @Test("Decodes a well-formed envelope")
    func wellFormed() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"auth.login"}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.id == "r1")
        #expect(req.role == "zeroauth-host")
        #expect(req.platform == "coinbase")
        #expect(req.operation == "auth.login")
        #expect(req.payload == nil)
        #expect(req.sessionId == nil)
    }

    @Test("Decodes payload as opaque JSON")
    func payloadIsOpaque() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"auth.status","payload":{"hello":"world"}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.payload != nil)
    }

    @Test("Rejects missing required field")
    func missingField() throws {
        let json = #"""
        {"id":"r1","platform":"coinbase","operation":"auth.login"}
        """#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        }
    }
}

@Suite("ZeroAuthRequest options.overlayOptions decoding")
struct ZeroAuthRequestOverlayOptionsTests {

    @Test("Decodes full overlayOptions and resolves to exactly those values")
    func fullOverlayOptions() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress",
         "payload":{"asset":"USDC","network":"solana"},
         "options":{"overlayOptions":{"titles":["Fetching your deposit address"],
           "subtitles":["Connecting to Coinbase…"],"cycleMs":3000,
           "branding":"zerohash"}},
         "sessionId":null}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)

        let wire = try #require(req.options?.overlayOptions)
        #expect(wire.titles == ["Fetching your deposit address"])
        #expect(wire.subtitles == ["Connecting to Coinbase…"])
        #expect(wire.cycleMs == 3000)
        #expect(wire.branding == "zerohash")

        // The wire DTO maps cleanly to the resolution-layer Partial...
        let partial = wire.asPartial
        #expect(partial.titles == ["Fetching your deposit address"])
        #expect(partial.subtitles == ["Connecting to Coinbase…"])
        #expect(partial.cycleMs == 3000)
        #expect(partial.branding == "zerohash")

        // ...and resolving a fully-specified Partial yields exactly those values,
        // with colors derived from the brand.
        let resolved = OverlayOptions(resolving: partial)
        #expect(resolved.titles == ["Fetching your deposit address"])
        #expect(resolved.subtitles == ["Connecting to Coinbase…"])
        #expect(resolved.cycleMs == 3000)
        #expect(resolved.brand == .zerohash)
        #expect(resolved.colors == Brand.zerohash.theme.colors)
    }

    @Test("Decodes partial overlayOptions; resolution fills the rest from defaults")
    func partialOverlayOptions() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress",
         "options":{"overlayOptions":{"titles":["Fetching"]}}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)

        let wire = try #require(req.options?.overlayOptions)
        #expect(wire.titles == ["Fetching"])
        #expect(wire.subtitles == nil)
        #expect(wire.cycleMs == nil)
        #expect(wire.branding == nil)

        let partial = wire.asPartial
        #expect(partial.titles == ["Fetching"])
        #expect(partial.subtitles == nil)
        #expect(partial.cycleMs == nil)
        #expect(partial.branding == nil)

        let resolved = OverlayOptions(resolving: partial)
        let d = OverlayOptions.default
        #expect(resolved.titles == ["Fetching"])           // caller-supplied wins
        #expect(resolved.subtitles == d.subtitles)         // default fills the gap
        #expect(resolved.cycleMs == d.cycleMs)
        #expect(resolved.brand == .connect)                // absent branding → default
        #expect(resolved.colors == Brand.connect.theme.colors)
    }

    @Test("Decodes options present but without overlayOptions; resolves to all defaults")
    func optionsWithoutOverlayOptions() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress",
         "options":{"presentation":"popup","initialOverlay":true}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)

        #expect(req.options != nil)
        #expect(req.options?.overlayOptions == nil)

        let resolved = OverlayOptions(resolving: req.options?.overlayOptions?.asPartial)
        #expect(resolved == OverlayOptions.default)
    }

    // MARK: - options.initialOverlay (contract.ts:38-41, 47-49)
    //
    // Contract-intended: the host can opt OUT of the branded loading overlay
    // so the user watches the automation play out on the underlying page.
    // The wire field rides in the top-level `options` (sibling of payload),
    // exactly like overlayOptions. Default when omitted is TRUE (extension
    // default initialOverlay: true) — resolved at the router, not the DTO.

    @Test("Decodes options.initialOverlay:false → RequestOptions.initialOverlay == false")
    func initialOverlayFalse() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress",
         "options":{"initialOverlay":false}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.options?.initialOverlay == false)
    }

    @Test("Decodes options.initialOverlay:true → RequestOptions.initialOverlay == true")
    func initialOverlayTrue() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress",
         "options":{"initialOverlay":true}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.options?.initialOverlay == true)
    }

    @Test("Absent initialOverlay → RequestOptions.initialOverlay == nil (router defaults to true)")
    func initialOverlayAbsent() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress",
         "options":{"overlayOptions":{"titles":["Fetching"]}}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.options != nil)
        #expect(req.options?.initialOverlay == nil)
    }

    @Test("Decodes empty options object; overlayOptions nil")
    func emptyOptionsObject() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"getDepositAddress","options":{}}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.options != nil)
        #expect(req.options?.overlayOptions == nil)
    }

    @Test("Regression: request with NO options at all still decodes; options nil")
    func noOptionsAtAll() throws {
        let json = #"""
        {"id":"r1","role":"zeroauth-host","platform":"coinbase","operation":"auth.login"}
        """#.data(using: .utf8)!
        let req = try JSONDecoder().decode(ZeroAuthRequest.self, from: json)
        #expect(req.options == nil)
    }
}

@Suite("ZeroAuthResponse encoding")
struct ZeroAuthResponseEncodingTests {

    @Test("Encodes success envelope")
    func success() throws {
        let env = ZeroAuthResponse(id: "r1", success: true, data: .bool(true), error: nil, sessionId: nil)
        let data = try JSONEncoder().encode(env)
        let s = String(data: data, encoding: .utf8)!
        #expect(s.contains(#""id":"r1""#))
        #expect(s.contains(#""role":"zeroauth-native""#))
        #expect(s.contains(#""success":true"#))
    }

    @Test("Encodes failure envelope")
    func failure() throws {
        let env = ZeroAuthResponse(id: "r1", success: false, data: nil, error: "boom", sessionId: nil)
        let s = String(data: try JSONEncoder().encode(env), encoding: .utf8)!
        #expect(s.contains(#""success":false"#))
        #expect(s.contains(#""error":"boom""#))
    }
}

@Suite("BridgeEvent encoding")
struct BridgeEventEncodingTests {
    @Test("Encodes correlationId + type")
    func basic() throws {
        let e = BridgeEvent(correlationId: "abc", type: "cancelled", data: nil)
        let s = String(data: try JSONEncoder().encode(e), encoding: .utf8)!
        #expect(s.contains(#""correlationId":"abc""#))
        #expect(s.contains(#""type":"cancelled""#))
    }
}
