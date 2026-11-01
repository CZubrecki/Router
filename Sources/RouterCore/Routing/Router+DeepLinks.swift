import Foundation

extension Router {
	enum DeepLinkTarget {
		case tab(Tab, [Destination])
		case sheet(Sheet, [Destination])
		case cover(FullscreenCover, [Destination])
	}
}

public extension Router where Tab: URLRoutableTab, Destination: URLRoutableDestination {
	/// Routes a URL into the router as a tab change, sheet presentation, or full-screen cover
	/// presentation.
	///
	/// URLs are dispatched by the first path component:
	///
	/// | URL shape                                       | Effect                              |
	/// |-------------------------------------------------|-------------------------------------|
	/// | `myapp://[tab]/[dest…]`                         | Select tab, replace its stack       |
	/// | `myapp://sheet/[sheet]/[dest…]`                 | Present sheet with stack inside     |
	/// | `myapp://cover/[cover]/[dest…]`                 | Present cover with stack inside     |
	///
	/// Sheet and cover prefixes only match when the corresponding type conforms to
	/// `URLRoutableSheet` / `URLRoutableFullScreenCover`. Otherwise, the router falls through to
	/// tab routing.
	///
	/// The matched destination's existing stack is *replaced* with the parsed destinations. Every
	/// path component must be claimed: a component no destination recognises rejects the whole
	/// link with ``DeepLinkError/unconsumedComponents(_:)`` and leaves the router unchanged.
	/// Emits ``NavigationEvent/deepLinkHandled(_:)`` or ``NavigationEvent/deepLinkRejected(_:_:)``.
	///
	/// ## Example
	///
	/// ```swift
	/// // myapp://profile/friend/42        →  tab .profile, stack [.friend(id: 42)]
	/// // myapp://sheet/checkout/payment   →  presented sheet .checkout, sheet stack [.payment]
	/// // myapp://cover/onboarding         →  presented cover .onboarding, cover stack []
	/// router.handleDeepLink(url: url)
	/// ```
	///
	/// - Parameters:
	///   - url: The incoming URL.
	///   - treatHostAsPath: When `true` (the default), the URL's host is prepended to the path
	///     components. Use this for custom URL schemes like `myapp://profile/...` where the
	///     host *is* part of the route. Set to `false` for universal links
	///     (`https://example.com/profile/...`) where the host is the domain.
	///   - sheetPrefix: The reserved first path component that signals a sheet presentation, or
	///     `nil` to use ``Router/routeFormat``. Defaults to `nil`.
	///   - coverPrefix: The reserved first path component that signals a full-screen cover
	///     presentation, or `nil` to use ``Router/routeFormat``. Defaults to `nil`.
	/// - Returns: `.success` when the link was applied, or the reason it was rejected.
	@discardableResult
	func handleDeepLink(
		url: URL,
		treatHostAsPath: Bool = true,
		sheetPrefix: String? = nil,
		coverPrefix: String? = nil,
	) -> Result<Void, DeepLinkError> {
		var format = routeFormat
		format.sheetPrefix = sheetPrefix ?? format.sheetPrefix
		format.coverPrefix = coverPrefix ?? format.coverPrefix

		switch Self.target(for: url, treatHostAsPath: treatHostAsPath, format: format) {
		case let .success(target):
			apply(target, from: url)
			return .success(())
		case let .failure(error):
			emit(.deepLinkRejected(url, error))
			return .failure(error)
		}
	}

	/// Navigates to a route string such as `"profile/friend/42"` or `"sheet/checkout"`.
	///
	/// Builds a URL with ``Router/routeFormat``'s scheme and passes it to
	/// ``handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)``.
	/// - Parameter route: The route to apply.
	/// - Returns: `.success` when the route was applied, or the reason it was rejected.
	@discardableResult
	func navigate(route: String) -> Result<Void, DeepLinkError> {
		guard let url = routeFormat.url(for: route) else { return .failure(.malformedURL) }
		return handleDeepLink(url: url)
	}

	/// The route that leads to the router's current location, using ``Router/routeFormat``'s
	/// prefixes.
	///
	/// The location is the presented cover if any, else the presented sheet, else the selected
	/// tab, followed by that place's stack: `profile/friend/42`, `sheet/checkout/payment`. A sheet
	/// or cover whose type isn't URL-routable is skipped. Passing the route to
	/// ``navigate(route:)`` leaves the router's ``snapshot`` unchanged.
	var currentRoute: String {
		Self.route(for: snapshot, format: routeFormat)
	}

	/// Renders the route for a snapshot's current location. See ``currentRoute``.
	/// - Parameters:
	///   - snapshot: The state to render.
	///   - format: The prefixes to use. Defaults to the standard `sheet` and `cover` prefixes.
	/// - Returns: A route string such as `"profile/friend/42"`.
	nonisolated static func route(for snapshot: Snapshot, format: RouteFormat = RouteFormat()) -> String {
		let components: [String]
		if let presentation = snapshot.presentedFullscreenCover,
		   let cover = presentation.cover as? any URLRoutableFullScreenCover
		{
			components = [format.coverPrefix, cover.path] + presentation.stack.flatMap(\.pathComponents)
		} else if let presentation = snapshot.presentedSheet,
		          let sheet = presentation.sheet as? any URLRoutableSheet
		{
			components = [format.sheetPrefix, sheet.path] + presentation.stack.flatMap(\.pathComponents)
		} else {
			let stack = snapshot.paths[snapshot.selectedTab, default: []]
			components = [snapshot.selectedTab.path] + stack.flatMap(\.pathComponents)
		}
		return components.map(RouteFormat.encode).joined(separator: "/")
	}

	private nonisolated static func target(
		for url: URL,
		treatHostAsPath: Bool,
		format: RouteFormat,
	) -> Result<DeepLinkTarget, DeepLinkError> {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return .failure(.malformedURL)
		}

		var pathComponents = components.percentEncodedPath
			.split(separator: "/")
			.map { $0.removingPercentEncoding ?? String($0) }
		if treatHostAsPath, let host = components.percentEncodedHost, !host.isEmpty {
			pathComponents.insert(host.removingPercentEncoding ?? host, at: 0)
		}

		guard let first = pathComponents.first else { return .failure(.malformedURL) }

		var parameters: [String: String] = [:]
		components.queryItems?.forEach { item in
			parameters[item.name] = item.value ?? ""
		}

		if first == format.sheetPrefix, let sheetType = Sheet.self as? any URLRoutableSheet.Type {
			guard pathComponents.count >= 2 else { return .failure(.malformedURL) }
			guard let sheet = sheetType.sheet(from: pathComponents[1]) as? Sheet else {
				return .failure(.unknownSheet(pathComponents[1]))
			}
			return destinations(pathComponents.dropFirst(2), parameters: parameters)
				.map { .sheet(sheet, $0) }
		}

		if first == format.coverPrefix, let coverType = FullscreenCover.self as? any URLRoutableFullScreenCover.Type {
			guard pathComponents.count >= 2 else { return .failure(.malformedURL) }
			guard let cover = coverType.cover(from: pathComponents[1]) as? FullscreenCover else {
				return .failure(.unknownCover(pathComponents[1]))
			}
			return destinations(pathComponents.dropFirst(2), parameters: parameters)
				.map { .cover(cover, $0) }
		}

		guard let tab = Tab.tab(from: first) else { return .failure(.unknownTab(first)) }
		return destinations(pathComponents.dropFirst(), parameters: parameters)
			.map { .tab(tab, $0) }
	}

	private nonisolated static func destinations(
		_ components: ArraySlice<String>,
		parameters: [String: String],
	) -> Result<[Destination], DeepLinkError> {
		var remaining = components
		var destinations: [Destination] = []

		while !remaining.isEmpty {
			guard let result = Destination.destination(consuming: remaining, parameters: parameters),
			      (1...remaining.count).contains(result.consumed)
			else {
				return .failure(.unconsumedComponents(Array(remaining)))
			}
			destinations.append(result.destination)
			remaining = remaining.dropFirst(result.consumed)
		}

		return .success(destinations)
	}
}
