/// A tab that can be selected from a URL path component.
///
/// Conform when you want the router to handle deep links via
/// `Router.handleDeepLink(url:)`.
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
/// }
/// ```
public protocol URLRoutableTab: RouterTab {
	/// Returns the tab that corresponds to a leading URL path component, or `nil` if no tab
	/// matches.
	/// - Parameter path: The first path component of the URL (e.g. `"profile"`).
	static func tab(from path: String) -> Self?
}
