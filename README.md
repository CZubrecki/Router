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
    .package(url: "https://github.com/CZubrecki/Router.git", from: "0.1.0"),
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

- **Path access:** `subscript(tab:)`, `currentPath`, `pathBinding(for:)`
- **Tab navigation:** `navigate(to:)`, `navigate(to:in:)`, `switchTab(to:navigatingTo:)`, `switchTab(to:resetTo:)`
- **Pop:** `pop(_:)`, `popTo(_:in:)`, `popToRoot(in:)`, `popAllToRoot()`
- **Sheets:** `present(sheet:)`, `navigateInSheet(to:)`, `popInSheet(_:)`, `popInSheetToRoot()`, `dismissSheet()`
- **Covers:** `present(fullscreenCover:)`, `navigateInFullscreenCover(to:)`, `popInFullscreenCover(_:)`, `popInFullscreenCoverToRoot()`, `dismissFullscreenCover()`
- **Deep links:** `handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)`, `View.onOpenURL(with:)`

## License

Router is available under the MIT license. See [LICENSE](LICENSE) for details.
