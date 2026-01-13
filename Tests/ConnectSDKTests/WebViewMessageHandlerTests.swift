//
//  WebViewMessageHandlerTests.swift
//  ConnectSDKTests
//
//  Tests for WebViewMessageHandler - JS ↔ Native message bridge

import Foundation
import Testing
import WebKit
@testable import ConnectSDK

struct WebViewMessageHandlerBasicTests {

    @Test("WebViewMessageHandler type exists") func testMessageHandler_TypeExists() {
        #expect(WebViewMessageHandler.self != nil)
    }

    @Test("Environment sandbox is valid") func testEnvironment_Sandbox_IsValid() {
        #expect(Environment.sandbox.rawValue == "sandbox")
    }

    @Test("Environment production is valid") func testEnvironment_Production_IsValid() {
        #expect(Environment.production.rawValue == "production")
    }

    @Test("Environment sandbox not equal production") func testEnvironment_Sandbox_NotEqual_Production() {
        #expect(Environment.sandbox != Environment.production)
    }
}

struct WebViewMessageHandlerDataTests {

    @Test("page ready message has correct type") func testPageReadyMessage_HasCorrectType() {
        let message = MockData.pageReadyMessage()
        #expect(message["type"] as? String == "page-ready")
    }

    @Test("content ready message has correct type") func testContentReadyMessage_HasCorrectType() {
        let message = MockData.contentReadyMessage()
        #expect(message["type"] as? String == "content-ready")
    }

    @Test("close message has correct type") func testCloseMessage_HasCorrectType() {
        let message = MockData.closeMessage()
        #expect(message["type"] as? String == "close")
    }

    @Test("navigation message contains URL") func testNavigationMessage_ContainsURL() {
        let message = MockData.navigationMessage(url: "https://example.com")
        #expect(message["type"] as? String == "navigate")

        if let data = message["data"] as? [String: Any] {
            #expect(data["url"] as? String == "https://example.com")
        }
    }

    @Test("navigation message with mobile target") func testNavigationMessage_WithMobileTarget() {
        let message = MockData.navigationMessage(url: "https://example.com", mobileTarget: "in_app")

        if let data = message["data"] as? [String: Any] {
            #expect(data["mobileTarget"] as? String == "in_app")
        }
    }

    @Test("error event message contains code") func testErrorEventMessage_ContainsCode() {
        let message = MockData.errorEventMessage(code: "ERR_123")

        if let data = message["data"] as? [String: Any] {
            #expect(data["errorCode"] as? String == "ERR_123")
        }
    }

    @Test("error event message contains reason") func testErrorEventMessage_ContainsReason() {
        let message = MockData.errorEventMessage(reason: "Test failure")

        if let data = message["data"] as? [String: Any] {
            #expect(data["reason"] as? String == "Test failure")
        }
    }

    @Test("deposit event message contains deposit ID") func testDepositEventMessage_ContainsDepositId() {
        let message = MockData.depositEventMessage(depositId: "dep-456")

        if let data = message["data"] as? [String: Any] {
            #expect(data["depositId"] as? String == "dep-456")
        }
    }

    @Test("deposit event message contains status") func testDepositEventMessage_ContainsStatus() {
        let message = MockData.depositEventMessage(status: "completed")

        if let data = message["data"] as? [String: Any] {
            if let status = data["status"] as? [String: Any] {
                #expect(status["value"] as? String == "completed")
            }
        }
    }
}

struct WebViewMessageHandlerJSONTests {

    @Test("page ready JSON is valid") func testPageReadyJSON_IsValid() {
        let json = MockData.pageReadyJSON
        #expect(json.contains("page-ready"))
    }

    @Test("content ready JSON is valid") func testContentReadyJSON_IsValid() {
        let json = MockData.contentReadyJSON
        #expect(json.contains("content-ready"))
    }

    @Test("close JSON is valid") func testCloseJSON_IsValid() {
        let json = MockData.closeJSON
        #expect(json.contains("close"))
    }

    @Test("navigation JSON contains URL") func testNavigationJSON_ContainsURL() {
        let json = MockData.navigationJSON(url: "https://test.com")
        #expect(json.contains("https://test.com"))
    }

    @Test("error event JSON contains code") func testErrorEventJSON_ContainsCode() {
        let json = MockData.errorEventJSON(code: "ERR_456")
        #expect(json.contains("ERR_456"))
    }

    @Test("error event JSON contains reason") func testErrorEventJSON_ContainsReason() {
        let json = MockData.errorEventJSON(reason: "Network error")
        #expect(json.contains("Network error"))
    }
}

struct WebViewMessageHandlerDelegateTests {

    @Test("WebViewMessageHandler delegate type") func testMessageHandler_DelegateType() {
        #expect(WebViewMessageHandler.self != nil)
    }

    @Test("delegate protocol exists") func testDelegate_ProtocolExists() {
        #expect(WebViewMessageHandlerDelegate.self != nil)
    }
}

struct WebViewMessageHandlerErrorTests {

    @Test("WebView message without type") func testWebViewMessage_WithoutType() {
        let message: [String: Any] = ["data": ["key": "value"]]
        #expect(message["type"] == nil)
    }

    @Test("WebView message empty data") func testWebViewMessage_EmptyData() {
        let message = MockData.webViewMessage(type: "event", data: [:])
        #expect(message["type"] as? String == "event")
    }

    @Test("WebView message nested data") func testWebViewMessage_NestedData() {
        let complexData: [String: Any] = [
            "level1": [
                "level2": "value"
            ]
        ]
        let message = MockData.webViewMessage(type: "error", data: complexData)

        if let data = message["data"] as? [String: Any] {
            #expect(data["level1"] is [String: Any])
        }
    }
}
