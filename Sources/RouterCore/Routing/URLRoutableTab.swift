/// A tab that can be selected from a URL path component.
///
/// Conform when you want the router to handle deep links via
/// `Router.handleDeepLink(url:)` and render ``Router/currentRoute``. Enums with `String` raw
/// values get both requirements for free, using the raw value as the path.
///
/// ## Example
///
/// ```swift
/// enum AppTab: Hashable, Sendable {
///     case home, profile, settings
/// }
///
/// extension AppTab: URLRoutableTab {
///     static func tab(from path: String) -> AppTab? {
///         switch path {
///         case "home":     return .home
///         case "profile":  return .profile
///         case "settings": return .settings
///         default:         return nil
///         }
///     }
///
///     var path: String {
///         switch self {
///         case .home:     "home"
///         case .profile:  "profile"
///         case .settings: "settings"
///         }
///     }
/// }
/// ```
public protocol URLRoutableTab: RouterTab {
	/// Returns the tab that corresponds to a leading URL path component, or `nil` if no tab
	/// matches.
	/// - Parameter path: The first path component of the URL (e.g. `"profile"`).
	static func tab(from path: String) -> Self?

	/// The path component that names this tab. ``tab(from:)`` must map it back to `self`.
	var path: String { get }
}

public extension URLRoutableTab where Self: RawRepresentable, RawValue == String {
	static func tab(from path: String) -> Self? {
		Self(rawValue: path)
	}

	var path: String {
		rawValue
	}
}
