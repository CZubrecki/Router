import SwiftUI

/// The image source for a tab's tab-bar item.
public enum TabImage: Sendable {
	/// An SF Symbol name resolved with `Image(systemName:)`.
	case systemImage(String)
	/// An asset-catalog image name resolved with `Image(_:)`.
	case asset(String)
}

/// A value that identifies a tab the router manages.
///
/// Conform a `Hashable` enum (or struct) to `RouterTab` to describe every tab in the app.
///
/// All three properties have protocol-extension defaults of `nil`, so you only implement what
/// each tab actually needs.
///
/// ## Example
///
/// ```swift
/// enum AppTab: Hashable, Sendable, RouterTab {
///     case home, profile, search, settings
///
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
public protocol RouterTab: Hashable, Sendable {
	/// The tab's display title. Return `nil` to defer to the tab's `role` for a default title.
	var title: LocalizedStringKey? { get }

	/// The image shown in the tab bar. Return `nil` to defer to the tab's `role` or to display
	/// a label-only tab.
	var image: TabImage? { get }

	/// The semantic role of the tab (e.g. `.search`). Return `nil` for a standard navigation tab.
	var role: TabRole? { get }
}

public extension RouterTab {
	var title: LocalizedStringKey? { nil }
	var image: TabImage? { nil }
	var role: TabRole? { nil }
}
