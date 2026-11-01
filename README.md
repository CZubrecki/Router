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
- **Events**: every state change is reported as a `NavigationEvent`, through an `AsyncStream` or a synchronous handler.
- **Two-way routes**: deep links parse into state, `currentRoute` renders state back into a route, and rejected links say why.
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
    .package(url: "https://github.com/CZubrecki/Router.git", .upToNextMajor(from: "1.0.0")),
]
```

Then depend on the library each target needs:

```swift
.target(name: "Features", dependencies: [.product(name: "RouterCore", package: "Router")]),
.target(name: "AppUI", dependencies: [.product(name: "RouterUI", package: "Router")]),
```

Upgrading from 0.x? [MIGRATION.md](MIGRATION.md) lists every step with before-and-after code.

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

Every stack operation takes a `Context` saying which stack to act on.
It defaults to the selected tab, so most calls don't mention it:

```swift
public enum Context: Hashable, Sendable {
    case tab(Tab)        // a specific tab
    case currentTab      // whichever tab is selected when the call runs (the default)
    case sheet           // the presented sheet's stack
    case cover           // the presented full-screen cover's stack
}
```

```swift
let router = AppRouter(initialTab: .home)

// Push
router.navigate(to: .friend(id: 42))                     // selected tab
router.navigate(to: .friend(id: 42), .settings)          // several at once
router.navigate(to: .friend(id: 42), in: .tab(.profile)) // a specific tab
router.navigate(to: .settings, in: .sheet)               // inside the presented sheet

// Pop
router.pop()                                  // one level
router.pop(3, in: .cover)                     // three levels inside the cover
router.popTo(.friend(id: 42))                 // back to a destination
router.popToRoot(in: .tab(.profile))          // all the way
router.popAllToRoot()                         // every tab

// Replace a whole stack
router.replaceStack([.friend(id: 42), .settings], in: .tab(.profile))

// Tabs
router.switchTab(to: .profile)
```

Stack operations on `.sheet` or `.cover` do nothing when that modal isn't presented.

## Sheets and full-screen covers

Presentation state is held alongside its own navigation stack so the two can't drift apart.

```swift
router.present(sheet: .login)
router.present(cover: .onboarding)
router.replace(cover: .signUp)       // swap covers safely, see below

router.dismiss(.sheet)
router.dismiss(.cover)
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
Paths are encoded as a list in a fixed tab order, so with `.sortedKeys` the JSON is byte-stable across runs and fixtures diff cleanly in git.
The order is the tab type's own when it is `Comparable`, and each tab's description otherwise:

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

## Events

Every change to the router's state is reported as a `NavigationEvent`, delivered after the change so a handler that reads `router.snapshot` sees the new state.

```swift
public enum NavigationEvent: Hashable, Sendable {
    case switchedTab(from: Tab, to: Tab)
    case pushed([Destination], in: Context)
    case popped(count: Int, in: Context)
    case stackReplaced([Destination], in: Context)
    case presented(Presentation)          // .sheet(Sheet) | .cover(FullscreenCover)
    case dismissed(Presentation)
    case deepLinkHandled(URL)
    case deepLinkRejected(URL, DeepLinkError)
    case restored
}
```

Subscribe with an `AsyncStream`, or set a synchronous handler for a debug socket or analytics bridge:

```swift
Task {
    for await event in router.events {
        print(event)
    }
}

router.onEvent = { event in socket.send(.navigation(event)) }
```

- Each router method emits exactly one event. The exception is `popAllToRoot()`, which emits one pop per tab it clears: in tab order when `Tab` is `Comparable`, and otherwise in the order the stacks were started.
- Calls that change nothing (popping an empty stack, pushing into a sheet that isn't presented) emit nothing.
- Writes through SwiftUI bindings emit events too: a swipe-back is a `popped`, a tab tap is a `switchedTab`, a swipe-to-dismiss is a `dismissed`.
- Contexts in events are concrete: `.currentTab` is reported as the `.tab(_)` it resolved to.
- Nothing is built while no stream or handler is attached, so release builds pay nothing.

Mapping navigation events to analytics events is the app's job; Router never learns about any one app.

## Deep linking

Conform your tab, destination, sheet, and cover types to the corresponding `URLRoutable*` protocols.
Each protocol maps a path to a value and back.
Sheet and cover conformance is optional; the router checks for it at runtime.

Enums with `String` raw values get `tab(from:)`, `sheet(from:)`, `cover(from:)`, and `path` for free:

```swift
extension AppTab: URLRoutableTab { }
extension AppSheet: URLRoutableSheet { }
```

Destinations spell out both directions, since one destination can span several components:

```swift

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

    var pathComponents: [String] {
        switch self {
        case .friend(let id): ["friend", String(id)]
        case .settings:       ["settings"]
        }
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
The `sheet` and `cover` prefixes are reserved by default; change them with `router.routeFormat` or per call on `handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)`.

For universal links (`https://example.com/...`), pass `treatHostAsPath: false` so the host (your domain) isn't treated as the first route component.

### Rejected links

`handleDeepLink(url:)` returns `Result<Void, DeepLinkError>`.
A rejected link leaves the router unchanged.

| Error                         | Cause                                                           |
|-------------------------------|-----------------------------------------------------------------|
| `.unknownTab(String)`         | The first component names no tab.                               |
| `.unknownSheet(String)`       | The component after the sheet prefix names no sheet.            |
| `.unknownCover(String)`       | The component after the cover prefix names no cover.            |
| `.unconsumedComponents([String])` | No destination claimed these trailing components.           |
| `.malformedURL`               | No route at all, or a modal prefix with nothing after it.       |

Every component must be claimed.
Unrecognised components are an error rather than being skipped, so a typo in a route can't silently land somewhere else.

## Routes

A route is a URL without its scheme: `profile/friend/42`, `sheet/checkout/payment`, `cover/onboarding`.
`currentRoute` renders where the router is now, and `navigate(route:)` goes to a route:

```swift
router.routeFormat = RouteFormat(scheme: "myapp")   // prefixes default to "sheet" and "cover"

router.currentRoute                                  // "profile/friend/42"

switch router.navigate(route: "sheet/login") {
case .success: print(router.currentRoute)
case .failure(let error): print("rejected:", error)
}
```

The current location is the presented cover if any, else the presented sheet, else the selected tab, each followed by its stack.
`Router.route(for: snapshot)` renders a snapshot without a live router and can be called from any actor.
Following `currentRoute` always leaves the router's snapshot unchanged.
Routes use path components only; query parameters are still parsed, and reserved for optional modifiers.

## Running headless

Because `RouterCore` builds for macOS without SwiftUI, a command-line tool or test can load a state, drive it by route, observe what changed, and print the result with no simulator:

```swift
import Foundation
import RouterCore

let router = AppRouter(initialTab: .home)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]

// app state
print(String(decoding: try encoder.encode(router.snapshot), as: UTF8.self))

// app navigate profile/friend/42
switch router.navigate(route: arguments[0]) {
case .success: print(router.currentRoute)
case .failure(let error): fail(error)
}

// app scenario sunday  (the fixture includes a snapshot)
router.restore(fixture.navigation)

// debug socket
router.onEvent = { socket.send(.navigation($0)) }
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
        .fullScreenCover(router: router) { cover in
            view(for: cover)
        }
        .onOpenURL(with: router)
        .environment(router)
    }
}
```

`SheetPresentation` and `FullscreenCoverPresentation` conform to `Identifiable`, so they bind directly to `.sheet(item:)`.
Covers use `.fullScreenCover(router:)`, which also tells the router when a cover appears and finishes dismissing (see [Swapping one cover for another](#swapping-one-cover-for-another)).

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
.fullScreenCover(router: router) { cover in
    NavigationStack(path: router.fullscreenCoverPathBinding()) {
        view(for: cover)
            .navigationDestination(for: AppDestination.self) { destination in
                view(for: destination)
            }
    }
}
```

`sheetPathBinding()` does the same for sheets.
Both read as empty and discard writes when nothing is presented, so the binding can be built before anything is on screen.

## Swapping one cover for another

SwiftUI can drop a full-screen cover presented while another is still dismissing.
`replace(cover:)` handles the handoff: it dismisses the current cover and queues the replacement in `pendingFullscreenCover`.
The `.fullScreenCover(router:)` modifier tells the router when the outgoing cover has finished dismissing, and the router presents the queued cover then:

```swift
// From anywhere - e.g. a sign-up prompt inside an onboarding cover
router.replace(cover: .login)

// Host
.fullScreenCover(router: router) { cover in
    view(for: cover)
}
```

Hosts that present covers some other way call `router.coverDidAppear()` from the cover's `onAppear` and `router.coverDidDismiss()` from `onDismiss`.
Without those calls, as in headless tests, the router presents the queued cover on the next main-actor turn.

With nothing presented, `replace(cover:)` presents immediately.
Calling it again before the handoff supersedes the queued cover, and `dismiss(.cover)` or presenting a cover directly cancels it.

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
- **Events:** `events`, `onEvent`
- **Routes:** `routeFormat`, `currentRoute`, `navigate(route:)`, `route(for:format:)`
- **Stacks:** `navigate(to:in:)`, `pop(_:in:)`, `popTo(_:in:)`, `popToRoot(in:)`, `replaceStack(_:in:)`, `popAllToRoot()`
- **Tabs:** `switchTab(to:)`
- **Modals:** `present(sheet:)`, `present(cover:)`, `replace(cover:)`, `dismiss(_:)`, `coverDidAppear()`, `coverDidDismiss()`
- **Deep links:** `handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)`
- **SwiftUI (`RouterUI`):** `pathBinding(for:)`, `sheetPathBinding()`, `fullscreenCoverPathBinding()`, `View.fullScreenCover(router:onDismiss:content:)`, `View.onOpenURL(with:)`

## Development

```sh
swift test                              # RouterCore + RouterUI bindings, headless on macOS
scripts/check-coverage.sh 90            # same, with RouterCore's line-coverage gate
scripts/check-core-swiftui-free.sh      # RouterCore's interface must not mention SwiftUI
xcodebuild test -scheme Router-Package \
  -destination "platform=iOS Simulator,id=$(scripts/ios-simulator-id.sh)"
```

CI runs all of the above on every pull request and publishes DocC archives for both modules as a build artifact.
Build them locally with `xcodebuild docbuild -scheme RouterCore -destination 'generic/platform=macOS'`.

## Status

Router follows semantic versioning from 1.0: breaking changes only in a new major version.
Pin with `.upToNextMajor(from: "1.0.0")`.

**Known limitations**

- The router is designed around `TabView` + `NavigationStack`.
  `NavigationSplitView` (three-column iPad and macOS layouts) is not modeled.
  `RouterCore` builds on macOS so tools can run it, not so macOS apps can use it.
- One sheet at a time at the router level.
  Nested sheets work through SwiftUI `@State` (see [Nested sheets](#nested-sheets)), but the router doesn't track them.

## Roadmap

- **Later**: first-class iPad and macOS layouts (`NavigationSplitView`, multi-window scenes).

Out of scope: Combine APIs, and view-layer concerns like detents, transitions, and sheet sizing, which stay at the call site.

## License

Router is available under the MIT license. See [LICENSE](LICENSE) for details.
