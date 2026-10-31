# Migrating Router

Each section lists what changed in one release and the mechanical edit that ports an app to it.
Apply them in order when skipping releases.

## 0.2 → 0.3: RouterCore and RouterUI

The single `Router` library is now two:

- `RouterCore`: the `Router` class, routing protocols, snapshots, and deep-link parsing.
  Imports only Foundation and Observation and builds for macOS.
- `RouterUI`: SwiftUI bindings, `View.onOpenURL(with:)`, and `TabPresentable`.
  Re-exports `RouterCore`.

### 1. Change the product and the import

```swift
// Before
.product(name: "Router", package: "Router")
import Router

// After, in view code and the app target
.product(name: "RouterUI", package: "Router")
import RouterUI

// After, in packages that must not import SwiftUI
.product(name: "RouterCore", package: "Router")
import RouterCore
```

### 2. Move tab titles, images, and roles to `TabPresentable`

`RouterTab` no longer declares `title`, `image`, or `role`.
They moved to `TabPresentable: RouterTab` in `RouterUI`, along with `TabImage`.

```swift
// Before
enum AppTab: Hashable, Sendable, RouterTab {
    case home, profile
    var title: LocalizedStringKey? { ... }
    var image: TabImage? { ... }
}

// After
enum AppTab: Hashable, Sendable, RouterTab {
    case home, profile
}

extension AppTab: TabPresentable {   // in the UI layer
    var title: LocalizedStringKey? { ... }
    var image: TabImage? { ... }
}
```

### 3. Optional: snapshots

Conform the four routing enums to `Codable` to make `Router.Snapshot` `Codable`.
Apps that don't conform see no change.

## 0.3 → 0.4: events, routes, and deep-link errors

Everything is additive except one behaviour change.

### Behaviour change: unknown path components are an error

0.3 skipped path components no destination recognised, so `myapp://home/typo/photos` landed on `[.photos]`.
0.4 rejects the whole link with `.unconsumedComponents(["typo", "photos"])` and leaves the router unchanged.

`handleDeepLink(url:)` now returns `Result<Void, DeepLinkError>` (marked `@discardableResult`, so existing calls still compile).
To keep the old lenient behaviour for a specific case, make the destination parser claim the components it should ignore.
For example, consume an unknown trailing component instead of returning `nil`:

```swift
static func destination(consuming components: ArraySlice<String>, parameters: [String: String])
    -> (destination: AppDestination, consumed: Int)? {
    switch components.first {
    case "photos": return (.photos, 1)
    default: return nil   // 0.4: rejects the link. Return a fallback destination to accept it.
    }
}
```

### New requirement: map values back to paths

Routes now render in both directions, so each `URLRoutable*` protocol gains a reverse mapping:

| Protocol                     | New requirement                  |
|------------------------------|----------------------------------|
| `URLRoutableTab`             | `var path: String`               |
| `URLRoutableSheet`           | `var path: String`               |
| `URLRoutableFullScreenCover` | `var path: String`               |
| `URLRoutableDestination`     | `var pathComponents: [String]`   |

Enums with `String` raw values get `path` (and the `from:` lookups) for free.
Destinations implement `pathComponents` as the inverse of `destination(consuming:parameters:)`.

### New API

- `router.events` (`AsyncStream<NavigationEvent>`) and `router.onEvent`.
- `router.currentRoute`, `router.navigate(route:)`, `Router.route(for:format:)`, and `router.routeFormat`.
- `handleDeepLink`'s `sheetPrefix` and `coverPrefix` now default to `router.routeFormat`'s values.
