import Foundation

/// The URL scheme and reserved prefixes a router uses to render and parse routes.
///
/// A route is a URL without its scheme: `profile/friend/42`, `sheet/checkout/payment`, or
/// `cover/onboarding`.
public struct RouteFormat: Hashable, Sendable {
	/// The scheme ``url(for:)`` puts in front of a route, such as `"myapp"`.
	public var scheme: String

	/// The reserved first component that signals a sheet presentation.
	public var sheetPrefix: String

	/// The reserved first component that signals a full-screen cover presentation.
	public var coverPrefix: String

	/// Creates a route format.
	/// - Parameters:
	///   - scheme: The URL scheme for routes. Defaults to `"router"`.
	///   - sheetPrefix: The sheet prefix. Defaults to `"sheet"`.
	///   - coverPrefix: The cover prefix. Defaults to `"cover"`.
	public init(scheme: String = "router", sheetPrefix: String = "sheet", coverPrefix: String = "cover") {
		self.scheme = scheme
		self.sheetPrefix = sheetPrefix
		self.coverPrefix = coverPrefix
	}

	/// Builds the custom-scheme URL for a route, or `nil` if the route can't form a valid URL.
	///
	/// Leading slashes are ignored, so `"/profile"` and `"profile"` produce the same URL.
	/// - Parameter route: A route such as `"profile/friend/42"`.
	public func url(for route: String) -> URL? {
		let trimmed = route.drop { $0 == "/" }
		guard !trimmed.isEmpty else { return nil }
		return URL(string: "\(scheme)://\(trimmed)")
	}

	static func encode(_ component: String) -> String {
		component.addingPercentEncoding(withAllowedCharacters: pathComponentAllowed) ?? component
	}

	private static let pathComponentAllowed = CharacterSet.urlPathAllowed.subtracting(["/"])
}
