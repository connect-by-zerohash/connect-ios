import Testing
import WebKit
@testable import ConnectSDK

@MainActor
@Suite("OffscreenWebViewRunner")
struct OffscreenWebViewRunnerTests {

    @Test("Runs script against an HTML string and returns the value")
    func runHappyPath() async throws {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let html = "<html><body><div id='x'>hello</div></body></html>"
        let result = try await runner.runHTML(
            html: html,
            baseURL: URL(string: "https://example.test/")!,
            script: "document.getElementById('x').textContent",
            timeoutMs: 5_000
        )
        #expect((result as? String) == "hello")
    }

    @Test("tearDown is idempotent")
    func tearDownTwice() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        runner.tearDown()
        runner.tearDown()
        // No assertion beyond "doesn't crash".
    }

    @Test("OffscreenSettleDecision.answer carries an arbitrary payload")
    func settleDecisionAnswerCarriesPayload() {
        let decision: OffscreenSettleDecision = .answer(["loggedIn": false])
        guard case .answer(let payload) = decision else {
            #expect(Bool(false), "expected .answer case")
            return
        }
        let dict = payload as? [String: Bool]
        #expect(dict?["loggedIn"] == false)
    }

    @Test("OffscreenSettleDecision.evaluate and .waitMore are distinct cases")
    func settleDecisionCases() {
        let a: OffscreenSettleDecision = .evaluate
        let b: OffscreenSettleDecision = .waitMore
        if case .evaluate = a { /* ok */ } else { #expect(Bool(false)) }
        if case .waitMore = b { /* ok */ } else { #expect(Bool(false)) }
    }

    @Test("RunnerError.timeout carries a stage")
    func timeoutCarriesStage() {
        let e = RunnerError.timeout(stage: .initialLoad)
        if case .timeout(.initialLoad) = e { /* ok */ } else {
            #expect(Bool(false), "stage not preserved")
        }
    }

    @Test("Existing timeout test still asserts stage on slow-load")
    func timesOutWithStage() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let url = URL(string: "http://192.0.2.1:1/will-hang")!
        do {
            _ = try await runner.run(url: url, script: "1", timeoutMs: 100)
            #expect(Bool(false), "expected timeout")
        } catch let e as RunnerError {
            if case .timeout(let stage) = e {
                #expect(stage == .initialLoad)
            } else {
                #expect(Bool(false), "expected .timeout, got \(e)")
            }
        } catch {
            #expect(Bool(false), "unexpected error type: \(type(of: error))")
        }
    }


    // The original race-reproduction test (`survivesRedirectRace`) was
    // dropped: iOS 17's WebKit blocks the cross-origin data: URL navigation
    // it relied on with `WebKitErrorFrameLoadInterruptedByPolicyChange`
    // (code 102), so the test couldn't exercise the latch race in either
    // the broken or the fixed implementation. The structural fix
    // (generation-counted buffered tracker) is verified by Plan 01 Task 10
    // manual smoke against the live Coinbase host.

    @Test("Settle predicate .answer short-circuits without running JS")
    func settleAnswerShortCircuits() async throws {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let html = "<html><body>noscript</body></html>"
        let result = try await runner.runHTML(
            html: html,
            baseURL: URL(string: "https://terminal.test/")!,
            settle: { url in
                if url.host == "terminal.test" { return .answer(["resolved": true]) }
                return .waitMore
            },
            // Script that would crash if run — proves we never executed it.
            script: "throw new Error('should not run')",
            timeoutMs: 5_000
        )
        let dict = result as? [String: Bool]
        #expect(dict?["resolved"] == true)
    }

    @Test("Settle predicate .evaluate runs the script as before")
    func settleEvaluateRunsScript() async throws {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let html = "<html><body><div id='x'>hello</div></body></html>"
        let result = try await runner.runHTML(
            html: html,
            baseURL: URL(string: "https://example.test/")!,
            settle: { _ in .evaluate },
            script: "document.getElementById('x').textContent",
            timeoutMs: 5_000
        )
        #expect((result as? String) == "hello")
    }

    @Test("Settle predicate .waitMore times out with .navigationSettle stage")
    func settleWaitMoreTimesOut() async {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let html = "<html><body>stuck</body></html>"
        // Total 3s budget: ~1s for cold-start + initial load on iOS 17
        // simulator, leaving ~2s for the .waitMore loop to time out at
        // .navigationSettle. With a too-tight budget the .initialLoad
        // stage would time out first and mask the behaviour we're testing.
        do {
            _ = try await runner.runHTML(
                html: html,
                baseURL: URL(string: "https://stuck.test/")!,
                settle: { _ in .waitMore },
                script: "1",
                timeoutMs: 3_000
            )
            #expect(Bool(false), "expected timeout")
        } catch let e as RunnerError {
            if case .timeout(.navigationSettle) = e { /* ok */ } else {
                #expect(Bool(false), "expected .timeout(.navigationSettle), got \(e)")
            }
        } catch {
            #expect(Bool(false), "unexpected error: \(error)")
        }
    }

    @Test("Cancelling a run via abort() invalidates its generation; later runs are unaffected")
    func cancellingARunInvalidatesGeneration() async throws {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)

        // Kick off a run that will never settle, then abort it.
        let html = "<html><body>stuck</body></html>"
        let abortTask = Task { () -> RunnerError? in
            do {
                _ = try await runner.runHTML(
                    html: html,
                    baseURL: URL(string: "https://stuck.test/")!,
                    settle: { _ in .waitMore },
                    script: "1",
                    timeoutMs: 50_000
                )
                return nil
            } catch let e as RunnerError {
                return e
            } catch {
                return nil
            }
        }
        // Yield enough for the WebView to start loading.
        try await Task.sleep(nanoseconds: 50_000_000)
        runner.abortCurrentRun()

        // The aborted run throws .navigationLost (its waiter was resumed
        // with that error).
        let thrown = await abortTask.value
        if case .navigationLost = thrown {
            /* ok */
        } else {
            #expect(Bool(false), "expected navigationLost, got \(String(describing: thrown))")
        }

        // A fresh run on the same runner instance still works.
        let html2 = "<html><body><div id='x'>ok</div></body></html>"
        let result = try await runner.runHTML(
            html: html2,
            baseURL: URL(string: "https://example.test/")!,
            script: "document.getElementById('x').textContent",
            timeoutMs: 5_000
        )
        #expect((result as? String) == "ok")
    }

    @Test("Two concurrent runs on the same runner are serialised, not interleaved")
    func runsAreSerialised() async throws {
        let cfg = SharedWebViewConfiguration().platformConfiguration()
        let runner = OffscreenWebViewRunner(config: cfg)
        let html1 = "<html><body><script>window.__id='one'</script></body></html>"
        let html2 = "<html><body><script>window.__id='two'</script></body></html>"

        // Two Tasks that each return a typed Sendable result. We can't use
        // `async let` with Any? because of Swift 6 strict-concurrency.
        let a = Task { () -> String? in
            let r = try? await runner.runHTML(
                html: html1, baseURL: URL(string: "https://a.test/")!,
                script: "window.__id", timeoutMs: 5_000
            )
            return r as? String
        }
        let b = Task { () -> String? in
            let r = try? await runner.runHTML(
                html: html2, baseURL: URL(string: "https://b.test/")!,
                script: "window.__id", timeoutMs: 5_000
            )
            return r as? String
        }
        let ra = await a.value
        let rb = await b.value
        // Each run sees its own page, not the other's. Without a serial
        // gate, both runs would race on a single WKWebView and at least one
        // would observe the wrong global.
        let set = Set([ra, rb].compactMap { $0 })
        #expect(set == ["one", "two"])
    }
}
