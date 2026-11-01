# Router

A type-safe, observable navigation model for SwiftUI apps built around `TabView`, `NavigationStack`, and modal presentations.

Navigation is a value the app owns.
Views only observe it, deep links produce a state rather than mutate one, and the whole model runs headless on macOS so tests and command-line tools can drive it without a simulator.

Router ships as two libraries:

| Library      | Imports                     | Platforms        | Use it from                                   |
|--------------|-----------------------------|------------------|-----------------------------------------------|
| `RouterCore` | Foundation, Observation     | iOS 18, macOS 14 | Feature and core packages, tests, CLIs        |
| `RouterUI`   | `RouterCore`, SwiftUI       | iOS 18           | Views and the app target                      |

`RouterUI` re-exports `RouterCore`, so views only need `import RouterUI`.

## Features

- **Type-safe**: generic over your own `Tab`, `Destination`, `Sheet`, and `FullscreenCover` enums.
- **Observable** via the `@Observable` macro, so view updates propagate automatically.
- **Single source of truth** for tab selection, per-tab navigation stacks, and presented sheets and covers.
- **Bundled presentation state**: sheets and covers carry their own navigation stacks, so they can't drift out of sync with their presentation identity.
- **Snapshots**: the whole router is a `Codable`, `Equatable` value you can persist, print, diff, and restore.
- **Deep linking** via opt-in `URLRoutable*` protocols, with sheet and cover deep links supported through reserved URL prefixes.
- **Headless**: `RouterCore` has no SwiftUI dependency and runs under `swift test` on macOS.
- **`@MainActor`-isolated** for correct concurrency.

## Requirements

- Swift 6.3 toolchain or later
- iOS 18+ (`RouterCore` and `RouterUI`)
- macOS 14+ (`RouterCore`)

## Installation

Add the package with Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/CZubrecki/Router.git", .upToNextMinor(from: "0.3.0")),
]
```

Then depend on the library each target needs:

```swift
.target(name: "Features", dependencies: [.product(name: "RouterCore", package: "Router")]),
.target(name: "AppUI", dependencies: [.product(name: "RouterUI", package: "Router")]),
```

Upgrading from 0.2? See [MIGRATION.md](MIGRATION.md).

# Core

Everything in this section lives in `RouterCore` and works anywhere, including macOS command-line tools and test targets with no SwiftUI.

## Defining routes

```swift
import RouterCore

enum AppTab: String, Codable, RouterTab {
    case home, profile, settings
}

enum AppDestination: Codable, RouterDestination {
    case friend(id: Int)
    case settings
}

enum AppSheet: String, Codable, RouterSheet {
    case login
}

enum AppCover: String, Codable, RouterFullScreenCover {
    case onboarding
}

typealias AppRouter = Router<AppTab, AppDestination, AppSheet, AppCover>
```

`Codable` is optional.
Conform the four enums to it when you want snapshots to be `Codable` too.

## Driving navigation

All mutations go through the router:

```swift
let router = AppRouter(initialTab: .home)

// Push onto the current tab's stack
router.navigate(to: .friend(id: 42))

// Push onto a specific tab
router.navigate(to: .friend(id: 42), in: .profile)

// Push several at once
router.navigate(to: .friend(id: 42), .settings)

// Switch tab + push in one call
router.switchTab(to: .profile, navigatingTo: .friend(id: 42))

// Reset a tab's stack
router.switchTab(to: .profile, resetTo: .friend(id: 42), .settings)

// Pop operations
router.pop()                       // current tab, one level
router.pop(3)                      // current tab, three levels
router.popTo(.friend(id: 42))      // current tab, back to a destination
router.popToRoot()                 // current tab, all the way
router.popToRoot(in: .profile)     // a specific tab
router.popAllToRoot()              // every tab
```

## Sheets and full-screen covers

Presentation state is held alongside its own navigation stack so the two can't drift apart.

```swift
// Present
router.present(sheet: .login)
router.present(fullscreenCover: .onboarding)

// Push inside a presented sheet / cover
router.navigateInSheet(to: .friend(id: 42))
router.navigateInFullscreenCover(to: .settings)

// Pop inside
router.popInSheet()
router.popInFullscreenCover(2)
router.popInSheetToRoot()
router.popInFullscreenCoverToRoot()

// Dismiss
router.dismissSheet()
router.dismissFullscreenCover()
```

Sheets and full-screen covers are **global** to the router.
There is one of each at a time, and they persist across tab switches by design.
This matches native iOS apps like Clock: tap "+" on Alarms to open the new-alarm sheet, then tap Timers, and the sheet stays visible on top.

In practice, users can't *trigger* a tab switch during a modal, because `.sheet()` covers the tab bar at most detents and blocks interaction underneath.
So the persistence rule mainly affects programmatic switches (notifications, deep links).

## Snapshots

`router.snapshot` captures the whole router as a value: the selected tab, every tab's stack, the presented sheet and cover with their stacks, and any queued cover replacement.

```swift
let saved = router.snapshot              // Router.Snapshot: Hashable, Sendable
let copy = AppRouter(snapshot: saved)    // a new router in that state
router.restore(saved)                    // put a live router back into that state
```

`Snapshot` is `Codable` when all four routing types are.
Paths are encoded as a list sorted by tab, so with `.sortedKeys` the JSON is byte-stable across runs and fixtures diff cleanly in git:

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let json = try encoder.encode(router.snapshot)
```

```json
{
  "paths" : [
    { "stack" : [ { "friend" : { "id" : 42 } } ], "tab" : "profile" }
  ],
  "presentedSheet" : { "sheet" : "login", "stack" : [ ] },
  "selectedTab" : "profile"
}
```

Empty stacks are left out, so a tab popped back to its root equals one that was never touched.
Where and when to save a snapshot (`SceneStorage`, a file, a test fixture) is up to the app.
See [Restoring navigation on launch](#restoring-navigation-on-launch) for a `SceneStorage` example.

## Deep linking

Conform your tab, destination, sheet, and cover types to the corresponding `URLRoutable*` protocols.
Sheet and cover conformance is optional; the router checks for it at runtime.

```swift
extension AppTab: URLRoutableTab {
    static func tab(from path: String) -> AppTab? {
        AppTab(rawValue: path)
    }
}

extension AppDestination: URLRoutableDestination {
    static func destination(
        consuming components: ArraySlice<String>,
        parameters: [String: String]
    ) -> (destination: AppDestination, consumed: Int)? {
        guard let head = components.first else { return nil }
        switch head {
        case "friend":
            guard let id = components.dropFirst().first.flatMap(Int.init) else { return nil }
            return (.friend(id: id), 2)
        case "settings":
            return (.settings, 1)
        default:
            return nil
        }
    }
}

extension AppSheet: URLRoutableSheet {
    static func sheet(from path: String) -> AppSheet? {
        AppSheet(rawValue: path)
    }
}
```

URL conventions:

| URL                                       | Result                                                  |
|-------------------------------------------|---------------------------------------------------------|
| `myapp://profile/friend/42`               | Select `.profile`, stack `[.friend(id: 42)]`            |
| `myapp://sheet/login`                     | Present sheet `.login`                                  |
| `myapp://sheet/checkout/payment/confirm`  | Present sheet `.checkout`, stack `[.payment, .confirm]` |
| `myapp://cover/onboarding`                | Present cover `.onboarding`                             |

The matched stack is *replaced* with the parsed destinations.
The `sheet` and `cover` prefixes are reserved by default; both are configurable on `handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)`.

For universal links (`https://example.com/...`), pass `treatHostAsPath: false` so the host (your domain) isn't treated as the first route component.

## Running headless

Because `RouterCore` builds for macOS without SwiftUI, a command-line tool or test can load a state, drive it, and print the result with no simulator:

```swift
import Foundation
import RouterCore

let router = AppRouter(initialTab: .home)

// Load a fixture
let fixture = try JSONDecoder().decode(AppRouter.Snapshot.self, from: Data(contentsOf: fixtureURL))
router.restore(fixture)

// Drive it
router.handleDeepLink(url: URL(string: "myapp://profile/friend/42")!)

// Print the state
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
print(String(decoding: try encoder.encode(router.snapshot), as: UTF8.self))
```

# UI

Everything in this section lives in `RouterUI`, which adds the SwiftUI glue on top of `RouterCore`.

## Quick start

```swift
import RouterUI
import SwiftUI

struct RootView: View {
    @State private var router = AppRouter(initialTab: .home)

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.home) {
                NavigationStack(path: router.pathBinding(for: .home)) {
                    HomeRoot()
                        .navigationDestination(for: AppDestination.self) { destination in
                            view(for: destination)
                        }
                }
            } label: {
                Label("Home", systemImage: "house")
            }
            // ...other tabs
        }
        .sheet(item: $router.presentedSheet) { presentation in
            view(for: presentation.sheet)
        }
        .fullScreenCover(item: $router.presentedFullscreenCover) { presentation in
            view(for: presentation.cover)
        }
        .onOpenURL(with: router)
        .environment(router)
    }
}
```

`SheetPresentation` and `FullscreenCoverPresentation` conform to `Identifiable`, so they bind directly to `.sheet(item:)` and `.fullScreenCover(item:)`.

## Tab titles and images

Tab display details live in `TabPresentable`, so the tab enum itself can stay in a package with no SwiftUI.
Add the conformance in the UI layer:

```swift
extension AppTab: TabPresentable {
    var title: LocalizedStringKey? {
        switch self {
        case .home:     "Home"
        case .profile:  "Profile"
        case .settings: "Settings"
        }
    }

    var image: TabImage? {
        switch self {
        case .home:     .systemImage("house")
        case .profile:  .systemImage("person.circle")
        case .settings: .systemImage("gear")
        }
    }
}
```

`title`, `image`, and `role` all default to `nil`, so implement only what each tab needs.

## Navigation stacks inside a modal

A modal that hosts a multi-step flow gets its own `NavigationStack`, driven by the presentation's bundled stack:

```swift
.fullScreenCover(item: $router.presentedFullscreenCover) { presentation in
    NavigationStack(path: router.fullscreenCoverPathBinding()) {
        view(for: presentation.cover)
            .navigationDestination(for: AppDestination.self) { destination in
                view(for: destination)
            }
    }
}
```

`sheetPathBinding()` does the same for sheets.
Both read as empty and discard writes when nothing is presented, so the binding can be built before anything is on screen.

## Swapping one cover for another

SwiftUI drops the incoming presentation if you dismiss one full-screen cover and present another in the same update.
`replace(fullscreenCover:)` handles the handoff: it dismisses the current cover and queues the replacement, which the host presents once dismissal finishes.

```swift
// From anywhere - e.g. a sign-up prompt inside an onboarding cover
router.replace(fullscreenCover: .login)

// Drained by the host
.fullScreenCover(item: $router.presentedFullscreenCover) { presentation in
    view(for: presentation.cover)
} onDismiss: {
    if let next = router.takePendingFullscreenCover() {
        DispatchQueue.main.async { router.present(fullscreenCover: next) }
    }
}
```

With nothing presented, `replace(fullscreenCover:)` presents immediately.
Calling it again before the queue drains supersedes the queued cover.
`dismissFullscreenCover()` cancels a queued replacement, so drain with `takePendingFullscreenCover()` rather than dismissing again.

## Native SwiftUI transitions (zoom, etc.)

The router only manipulates data (`[Destination]`, `presentedSheet`, ...), so every native SwiftUI navigation transition, including the iOS 18 [zoom transition](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)), works without router involvement.
The router triggers the push; SwiftUI animates it.

```swift
struct HomeRoot: View {
    @Environment(AppRouter.self) private var router
    @Namespace private var namespace
    let friends: [Friend]

    var body: some View {
        List(friends) { friend in
            Button {
                router.navigate(to: .friend(id: friend.id))
            } label: {
                FriendThumbnail(friend: friend)
                    .matchedTransitionSource(id: friend.id, in: namespace)
            }
        }
        .navigationDestination(for: AppDestination.self) { destination in
            if case .friend(let id) = destination {
                FriendDetailView(id: id)
                    .navigationTransition(.zoom(sourceID: id, in: namespace))
            }
        }
    }
}
```

The same pattern applies to sheets and full-screen covers: apply `.navigationTransition(.zoom(sourceID:in:))` to the presented view.

## Nested sheets

The router holds at most one sheet.
For sub-sheets within a flow (compose → photo picker, email → OTP), present them with a local `@State` binding *inside the parent sheet's view*.
SwiftUI stacks them visually; the router stays focused on top-level flows.

```swift
struct EmailSheetView: View {
    @State private var otpPresented = false

    var body: some View {
        Form {
            Button("Send code") { otpPresented = true }
        }
        .sheet(isPresented: $otpPresented) {
            OTPSheetView()        // visually stacks over the email sheet
        }
    }
}
```

Dismissing the parent sheet collapses the entire SwiftUI sheet hierarchy.

## Handling notifications

When a notification or background event should present a sheet, present it *without* changing tabs so the user returns to wherever they were:

```swift
.onContinueUserActivity("openAlarm") { activity in
    if let alarmId = activity.userInfo?["id"] as? UUID {
        router.present(sheet: .editAlarm(id: alarmId))
    }
}
```

If the notification should also change the active tab, do both:

```swift
router.switchTab(to: .alarms)
router.present(sheet: .editAlarm(id: alarmId))
```

## Restoring navigation on launch

Save the snapshot to `SceneStorage` whenever it changes and restore it when the scene comes back:

```swift
struct RootView: View {
    @State private var router = AppRouter(initialTab: .home)
    @SceneStorage("navigation") private var savedNavigation: Data?

    var body: some View {
        content
            .onAppear {
                guard let savedNavigation,
                      let snapshot = try? JSONDecoder().decode(AppRouter.Snapshot.self, from: savedNavigation)
                else { return }
                router.restore(snapshot)
            }
            .onChange(of: router.snapshot) { _, snapshot in
                savedNavigation = try? JSONEncoder().encode(snapshot)
            }
    }
}
```

# Reference

## Protocols

| Protocol                     | Module       | Refines                 | Purpose                                         |
|------------------------------|--------------|-------------------------|-------------------------------------------------|
| `RouterTab`                  | `RouterCore` | `Hashable`, `Sendable`  | Identifies a tab.                               |
| `RouterDestination`          | `RouterCore` | `Hashable`, `Sendable`  | Identifies a screen the router can push.        |
| `RouterSheet`                | `RouterCore` | `Hashable`, `Sendable`  | Identifies a sheet the router can present.      |
| `RouterFullScreenCover`      | `RouterCore` | `Hashable`, `Sendable`  | Identifies a full-screen cover.                 |
| `URLRoutableTab`             | `RouterCore` | `RouterTab`             | Adds URL deep-link support for tabs.            |
| `URLRoutableDestination`     | `RouterCore` | `RouterDestination`     | Adds URL deep-link support for destinations.    |
| `URLRoutableSheet`           | `RouterCore` | `RouterSheet`           | Adds URL deep-link support for sheets.          |
| `URLRoutableFullScreenCover` | `RouterCore` | `RouterFullScreenCover` | Adds URL deep-link support for covers.          |
| `TabPresentable`             | `RouterUI`   | `RouterTab`             | Adds title, image, and role for the tab bar.    |

## Router at a glance

- **State:** `selectedTab`, `subscript(tab:)`, `currentPath`, `presentedSheet`, `presentedFullscreenCover`, `pendingFullscreenCover`
- **Snapshots:** `snapshot`, `init(snapshot:)`, `restore(_:)`
- **Tab navigation:** `navigate(to:)`, `navigate(to:in:)`, `switchTab(to:navigatingTo:)`, `switchTab(to:resetTo:)`
- **Pop:** `pop(_:)`, `popTo(_:in:)`, `popToRoot(in:)`, `popAllToRoot()`
- **Sheets:** `present(sheet:)`, `navigateInSheet(to:)`, `popInSheet(_:)`, `popInSheetToRoot()`, `dismissSheet()`
- **Covers:** `present(fullscreenCover:)`, `replace(fullscreenCover:)`, `takePendingFullscreenCover()`, `navigateInFullscreenCover(to:)`, `popInFullscreenCover(_:)`, `popInFullscreenCoverToRoot()`, `dismissFullscreenCover()`
- **Deep links:** `handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)`
- **SwiftUI (`RouterUI`):** `pathBinding(for:)`, `sheetPathBinding()`, `fullscreenCoverPathBinding()`, `View.onOpenURL(with:)`

## Development

```sh
swift test                              # RouterCore + RouterUI bindings, headless on macOS
scripts/check-coverage.sh 90            # same, with RouterCore's line-coverage gate
scripts/check-core-swiftui-free.sh      # RouterCore's interface must not mention SwiftUI
xcodebuild test -scheme Router-Package \
  -destination "platform=iOS Simulator,id=$(scripts/ios-simulator-id.sh)"
```

CI runs all of the above on every pull request and publishes DocC archives for both modules as a build artifact.

## Status

Router is in **0.x**: the public API may change between minor versions.
Pin with `.upToNextMinor(from:)` until 1.0.

**Known limitations**

- The router is designed around `TabView` + `NavigationStack`.
  `NavigationSplitView` (three-column iPad and macOS layouts) is not modeled.
  `RouterCore` builds on macOS so tools can run it, not so macOS apps can use it.
- One sheet at a time at the router level.
  Nested sheets work through SwiftUI `@State` (see [Nested sheets](#nested-sheets)), but the router doesn't track them.

## Roadmap

- **0.4**: a navigation event stream, two-way routes (`currentRoute`, `navigate(route:)`), and explicit deep-link errors.
- **0.5**: a smaller API built on a `Context` parameter, and cover replacement handled inside the router.
- **1.0**: deprecated 0.x names removed.
- **Later**: first-class iPad and macOS layouts (`NavigationSplitView`, multi-window scenes).

Out of scope: Combine APIs, and view-layer concerns like detents, transitions, and sheet sizing, which stay at the call site.

## License

Router is available under the MIT license. See [LICENSE](LICENSE) for details.
