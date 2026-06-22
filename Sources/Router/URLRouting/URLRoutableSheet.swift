/// A sheet that can be identified from a URL path component.
///
/// Conform when you want the router to recognize sheet deep links via
/// `Router.handleDeepLink(url:)`. Sheet URLs are identified by a reserved prefix component
/// (`"sheet"` by default), followed by the sheet identifier and any destinations to push onto
/// the sheet's stack:
///
/// ```
/// myapp://sheet/checkout/payment/confirm
///           │       │       └────┴── destinations pushed inside the sheet
///           │       └── sheet identifier
///           └── reserved prefix
/// ```
///
/// ## Example
///
/// ```swift
/// enum AppSheet: Hashable, Sendable, RouterSheet {
///     case login
///     case checkout
/// }
///
/// extension AppSheet: URLRoutableSheet {
///     static func sheet(from path: String) -> AppSheet? {
///         switch path {
///         case "login":    return .login
///         case "checkout": return .checkout
///         default:         return nil
///         }
///     }
/// }
/// ```
public protocol URLRoutableSheet: RouterSheet {
	/// Returns the sheet that corresponds to a URL path component, or `nil` if no sheet matches.
	/// - Parameter path: The path component following the sheet prefix (e.g. `"checkout"`).
	static func sheet(from path: String) -> Self?
}
