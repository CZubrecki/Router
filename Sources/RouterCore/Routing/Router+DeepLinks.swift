import Foundation

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
	/// The matched destination's existing stack is *replaced* with the parsed destinations.
	/// Components that no destination claims are skipped silently.
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
	///   - sheetPrefix: The reserved first path component that signals a sheet presentation.
	///     Defaults to `"sheet"`.
	///   - coverPrefix: The reserved first path component that signals a full-screen cover
	///     presentation. Defaults to `"cover"`.
	func handleDeepLink(
		url: URL,
		treatHostAsPath: Bool = true,
		sheetPrefix: String = "sheet",
		coverPrefix: String = "cover",
	) {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return
		}

		var pathComponents = components.path
			.split(separator: "/")
			.map(String.init)
			.filter { !$0.isEmpty }

		if treatHostAsPath, let host = components.host, !host.isEmpty {
			pathComponents.insert(host, at: 0)
		}

		guard let firstComponent = pathComponents.first else { return }

		var parameters: [String: String] = [:]
		components.queryItems?.forEach { item in
			parameters[item.name] = item.value ?? ""
		}

		// Sheet prefix
		if firstComponent == sheetPrefix,
		   pathComponents.count >= 2,
		   let sheetType = Sheet.self as? any URLRoutableSheet.Type,
		   let sheet = sheetType.sheet(from: pathComponents[1]) as? Sheet
		{
			let remaining = pathComponents.dropFirst(2)
			let destinations = parseDestinations(remaining, parameters: parameters)
			presentedSheet = SheetPresentation(sheet: sheet, stack: destinations)
			return
		}

		// Cover prefix
		if firstComponent == coverPrefix,
		   pathComponents.count >= 2,
		   let coverType = FullscreenCover.self as? any URLRoutableFullScreenCover.Type,
		   let cover = coverType.cover(from: pathComponents[1]) as? FullscreenCover
		{
			let remaining = pathComponents.dropFirst(2)
			let destinations = parseDestinations(remaining, parameters: parameters)
			presentedFullscreenCover = FullscreenCoverPresentation(cover: cover, stack: destinations)
			return
		}

		// Tab routing
		guard let tab = Tab.tab(from: firstComponent) else { return }
		let remaining = pathComponents.dropFirst()
		let destinations = parseDestinations(remaining, parameters: parameters)
		selectedTab = tab
		self[tab] = destinations
	}

	private func parseDestinations(
		_ components: ArraySlice<String>,
		parameters: [String: String],
	) -> [Destination] {
		var remaining = components
		var destinations: [Destination] = []

		while !remaining.isEmpty {
			guard let result = Destination.destination(
				consuming: remaining,
				parameters: parameters,
			) else {
				remaining = remaining.dropFirst()
				continue
			}
			destinations.append(result.destination)
			remaining = remaining.dropFirst(result.consumed)
		}

		return destinations
	}
}
