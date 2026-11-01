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
