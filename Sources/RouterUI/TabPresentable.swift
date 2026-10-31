import RouterCore
import SwiftUI

/// The image source for a tab's tab-bar item.
public enum TabImage: Hashable, Sendable {
	/// An SF Symbol name resolved with `Image(systemName:)`.
	case systemImage(String)
	/// An asset-catalog image name resolved with `Image(_:)`.
	case asset(String)
}

/// A tab that carries the details needed to draw its tab-bar item.
///
/// Kept apart from `RouterTab` so tab enums can live in packages that never import SwiftUI.
/// Declare the conformance in the UI layer. All three properties default to `nil`, so you only
/// implement what each tab actually needs.
///
/// ## Example
///
/// ```swift
/// extension AppTab: TabPresentable {
///     var title: LocalizedStringKey? {
///         switch self {
///         case .home:     "Home"
///         case .profile:  "Profile"
///         case .search:   nil          // role provides default
///         case .settings: "Settings"
///         }
///     }
///
///     var image: TabImage? {
///         switch self {
///         case .home:     .systemImage("house")
///         case .profile:  .systemImage("person.circle")
///         case .search:   nil          // role provides default
///         case .settings: .systemImage("gear")
///         }
///     }
///
///     var role: TabRole? {
///         self == .search ? .search : nil
///     }
/// }
/// ```
@available(macOS 15, *)
public protocol TabPresentable: RouterTab {
	/// The tab's display title. Return `nil` to defer to the tab's `role` for a default title.
	var title: LocalizedStringKey? { get }

	/// The image shown in the tab bar. Return `nil` to defer to the tab's `role` or to display
	/// a label-only tab.
	var image: TabImage? { get }

	/// The semantic role of the tab (e.g. `.search`). Return `nil` for a standard navigation tab.
	var role: TabRole? { get }
}

@available(macOS 15, *)
public extension TabPresentable {
	var title: LocalizedStringKey? { nil }
	var image: TabImage? { nil }
	var role: TabRole? { nil }
}
