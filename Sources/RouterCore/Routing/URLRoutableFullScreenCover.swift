/// A full-screen cover that can be identified from a URL path component.
///
/// Conform when you want the router to recognize full-screen-cover deep links via
/// `Router.handleDeepLink(url:)`. Cover URLs are identified by a reserved prefix component
/// (`"cover"` by default), followed by the cover identifier and any destinations to push onto
/// the cover's stack:
///
/// ```
/// myapp://cover/onboarding/welcome
///           │       │         └── destination pushed inside the cover
///           │       └── cover identifier
///           └── reserved prefix
/// ```
///
/// ## Example
///
/// ```swift
/// enum AppCover: Hashable, Sendable, RouterFullScreenCover {
///     case onboarding
///     case videoPlayer(id: UUID)
/// }
///
/// extension AppCover: URLRoutableFullScreenCover {
///     static func cover(from path: String) -> AppCover? {
///         switch path {
///         case "onboarding": return .onboarding
///         default:           return nil
///         }
///     }
///
///     var path: String {
///         switch self {
///         case .onboarding:  "onboarding"
///         case .videoPlayer: "video-player"
///         }
///     }
/// }
/// ```
public protocol URLRoutableFullScreenCover: RouterFullScreenCover {
	/// Returns the cover that corresponds to a URL path component, or `nil` if no cover matches.
	/// - Parameter path: The path component following the cover prefix (e.g. `"onboarding"`).
	static func cover(from path: String) -> Self?

	/// The path component that names this cover. ``cover(from:)`` must map it back to `self`.
	var path: String { get }
}

public extension URLRoutableFullScreenCover where Self: RawRepresentable, RawValue == String {
	static func cover(from path: String) -> Self? {
		Self(rawValue: path)
	}

	var path: String {
		rawValue
	}
}
