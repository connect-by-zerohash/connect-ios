import Testing
import UIKit
@testable import ConnectSDK

@MainActor
@Suite("LoadingOverlayView")
struct LoadingOverlayViewTests {

    @Test("Inits with resolved options and exposes them")
    func initsWithOptions() {
        let view = LoadingOverlayView(options: .default)
        #expect(view.options == OverlayOptions.default)
    }

    @Test("Pins to its superview when added as a subview")
    func pinsToSuperview() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let view = LoadingOverlayView(options: .default)
        host.addSubview(view)
        view.pinToSuperview()
        host.layoutIfNeeded()
        #expect(view.translatesAutoresizingMaskIntoConstraints == false)
        #expect(view.frame == host.bounds)
    }

    @Test("start/stop are idempotent and do not crash")
    func startStopSafe() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        // Multi-message options so the cycle timer actually starts.
        let opts = OverlayOptions(
            titles: ["One", "Two"],
            subtitles: ["A", "B"],
            cycleMs: 10,
            brand: .connect
        )
        let view = LoadingOverlayView(options: opts)
        host.addSubview(view)
        view.pinToSuperview()
        view.start()
        view.start() // idempotent
        view.stop()
        view.stop() // idempotent
    }

    @Test("Displays the first title and subtitle initially")
    func showsFirstMessage() {
        let opts = OverlayOptions(
            titles: ["Hello", "World"],
            subtitles: ["First", "Second"],
            cycleMs: 5000,
            brand: .connect
        )
        let view = LoadingOverlayView(options: opts)
        #expect(view.currentTitleText == "Hello")
        #expect(view.currentSubtitleText == "First")
    }

    // MARK: - Theming (AUTH-3365)

    @Test("Light theme uses the white background and dark primary text")
    func lightThemeColors() {
        let view = LoadingOverlayView(options: .default, theme: .light)
        #expect(view.backgroundColor == UIColor(hexString: "#ffffff"))
        #expect(view.titleLabel.textColor == UIColor(hexString: "#111827"))
    }

    @Test("Dark theme uses the dark background and white primary text")
    func darkThemeColors() {
        let view = LoadingOverlayView(options: .default, theme: .dark)
        // Explicit themes ignore the trait collection, so this holds regardless
        // of the test host's appearance.
        #expect(view.backgroundColor == Theme.darkBackgroundColor)
        #expect(view.titleLabel.textColor == .white)
    }
}
