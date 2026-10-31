/// A destination that can be reconstructed from URL path components.
///
/// Conform when you want the router to handle deep links via
/// `Router.handleDeepLink(url:)` and render ``Router/currentRoute``.
///
/// The protocol uses a "consume" model: each call inspects the leading path components and
/// reports both the destination it constructed *and* how many components it consumed. This
/// lets a single destination span multiple path segments (e.g. `friend/42` → one
/// `.friend(id: 42)` destination).
///
/// ## Example
///
/// ```swift
/// enum AppDestination: Hashable, Sendable {
///     case friend(id: Int)
///     case photos
///     case settings
/// }
///
/// extension AppDestination: URLRoutableDestination {
///     static func destination(
///         consuming components: ArraySlice<String>,
///         parameters: [String: String]
///     ) -> (destination: AppDestination, consumed: Int)? {
///         guard let head = components.first else { return nil }
///         switch head {
///         case "friend":
///             guard let idString = components.dropFirst().first,
///                   let id = Int(idString) else { return nil }
///             return (.friend(id: id), 2)
///         case "photos":   return (.photos, 1)
///         case "settings": return (.settings, 1)
///         default:         return nil
///         }
///     }
///
///     var pathComponents: [String] {
///         switch self {
///         case .friend(let id): ["friend", String(id)]
///         case .photos:         ["photos"]
///         case .settings:       ["settings"]
///         }
///     }
/// }
/// ```
public protocol URLRoutableDestination: RouterDestination {
	/// Builds a destination from the leading components of a URL path.
	///
	/// - Parameters:
	///   - pathComponents: The remaining unprocessed path components, with the candidate
	///     component at index `startIndex`.
	///   - parameters: The URL's query parameters, keyed by name.
	/// - Returns: The destination and the number of components it consumed, or `nil` if no
	///   destination matches the leading components. `consumed` must be at least 1.
	static func destination(
		consuming pathComponents: ArraySlice<String>,
		parameters: [String: String]
	) -> (destination: Self, consumed: Int)?

	/// The path components that render this destination. Passing them to
	/// ``destination(consuming:parameters:)`` must return `self` and consume all of them.
	var pathComponents: [String] { get }
}
