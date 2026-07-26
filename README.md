# Router

A type-safe, observable routing primitive for SwiftUI apps built around `TabView`, `NavigationStack`, and modal presentations.

## Features

- **Type-safe** generic over your own `Tab`, `Destination`, `Sheet`, and `FullscreenCover` enums.
- **Observable** via the `@Observable` macro — view updates propagate automatically.
- **Single source of truth** for tab selection, per-tab navigation stacks, and presented sheets / covers.
- **Bundled presentation state**: sheets and covers carry their own navigation stacks, so they can't desync from their presentation identity.
- **Deep linking** via opt-in `URLRoutable*` protocols, with sheet and cover deep links supported through reserved URL prefixes.
- **Idiomatic SwiftUI integration**: `Binding` helpers, `Identifiable` presentation structs, and a one-line `.onOpenURL(with:)` view modifier.
- **`@MainActor`-isolated** for correct concurrency.

## Requirements

- Swift 6.0+
- iOS 18+
- Xcode 16+

## Installation

Add the package to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/CZubrecki/Router.git", from: "0.2.0"),
]
```

Then import where needed:

```swift
import Router
```

## Quick start

```swift
import Router
import SwiftUI

// 1. Define your routing types.

enum AppTab: Hashable, Sendable, RouterTab {
    case home, profile, settings

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

enum AppDestination: Hashable, Sendable, RouterDestination {
    case friend(id: Int)
    case settings
}

enum AppSheet: Hashable, Sendable, RouterSheet {
    case login
}

enum AppCover: Hashable, Sendable, RouterFullScreenCover {
    case onboarding
}

typealias AppRouter = Router<AppTab, AppDestination, AppSheet, AppCover>

// 2. Create a router and wire it into your view tree.

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
        .environment(router)
    }
}
```

## Driving navigation

All mutations go through the router:

```swift
@Environment(AppRouter.self) private var router

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

### Native SwiftUI transitions (zoom, etc.)

The router only manipulates the data layer (`[Destination]`, `presentedSheet`, …), so every native SwiftUI navigation transition — including the iOS 18 [zoom transition](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)) — works without router involvement. The router triggers the push; SwiftUI animates it.

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

The same pattern applies to sheets and full-screen covers — apply `.navigationTransition(.zoom(sourceID:in:))` to the presented view.

## Sheets and full-screen covers

Presentation state is held alongside its own navigation stack so they can't desync.

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

`SheetPresentation` and `FullscreenCoverPresentation` both conform to `Identifiable`, so they bind directly to SwiftUI's `.sheet(item:)` and `.fullScreenCover(item:)` modifiers.

### Navigation stacks inside a modal

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

`sheetPathBinding()` does the same for sheets. Both read as empty and discard writes when nothing is presented, so the binding can be built before anything is on screen.

### Swapping one cover for another

SwiftUI drops the incoming presentation if you dismiss one full-screen cover and present another in the same update. `replace(fullscreenCover:)` handles the handoff: it dismisses the current cover and queues the replacement, which the host presents once dismissal finishes.

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

With nothing presented, `replace(fullscreenCover:)` presents immediately. Calling it again before the queue drains supersedes the queued cover. `dismissFullscreenCover()` cancels a queued replacement, so drain with `takePendingFullscreenCover()` rather than dismissing again.

### Modal behavior

Sheets and full-screen covers are **global** to the router — there is one of each at a time, and they persist across tab switches by design. This matches iOS native apps like Clock: tap "+" on Alarms to open the new-alarm sheet, then tap Timers, and the sheet stays visible on top.

In practice, end users can't *trigger* a tab switch during a modal — SwiftUI's `.sheet()` covers the tab bar at most detents and blocks underlying interaction. So the persistence rule mainly affects programmatic switches (notifications, deep links).

### Nested sheets

The router holds at most one sheet. For sub-sheets within a flow (e.g. compose → photo picker, email → OTP), present them with a local `@State` binding *inside the parent sheet's view*. SwiftUI stacks them visually; the router stays focused on top-level flows.

```swift
struct EmailSheetView: View {
    @Environment(AppRouter.self) private var router
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

Dismissing the parent sheet (via `router.dismissSheet()`) collapses the entire SwiftUI sheet hierarchy.

### Handling notifications

When a notification or background event should present a sheet, present it *without* changing tabs — the user returns to wherever they were:

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

## Deep linking

Conform your tab, destination, sheet, and cover types to the corresponding `URLRoutable*` protocols. Sheet and cover conformance is optional — the router only checks at runtime.

```swift
extension AppTab: URLRoutableTab {
    static func tab(from path: String) -> AppTab? {
        switch path {
        case "home":     .home
        case "profile":  .profile
        case "settings": .settings
        default:         nil
        }
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
        path == "login" ? .login : nil
    }
}
```

Wire it into the view tree:

```swift
RootView()
    .onOpenURL(with: router)
```

URL conventions:

| URL                                       | Result                                                  |
|-------------------------------------------|---------------------------------------------------------|
| `myapp://profile/friend/42`               | Select `.profile`, stack `[.friend(id: 42)]`            |
| `myapp://sheet/login`                     | Present sheet `.login`                                  |
| `myapp://sheet/checkout/payment/confirm`  | Present sheet `.checkout`, stack `[.payment, .confirm]` |
| `myapp://cover/onboarding`                | Present cover `.onboarding`                             |

The `sheet` and `cover` prefixes are reserved by default. Both are configurable on `handleDeepLink(url:sheetPrefix:coverPrefix:)`.

For universal links (`https://example.com/...`), pass `treatHostAsPath: false` so the host (your domain) isn't treated as the first route component.

## API overview

### Protocols

| Protocol                     | Refines      | Purpose                                                  |
|------------------------------|--------------|----------------------------------------------------------|
| `RouterTab`                  | `Hashable`   | Identifies a tab; carries title, image, and role hints.  |
| `RouterDestination`          | `Hashable`   | Identifies a screen the router can push.                 |
| `RouterSheet`                | `Hashable`   | Identifies a sheet the router can present.               |
| `RouterFullScreenCover`      | `Hashable`   | Identifies a full-screen cover the router can present.   |
| `URLRoutableTab`             | `RouterTab`  | Adds URL deep-link support for tabs.                     |
| `URLRoutableDestination`     | `RouterDestination` | Adds URL deep-link support for destinations.      |
| `URLRoutableSheet`           | `RouterSheet`| Adds URL deep-link support for sheets.                   |
| `URLRoutableFullScreenCover` | `RouterFullScreenCover` | Adds URL deep-link support for covers.        |

### Router methods at a glance

- **Path access:** `subscript(tab:)`, `currentPath`, `pathBinding(for:)`, `sheetPathBinding()`, `fullscreenCoverPathBinding()`
- **Tab navigation:** `navigate(to:)`, `navigate(to:in:)`, `switchTab(to:navigatingTo:)`, `switchTab(to:resetTo:)`
- **Pop:** `pop(_:)`, `popTo(_:in:)`, `popToRoot(in:)`, `popAllToRoot()`
- **Sheets:** `present(sheet:)`, `navigateInSheet(to:)`, `popInSheet(_:)`, `popInSheetToRoot()`, `dismissSheet()`
- **Covers:** `present(fullscreenCover:)`, `replace(fullscreenCover:)`, `takePendingFullscreenCover()`, `navigateInFullscreenCover(to:)`, `popInFullscreenCover(_:)`, `popInFullscreenCoverToRoot()`, `dismissFullscreenCover()`
- **Deep links:** `handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)`, `View.onOpenURL(with:)`

## Status

Router is in **0.x** — the public API may evolve between minor versions as real-world usage shakes out details. Pinning to `.upToNextMinor(from: "0.2.0")` is recommended until 1.0.0.

Tests run on the iOS simulator, since the package targets iOS only:

```sh
xcodebuild test -scheme Router -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

**Known limitations in 0.2**

- No state restoration. Cold-launching the app loses presented sheets, covers, and per-tab navigation stacks. The presentation structs aren't `Codable` yet.
- The router is designed around `TabView` + `NavigationStack`. **`NavigationSplitView` (three-column iPad / macOS layouts) is not modeled.** Apps using `.tabViewStyle(.sidebarAdaptable)` on iPadOS 18+ work out of the box; native split-view layouts are out of scope for now.
- Single sheet at a time at the router level. Nested sheets work via SwiftUI `@State` (see [Nested sheets](#nested-sheets) above), but the router doesn't track sub-sheets.

## Roadmap

**0.3 — State restoration**
- `Codable` conformance for `SheetPresentation` / `FullscreenCoverPresentation` plus a `Router.State` snapshot for `SceneStorage` integration
- CI workflow on GitHub Actions
- Universal links example in the README

**0.4 — Ergonomics**
- `popUntil(where:)` predicate-based pop
- `navigate(to:replacingTopWith:)` for sign-in → home flows
- Optional sheet stacking (`pushSheet(_:)` / `sheetStack`) if real-world usage demands centralized sub-sheet state

**Future — iPad and macOS first-class support**
- A sibling `SplitRouter` (or generalized model) for `NavigationSplitView`-driven three-column layouts
- macOS-specific affordances: multi-window scenes, toolbar-driven actions, removing the iOS-only `fullScreenCover` API on that platform
- `TabSection` and `TabViewCustomization` integration patterns documented as a guide

**Out of scope**
- Combine-based reactive APIs (the router is built around Swift Concurrency / `@Observable`).
- View-layer concerns like presentation detents, custom transitions, and sheet sizing — handled by SwiftUI modifiers at the call site.

## License

Router is available under the MIT license. See [LICENSE](LICENSE) for details.
