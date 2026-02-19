# Testing Guide

This project has two types of tests: **Unit Tests** and **UI Tests**. They use different frameworks, live in different targets, and test different things.

---

## Quick Comparison

| | Unit Tests | UI Tests |
|---|---|---|
| **Framework** | Swift Testing (`import Testing`) | XCTest (`import XCTest`) |
| **Target** | `KeyokuUnitTests/` | `KeyokuUITests/` |
| **What they test** | Code in isolation (managers, models, logic) | The running app in a simulator |
| **Speed** | Fast (milliseconds) | Slow (seconds per test) |
| **Define a test** | `@Test func name()` | `func testName()` (must start with `test`) |
| **Group tests** | `@Suite("Name") struct { }` | `class Name: XCTestCase { }` |
| **Assert** | `#expect(condition)` | `XCTAssertTrue(condition)` |
| **Assert throws** | `#expect(throws: ErrorType.self) { }` | — |
| **Async tests** | `@Test func name() async throws` | `func testName() async throws` |
| **Run all** | Cmd+U (or Test Navigator → play) | Cmd+U (or Test Navigator → play) |
| **Run one** | Click diamond next to test in gutter | Click diamond next to test in gutter |

---

## Unit Tests (Swift Testing)

Unit tests verify that individual pieces of code work correctly **in isolation** — no simulator, no UI, no network. They're fast and reliable.

### Where They Live

```
KeyokuUnitTests/
├── KeyokuUnitTests.swift          # AuthManager tests (10 tests)
├── FlashcardManagerTests.swift    # Deck/Flashcard CRUD, auth lifecycle, models (28 tests)
├── StreakTests.swift              # Streak manager, freezes, config, data (29 tests)
└── MockLogService.swift           # Shared mock for analytics verification
```

### Anatomy of a Unit Test

```swift
import Testing
@testable import Keyoku      // Access internal types

@Suite("FlashcardManager — Deck CRUD")  // Groups related tests
@MainActor                              // Required when testing @MainActor types
struct FlashcardManagerDeckTests {

    // HELPER — returns a tuple: (manager, mockLog)
    // MockLogService captures every analytics event so we can
    // verify tracking alongside state changes.
    private func makeManager(
        decks: [DeckModel] = [],
        mockLog: MockLogService = MockLogService()
    ) -> (FlashcardManager, MockLogService) {
        let logManager = LogManager(services: [mockLog])
        let manager = FlashcardManager(services: MockFlashcardServices(decks: decks), logManager: logManager)
        return (manager, mockLog)
    }

    @Test("Creating a deck adds it and tracks events")
    func createDeck() throws {
        // GIVEN — set up the scenario
        let (manager, mockLog) = makeManager()

        // WHEN — perform the action
        try manager.createDeck(name: "Test", sourceText: "text")

        // THEN — verify the result
        #expect(manager.decks.count == 1)
        #expect(manager.decks[0].name == "Test")

        // AND — verify analytics events were tracked
        #expect(mockLog.hasEvent(named: "FlashcardMan_CreateDeck_Start"))
        #expect(mockLog.hasEvent(named: "FlashcardMan_CreateDeck_Success"))
    }
}
```

### Key Concepts

**GIVEN / WHEN / THEN** — Every test follows this pattern:
- **GIVEN** — Set up mocks, create objects, configure state
- **WHEN** — Call the method you're testing
- **THEN** — Assert the expected result with `#expect(...)`

**@MainActor** — Required on test suites that test `@MainActor` types (like managers and presenters). Without it, you'll get concurrency errors.

**@testable import** — Lets you access `internal` types (the default access level). Without `@testable`, you can only access `public` types.

**Mock services** — The app's managers use protocol-based services. For testing, we use mock implementations that store data in memory instead of hitting Firebase:
- `MockAuthService` — In-memory auth (from SwiftfulAuthenticating)
- `MockFlashcardServices` — In-memory deck storage (MockDeckPersistence + MockRemoteDeckService)
- `MockStreakServices` — In-memory streaks (from SwiftfulGamification)
- `MockLogService` — Captures all tracked analytics events in memory for verification

### MockLogService & Analytics Verification

Every manager tracks analytics events via `LogManager`. To verify these events fire correctly, tests inject a `MockLogService` that captures every event:

```swift
// MockLogService conforms to LogService and stores events in an array
class MockLogService: LogService {
    var events: [AnyLoggableEvent] = []

    func trackEvent(event: LoggableEvent) {
        events.append(AnyLoggableEvent(
            eventName: event.eventName,
            parameters: event.parameters,
            type: event.type
        ))
    }

    func hasEvent(named name: String) -> Bool {
        events.contains { $0.eventName == name }
    }
    // ... also captures identifyUser, addUserProperties, trackScreenView
}
```

**The makeManager tuple pattern** — Every test suite's `makeManager` helper returns `(Manager, MockLogService)`:

```swift
private func makeManager(
    mockLog: MockLogService = MockLogService()
) -> (AuthManager, MockLogService) {
    let logManager = LogManager(services: [mockLog])
    let manager = AuthManager(service: MockAuthService(user: nil), logger: logManager)
    return (manager, mockLog)
}
```

- Use `let (manager, _) = makeManager()` when you don't need to check events
- Use `let (manager, mockLog) = makeManager()` when you want to verify analytics
- Always verify both `_Start` and `_Success` events for operations that track them

### Common Assertions

```swift
// Value checks
#expect(value == expected)
#expect(value != nil)
#expect(array.isEmpty)
#expect(array.count == 3)

// Boolean checks
#expect(user.isAnonymous == true)
#expect(!manager.decks.isEmpty)

// Error handling
#expect(throws: (any Error).self) {
    try someThrowingFunction()
}

// Async operations
@Test func asyncTest() async throws {
    try await manager.logIn(userId: "user123")
    #expect(!manager.decks.isEmpty)
}
```

### Testing Async Code

Many managers have async methods (network calls, database operations). In tests with mock services, these complete instantly but still need `async/await`:

```swift
@Test("Login loads decks and tracks events")
func loginSyncsDecks() async throws {
    let mockLog = MockLogService()
    let logManager = LogManager(services: [mockLog])
    let manager = FlashcardManager(services: MockFlashcardServices(decks: DeckModel.mocks), logManager: logManager)

    // async method — needs try await even with mocks
    try await manager.logIn(userId: "user123")

    #expect(!manager.decks.isEmpty)

    // verify analytics events were tracked
    #expect(mockLog.hasEvent(named: "FlashcardMan_LogIn_Start"))
    #expect(mockLog.hasEvent(named: "FlashcardMan_LogIn_Success"))
}
```

### When to Use Unit Tests

- Testing manager logic (CRUD operations, state changes)
- Testing model properties and computed values
- Testing error paths (what happens when things fail)
- Testing data transformations and business logic
- Testing lifecycle flows (login → action → logout → login)

---

## UI Tests (XCTest)

UI tests launch the **actual app** in a simulator and interact with it like a real user — tapping buttons, swiping, typing, and checking what's on screen.

### Where They Live

```
KeyokuUITests/
├── KeyokuUITests.swift              # Onboarding flow + signed-in state tests (3 flow tests)
└── KeyokuUITestsLaunchTests.swift   # Launch screenshot test
```

### How the App Supports UI Testing

The app has a built-in testing mode controlled by launch arguments:

```
AppDelegate.swift:
  1. Checks Utilities.isUITesting
  2. If true → forces .mock(isSignedIn:) config (no Firebase)
  3. Checks for "SIGNED_IN" launch argument
  4. KeyokuApp shows AppViewForUITesting
```

This means UI tests can control the app's starting state:
- **`["UI_TESTING"]`** → Onboarding mode (signed out, mock data)
- **`["UI_TESTING", "SIGNED_IN"]`** → Main app (signed in, mock data)

**Important:** `"UI_TESTING"` is **always required**. Without it, `Utilities.isUITesting` is `false` and the app runs in its normal (non-mock) mode, ignoring all other test arguments.

### Anatomy of a UI Test

**Key pattern**: Use a local `let app` in each test instead of a class property. This avoids `@MainActor` / `nonisolated` concurrency conflicts with XCTestCase's setUp/tearDown overrides.

```swift
import XCTest

@MainActor
final class KeyokuUITests: XCTestCase {

    // setUp only sets continueAfterFailure — no app property
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingFlow() throws {
        // Each test creates its own local app
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]  // "UI_TESTING" is REQUIRED
        app.launch()

        // Verify welcome screen
        let title = app.staticTexts["Keyoku"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))

        // Navigate through the flow
        app.buttons["StartButton"].tap()
        // ... continue testing the full flow
    }

    func testSignedInFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "SIGNED_IN"]
        app.launch()

        // Verify main app tabs are visible
        let homeTab = app.descendants(matching: .any)["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 10))
    }
}
```

**Why local `let app`?** — `XCUIApplication()` init is `@MainActor`-isolated. Using it as a class property requires setUp/tearDown to access it, but those are `nonisolated` overrides from XCTestCase. This causes Swift concurrency warnings/errors. Local variables in each test method avoid the problem entirely.

### Finding Elements (XCUIElementQuery)

The XCUI element type depends on the **SwiftUI view type**, not just visible text:

| SwiftUI View | XCUI Query | Example |
|---|---|---|
| `Text("Hello")` | `app.staticTexts["Hello"]` | Plain text labels |
| `Button("Tap")` / `.anyButton()` | `app.buttons["Tap"]` | Buttons and tappable views |
| `Link("Terms")` | `app.descendants(matching: .any)["Terms"]` | SwiftUI Link views (type varies by iOS) |
| `TextField("Name")` | `app.textFields["Name"]` | Text input fields |
| `NavigationBar` | `app.navigationBars["Title"]` | Nav bars |
| `TabBar` | `app.tabBars` | Tab bars |
| `.accessibilityIdentifier("ID")` | `app.buttons["ID"]` | Custom test anchors |

**Common gotcha**: If a `Text` is wrapped in `.anyButton(.press)` or `.asButton()`, it becomes a **button** in the accessibility hierarchy, not a `staticText`. If a test fails saying an element doesn't exist, it's probably under a different element type.

**Debugging tip**: Add `print(app.debugDescription)` to dump the full accessibility hierarchy and see exactly what elements exist and what type they are.

### Finding Elements by Partial Match

When you can't match the exact label (e.g., localized text, dynamic content, or text with markdown formatting):

```swift
// Partial match using NSPredicate
let signInButton = app.buttons.containing(
    NSPredicate(format: "label CONTAINS[c] %@", "Sign in")
)
XCTAssertTrue(signInButton.firstMatch.waitForExistence(timeout: 5))
```

### Using Accessibility Identifiers

Accessibility identifiers are the most reliable way to find elements in UI tests. They don't change with localization and are unique by design:

```swift
// In your SwiftUI view:
Text("Get Started")
    .accessibilityIdentifier("StartButton")

// In your UI test:
let button = app.buttons["StartButton"]
button.tap()
```

**When to add identifiers**:
- Buttons that trigger navigation or important actions
- Elements with dynamic or localized text
- Elements you'll need to find in multiple tests

### Interacting with Elements

```swift
// Tapping
element.tap()

// Swiping (for carousels, lists, etc.)
app.swipeLeft()
app.swipeRight()
app.swipeUp()
app.swipeDown()

// Typing
textField.tap()
textField.typeText("Hello world")

// Clearing and typing
textField.tap()
textField.clearAndEnterText("New value")  // Requires custom extension
```

### Waiting for Elements

UI tests need to wait for animations, network calls, and screen transitions:

```swift
// Wait up to 5 seconds for an element to appear
let element = app.staticTexts["Title"]
XCTAssertTrue(element.waitForExistence(timeout: 5))

// Check if something exists right now (no waiting)
XCTAssertTrue(element.exists)

// Check if something is visible AND tappable
XCTAssertTrue(element.isHittable)
```

**Rule of thumb**: Always use `waitForExistence(timeout:)` after any action that triggers a screen transition or animation. Use `exists` only for elements already known to be on screen.

### Common Assertions

```swift
// Element is visible
XCTAssertTrue(element.waitForExistence(timeout: 5), "Description of what should be visible")

// Element is NOT visible
XCTAssertFalse(element.exists, "Description of what should NOT be visible")

// Element has specific text
XCTAssertEqual(element.label, "Expected Text")

// Element count
XCTAssertEqual(app.buttons.count, 3)
```

### Launch Arguments Reference

| Arguments | Effect |
|---|---|
| `["UI_TESTING"]` | Onboarding mode — signed out, mock data |
| `["UI_TESTING", "SIGNED_IN"]` | Main app — signed in, mock decks loaded |

**`"UI_TESTING"` must always be included.** It activates `Utilities.isUITesting`, which tells `AppDelegate` to use mock config instead of Firebase. Without it, all other arguments are ignored.

To add new launch arguments:
1. Check for them in `AppDelegate.swift` (in the `isUITesting` block)
2. Or in `AppViewForUITesting.swift` (using `processInfoContains`)
3. Set them in tests via `app.launchArguments = ["UI_TESTING", "ARG1", "ARG2"]`

### When to Use UI Tests

- Testing navigation flows (onboarding, tab switching)
- Verifying screen content appears correctly
- Testing user interaction sequences (tap → type → submit)
- Testing that signed-in vs. signed-out states show the right screens
- End-to-end smoke tests (does the whole flow work?)

---

## File Organization

Keep test files focused and under 750 lines (SwiftLint rule):

```
KeyokuUnitTests/
├── KeyokuUnitTests.swift          # Auth tests
├── FlashcardManagerTests.swift    # Core CRUD tests
└── StreakTests.swift              # Gamification tests

KeyokuUITests/
├── KeyokuUITests.swift            # Flow tests (onboarding, signed-in)
└── KeyokuUITestsLaunchTests.swift # Launch performance
```

**Naming conventions**:
- Unit test files: `[Feature]Tests.swift`
- UI test files: `[Flow]UITests.swift` or group by feature in `KeyokuUITests.swift`
- Test suites: `@Suite("FeatureName — Category")`
- Test classes: `final class FeatureFlowTests: XCTestCase`

**When to split files**:
- File exceeds 750 lines (SwiftLint limit)
- Tests cover clearly separate features (auth vs. flashcards vs. streaks)
- You want to run a subset of tests quickly

---

## Writing New Tests — Checklist

### New Unit Test

1. Decide which file it belongs in (or create a new one)
2. Add `@Suite` struct with `@MainActor` if testing actor-isolated types
3. Create a `makeManager` helper returning `(Manager, MockLogService)` tuple
4. Write tests following GIVEN / WHEN / THEN
5. Use `#expect(...)` for all assertions
6. Verify analytics events with `mockLog.hasEvent(named:)` for key operations
7. Run with Cmd+U to verify

### New UI Test

1. Add to existing `KeyokuUITests` class or create a new `XCTestCase` subclass
2. Mark the class `@MainActor`, setUp only sets `continueAfterFailure = false`
3. Use local `let app = XCUIApplication()` in each test (not a class property)
4. Set `app.launchArguments` (always include `"UI_TESTING"`)
5. Prefer longer flow-based tests over many small tests (fewer app launches)
6. Use `waitForExistence(timeout:)` after every navigation action
7. If an element can't be found, check if it's under a different element type
8. Run with Cmd+U on the Mock scheme

### Adding Accessibility Identifiers

When you need to find an element in UI tests that doesn't have a stable label:

```swift
// In the SwiftUI view:
SomeView()
    .accessibilityIdentifier("UniqueTestID")

// In the UI test:
app.buttons["UniqueTestID"].tap()  // or app.staticTexts, app.links, etc.
```

---

## Common Mistakes

1. **Forgetting `@MainActor`** on test suites that test `@MainActor` types → concurrency errors
2. **Using `app.staticTexts` for buttons** → Elements wrapped in `.anyButton()` are buttons, not static texts
3. **Using `app.staticTexts` for links** → SwiftUI `Link()` element type varies by iOS version; use `app.descendants(matching: .any)["Label"]` for reliability
4. **Not waiting for elements** → Use `waitForExistence(timeout:)` after navigation, not just `.exists`
5. **Forgetting `@testable import`** → Can't access internal types without it
6. **Missing `try await`** → Async throwing methods need both `try` and `await`, even with mocks
7. **Test files over 750 lines** → Split into separate files by feature to satisfy SwiftLint
8. **Using `func name()` in UI tests** → Must start with `test` prefix: `func testName()`
9. **Hardcoding text in UI tests** → Prefer `accessibilityIdentifier` over label text for stability
10. **Not setting `continueAfterFailure = false`** → Cascading failures make debugging harder
11. **Using `var app` as a class property in UI tests** → Causes `@MainActor` / `nonisolated` concurrency conflicts with setUp/tearDown. Use local `let app` in each test instead
12. **Creating managers without MockLogService** → Always inject `LogManager(services: [mockLog])` so you can verify analytics events are tracked
13. **Not verifying analytics events** → Key operations should assert both `_Start` and `_Success` events via `mockLog.hasEvent(named:)`
