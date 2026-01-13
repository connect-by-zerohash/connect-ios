# ConnectSDK Unit Tests

Comprehensive unit test suite for the Connect iOS SDK using Swift Testing framework.

## Quick Start

### Run All Tests

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Run Tests with Coverage

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES
```

### Generate Coverage Report

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES -resultBundlePath ./coverage.xcresult && xcrun xccov view --report ./coverage.xcresult
```

### Run Specific Test Suite

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing ConnectSDKTests/ConnectAuthSessionTests
```

## Project Structure

```
Tests/
├── ConnectSDKTests/
│   ├── TestHelpers/
│   │   ├── MockData.swift              # Test fixtures and data factories
│   │   └── MockObjects.swift           # Mock objects (OAuth, WebView, delegates)
│   │
│   ├── ConnectSDKTypesTests.swift      # Types and enums
│   ├── AuthTypesTests.swift            # Authentication types
│   │
│   ├── OAuthHandlerTests.swift         # OAuth flows
│   ├── WebViewMessageHandlerTests.swift # JS ↔ Native messaging
│   ├── WebViewLoadingManagerTests.swift # Loading animation
│   │
│   ├── WebViewControllerTests.swift     # UI orchestration
│   └── ConnectAuthSessionTests.swift    # Session management
│
└── README.md                            
```

## Test Conventions

### Test Descriptions

All tests include a description parameter using `@Test("description")`. Descriptions are short, readable summaries extracted from the test method name:

```swift
// Format: @Test("Subject action/result")
@Test("ConnectApp auth identifier")
func testConnectAppAuthIdentifier() {
    let app = ConnectApp.auth
    #expect(app.identifier == "auth")
}

@Test("ConnectAuthSession present twice returns existing session")
func testConnectAuthSession_PresentTwiceReturnsExistingSession() {
    let session = MockData.connectAuthSession(jwt: MockData.validJWT)
    let presenter = MockUIViewController()

    let firstResult = session.present(from: presenter)
    let secondResult = session.present(from: presenter)

    #expect(firstResult === secondResult)
}

@Test("Theme light value")
func testThemeLightRawValue() {
    let theme = Theme.light
    #expect(theme.rawValue == "light")
}
```

**Description Guidelines:**
- Extract the meaningful part from the function name
- Keep descriptions concise (3-7 words typical)
- Use lowercase except for proper nouns/class names
- Format: subject and action/result
- Examples:
  - `testConnectApp_AuthIdentifier` → `"ConnectApp auth identifier"`
  - `testTheme_AllCasesExists` → `"Theme all cases exist"`
  - `testConnectSession_CanBeClosed` → `"ConnectSession can be closed"`
  - `testWebViewController_InitializationWithValidParameters` → `"WebViewController init valid parameters"`

Benefits:
- ✅ More readable in Xcode test navigator
- ✅ Clearer test report output
- ✅ Better test discovery in CI/CD logs
- ✅ Self-documenting code

### Naming Convention

Methods follow the pattern: `test<Component>_<Scenario>_<Expected>`

```swift
// ✅ Good
@Test("ConnectAuthSession present twice returns existing session")
func testConnectAuthSession_PresentTwiceReturnsExistingSession()

@Test("WebViewController init different environments")
func testWebViewController_InitializationWithDifferentEnvironments()

// ❌ Avoid
@Test("test 1") func test1()
@Test("present") func testPresent()
```

### Test Grouping

Tests are grouped into structs by functionality:

```swift
struct WebViewControllerInitializationTests {
    // Related initialization tests
}

struct WebViewControllerPropertiesTests {
    // Related property tests
}
```

### Assertions

All tests use Swift Testing's `#expect()` macro:

```swift
#expect(session != nil)
#expect(result == true)
#expect(count == 193)
```

## Mock Objects & Fixtures

### MockData Enum

Centralized factory for creating test data:

```swift
// Basic fixtures
MockData.emptyCallbacks
MockData.validJWT
MockData.errorEvent(code: "ERROR_001")

// OAuth & WebView
MockData.oauthCallbackURLWithCode()
MockData.pageReadyMessage()
MockData.navigationMessage(url: "https://example.com")

// Session & Navigation
MockData.connectAuthSession(jwt: MockData.validJWT)
MockData.mockUINavigationController()
MockData.traitCollection(userInterfaceStyle: .dark)
```

### MockObjects File

Reusable mock implementations:

```swift
// OAuth mocking
class MockASWebAuthenticationSession: NSObject {
    func simulateSuccess(with url: URL)
    func simulateFailure(with error: Error)
}

// WebView mocking
class MockWKWebView: WKWebView {
    var evaluatedScripts: [String] = []
    func recordEvaluatedScript(_ script: String, completionHandler: @escaping ...)
}

// UIKit mocking
class MockUIViewController: UIViewController {
    var presentCalled: Bool
    var dismissCalled: Bool
}

// Delegate spying
class WebViewMessageHandlerDelegateSpy: WebViewMessageHandlerDelegate {
    var pageReadyCalls: Int
    var navigateInvocations: [(url: String, mobileTarget: String?)] = []
}
```

## Adding New Tests

### Step 1: Write Test with Description

Always include a description parameter. Start with the test name and extract key components:

```swift
// ✅ Good - Clear, concise description
@Test("MyComponent initialization succeeds")
func testMyComponent_InitializationSucceeds() {
    let component = MyComponent()
    #expect(component != nil)
}

@Test("MyComponent handles invalid input")
func testMyComponent_HandlesInvalidInput() {
    let result = MyComponent.parse(invalidInput)
    #expect(result == nil)
}

// ❌ Avoid - Vague or too long descriptions
@Test("test") func testMyComponent() { }
@Test("tests all initialization scenarios") func testInit() { }
```

### Step 2: Use Existing Fixtures

Always reuse `MockData` factories instead of creating new instances:

```swift
// ✅ Good
let session = MockData.connectAuthSession()
let callbacks = MockData.emptyCallbacks
let jwt = MockData.validJWT

// ❌ Avoid
let callbacks = AuthCallbacks(onClose: nil, onError: nil, ...)
let session = ConnectAuthSession(jwt: "...", environment: .sandbox, ...)
```

### Step 3: Group Related Tests

Create test structs to group related tests and add description to first test:

```swift
struct MyNewFeatureTests {
    @Test("MyFeature initialization")
    func testFeature_Initialization() { }

    @Test("MyFeature normal behavior")
    func testFeature_NormalBehavior() { }

    @Test("MyFeature edge case handling")
    func testFeature_EdgeCase() { }
}
```

### Step 4: Use @MainActor When Needed

Mark test structs with `@MainActor` if they use UIKit classes:

```swift
@MainActor
struct WebViewTests {
    @Test("WebView creation")
    func testWebView_Creation() { }

    @Test("WebView theme application")
    func testWebView_ThemeApplication() { }
}
```

## Common Test Patterns

### Testing Initialization

```swift
@Test("Component initialization with valid parameters")
func testComponent_InitializationWithValidParameters() {
    let component = Component(param: value)
    #expect(component != nil)
}

@Test("Component initialization with different environments")
func testComponent_InitializationWithDifferentEnvironments() {
    let sandboxComponent = Component(env: .sandbox)
    let prodComponent = Component(env: .production)
    #expect(sandboxComponent != nil)
    #expect(prodComponent != nil)
}
```

### Testing Properties

```swift
@Test("Component property can be read")
func testComponent_PropertyCanBeRead() {
    let component = Component(prop: expectedValue)
    #expect(component.prop == expectedValue)
}

@Test("Component stores custom value")
func testComponent_StoresCustomValue() {
    let customValue = "test-value"
    let component = Component(value: customValue)
    #expect(component.value == customValue)
}
```

### Testing Enums

```swift
@Test("Theme all cases have raw values")
func testTheme_AllCasesHaveRawValues() {
    #expect(Theme.light.rawValue == "light")
    #expect(Theme.dark.rawValue == "dark")
    #expect(Theme.system.rawValue == "system")
}

@Test("Environment sandbox and production differ")
func testEnvironment_CasesAreDifferent() {
    #expect(Environment.sandbox != Environment.production)
}
```

### Testing Error Handling

```swift
@Test("Component handles invalid input")
func testComponent_InvalidInputReturnsError() {
    let result = Component.parse(invalidInput)
    #expect(result == nil)
}

@Test("Component gracefully handles nil input")
func testComponent_HandlesNilInput() {
    let result = Component.process(nil)
    #expect(result == nil)
}
```

### Testing Callbacks

```swift
@Test("Component calls close callback on success")
func testComponent_CallsCallbackOnSuccess() {
    var callbackCalled = false
    let callbacks = AuthCallbacks(onClose: {
        callbackCalled = true
    })

    // Trigger callback

    #expect(callbackCalled == true)
}

@Test("Component invokes error callback with data")
func testComponent_InvokesErrorCallback() {
    var errorData: [String: Any]?
    let callbacks = AuthCallbacks(onError: { error in
        errorData = error.data
    })

    // Trigger error callback

    #expect(errorData != nil)
}
```

## Running Tests in Different Ways

### Run All Tests (Verbose)

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -verbose
```

### Run Tests with Detailed Logging

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES -resultBundlePath ./coverage.xcresult
```

### Run Specific Test Suite

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing ConnectSDKTests/WebViewControllerInitializationTests
```

### Run Specific Test

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing ConnectSDKTests/WebViewControllerInitializationTests/testWebViewController_InitializationWithValidParameters
```

## Code Coverage

### Improve Coverage

To improve coverage:

1. **Identify uncovered lines:** Run tests with coverage and inspect results
2. **Add edge case tests:** Test boundary conditions and error paths
3. **Test error scenarios:** Don't just test the happy path
4. **Test state transitions:** Verify before/after states

### Generate Detailed Coverage Report

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -enableCodeCoverage YES -resultBundlePath ./coverage.xcresult

# View coverage in Xcode
open coverage.xcresult
```

## Troubleshooting

### Tests Won't Compile

**Issue:** `@MainActor` sendability errors

**Solution:** Add `@MainActor` annotation to test struct:

```swift
@MainActor
struct MyTests {
    @Test func testSomething() { }
}
```

### Tests Hang

**Issue:** Tests seem to run indefinitely

**Solution:** Check for infinite loops or missing expectations. Add timeout:

```bash
xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -timeout 60
```

### UIViewController Tests Fail

**Issue:** "Modifying properties off the main thread"

**Solution:** Mark test struct with `@MainActor`:

```swift
@MainActor
struct UITests {
    @Test func testUIComponent() { }
}
```

### Mock Objects Not Available

**Issue:** Import error for mock objects

**Solution:** Ensure `@testable import ConnectSDK` is at the top of test file:

```swift
import Foundation
import Testing
import UIKit
@testable import ConnectSDK
```

## Best Practices

✅ **Do:**
- Add `@Test("description")` to every test with clear, concise descriptions
- Use `MockData` factories for all test data
- Group related tests in structs
- Follow naming convention: `test<Component>_<Scenario>_<Expected>`
- Extract description from method name (last meaningful part)
- Test both happy path and error cases
- Use `@MainActor` for UIKit tests
- Keep tests focused on one concern
- Reuse mock objects instead of creating new ones
- Use present tense in descriptions ("component creates", not "component created")

❌ **Don't:**
- Omit `@Test("description")` parameter
- Use vague descriptions like "test", "verify", or "check"
- Write descriptions longer than 7-8 words typically
- Create test data inline (use `MockData`)
- Mix multiple concerns in one test
- Use cryptic variable names
- Skip error case testing
- Create duplicate mock objects
- Use `XCTest` patterns (use Swift Testing)
- Ignore `@MainActor` errors
- Use ALL_CAPS or excessive punctuation in descriptions

## Contributing

When adding new tests:

1. Follow the established patterns in this README
2. Use the naming convention for test methods
3. Group tests in structs by functionality
4. Reuse fixtures from `MockData`
5. Add mock objects to `MockObjects.swift` if needed
6. Run full test suite before committing: `xcodebuild test -scheme ConnectSDK -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
7. Verify coverage didn't decrease significantly

## References

- **Framework:** [Swift Testing](https://developer.apple.com/documentation/testing)
- **Swift Version:** 6.0+
- **iOS Target:** 13.0+
- **Simulator:** iPhone 15 Pro or higher recommended
