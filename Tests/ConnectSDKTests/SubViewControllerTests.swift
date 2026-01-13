//
//  SubViewControllerTests.swift
//  ConnectSDK
//

import Foundation
import Testing
import AuthenticationServices
@testable import ConnectSDK

@MainActor
struct SubViewControllerInitializationTests {

    @Test("SubViewController initialization with URL and default theme succeeds")
    func testInitializationDefaultTheme() {
        let vc = SubViewController(urlString: "https://example.com")
        #expect(vc != nil)
    }

    @Test("SubViewController initialization with URL and light theme succeeds")
    func testInitializationLightTheme() {
        let vc = SubViewController(urlString: "https://example.com", theme: .light)
        #expect(vc != nil)
    }

    @Test("SubViewController initialization with URL and dark theme succeeds")
    func testInitializationDarkTheme() {
        let vc = SubViewController(urlString: "https://example.com", theme: .dark)
        #expect(vc != nil)
    }

    @Test("SubViewController initialization with URL and system theme succeeds")
    func testInitializationSystemTheme() {
        let vc = SubViewController(urlString: "https://example.com", theme: .system)
        #expect(vc != nil)
    }
}

@MainActor
struct SubViewControllerLifecycleTests {

    @Test("SubViewController view loads without crashing")
    func testViewLoading() {
        let vc = SubViewController(urlString: "https://example.com")
        let _ = vc.view
        #expect(vc.view != nil)
    }

    @Test("SubViewController multiple instances can be created")
    func testMultipleInstances() {
        let vc1 = SubViewController(urlString: "https://example1.com", theme: .light)
        let vc2 = SubViewController(urlString: "https://example2.com", theme: .dark)
        let vc3 = SubViewController(urlString: "https://example3.com", theme: .system)

        #expect(vc1 != nil)
        #expect(vc2 != nil)
        #expect(vc3 != nil)
    }

    @Test("SubViewController different URLs supported")
    func testDifferentURLs() {
        let vc1 = SubViewController(urlString: "https://api.example.com/page1")
        let vc2 = SubViewController(urlString: "https://api.example.com/page2")

        #expect(vc1 != nil)
        #expect(vc2 != nil)
    }
}
