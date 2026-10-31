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
///
///     var path: String {
///         switch self {
///         case .login:    "login"
///         case .checkout: "checkout"
///         }
///     }
/// }
/// ```
public protocol URLRoutableSheet: RouterSheet {
	/// Returns the sheet that corresponds to a URL path component, or `nil` if no sheet matches.
	/// - Parameter path: The path component following the sheet prefix (e.g. `"checkout"`).
	static func sheet(from path: String) -> Self?

	/// The path component that names this sheet. ``sheet(from:)`` must map it back to `self`.
	var path: String { get }
}

public extension URLRoutableSheet where Self: RawRepresentable, RawValue == String {
	static func sheet(from path: String) -> Self? {
		Self(rawValue: path)
	}

	var path: String {
		rawValue
	}
}
