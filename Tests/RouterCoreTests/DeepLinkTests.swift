import Foundation
import Testing
@testable import RouterCore

@MainActor
@Suite("Deep linking")
struct DeepLinkTests {
	private func url(_ string: String) throws -> URL {
		try #require(URL(string: string))
	}

	@Test("A tab URL selects the tab and replaces its stack")
	func tabURL() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .tab(.profile))

		router.handleDeepLink(url: try url("myapp://profile/friend/42"))

		#expect(router.selectedTab == .profile)
		#expect(router[.profile] == [.friend(id: 42)])
	}

	@Test("A bare tab URL selects the tab and clears its stack")
	func bareTabURL() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .tab(.settings))

		router.handleDeepLink(url: try url("myapp://settings"))

		#expect(router.selectedTab == .settings)
		#expect(router[.settings].isEmpty)
	}

	@Test("Multiple destinations are pushed in URL order")
	func multipleDestinations() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(url: try url("myapp://home/photos/friend/7/settings"))

		#expect(router[.home] == [.photos, .friend(id: 7), .settings])
	}

	@Test("Unrecognised path components reject the link instead of being skipped")
	func unknownComponentsRejected() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .settings)

		let result = router.handleDeepLink(url: try url("myapp://home/photos/nonsense/settings"))

		#expect(result.failure == .unconsumedComponents(["nonsense", "settings"]))
		#expect(router[.home] == [.settings])
	}

	@Test("An unrecognised tab leaves the router alone")
	func unknownTab() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)

		let result = router.handleDeepLink(url: try url("myapp://nonsense/photos"))

		#expect(result.failure == .unknownTab("nonsense"))
		#expect(router.selectedTab == .home)
		#expect(router[.home] == [.photos])
	}

	@Test("A sheet URL presents the sheet with its stack")
	func sheetURL() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(url: try url("myapp://sheet/checkout/photos/settings"))

		#expect(router.presentedSheet?.sheet == .checkout)
		#expect(router.presentedSheet?.stack == [.photos, .settings])
		#expect(router.selectedTab == .home)
	}

	@Test("A cover URL presents the cover with its stack")
	func coverURL() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(url: try url("myapp://cover/onboarding/photos"))

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.presentedFullscreenCover?.stack == [.photos])
	}

	@Test("A custom reserved prefix routes modals")
	func customPrefix() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(url: try url("myapp://modal/login"), sheetPrefix: "modal")

		#expect(router.presentedSheet?.sheet == .login)
	}

	@Test("Universal links can keep the host out of the route")
	func universalLink() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(
			url: try url("https://example.com/profile/friend/3"),
			treatHostAsPath: false,
		)

		#expect(router.selectedTab == .profile)
		#expect(router[.profile] == [.friend(id: 3)])
	}

	@Test("A destination missing its argument is rejected rather than mis-parsed")
	func incompleteDestination() throws {
		let router = TestRouter(initialTab: .home)

		let result = router.handleDeepLink(url: try url("myapp://home/friend"))

		#expect(result.failure == .unconsumedComponents(["friend"]))
		#expect(router[.home].isEmpty)
	}

	@Test("An unknown sheet is rejected")
	func unknownSheet() throws {
		let router = TestRouter(initialTab: .home)

		let result = router.handleDeepLink(url: try url("myapp://sheet/nowhere"))

		#expect(result.failure == .unknownSheet("nowhere"))
		#expect(router.presentedSheet == nil)
	}

	@Test("An unknown cover is rejected")
	func unknownCover() throws {
		let router = TestRouter(initialTab: .home)

		let result = router.handleDeepLink(url: try url("myapp://cover/nowhere"))

		#expect(result.failure == .unknownCover("nowhere"))
		#expect(router.presentedFullscreenCover == nil)
	}

	@Test("A link with no route, or a modal prefix with nothing after it, is malformed")
	func malformedURL() throws {
		let router = TestRouter(initialTab: .home)

		#expect(router.handleDeepLink(url: try url("myapp://")).failure == .malformedURL)
		#expect(router.handleDeepLink(url: try url("myapp://sheet")).failure == .malformedURL)
		#expect(router.handleDeepLink(url: try url("myapp://cover/")).failure == .malformedURL)
		#expect(
			router.handleDeepLink(url: try url("https://example.com"), treatHostAsPath: false).failure
				== .malformedURL
		)
	}

	@Test("A rejected modal link leaves an existing presentation alone")
	func rejectedModalLinkIsAtomic() throws {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .login)
		router.navigate(to: .photos, in: .sheet)

		let result = router.handleDeepLink(url: try url("myapp://sheet/checkout/photos/nonsense"))

		#expect(result.failure == .unconsumedComponents(["nonsense"]))
		#expect(router.presentedSheet == SheetPresentation(sheet: .login, stack: [.photos]))
	}

	@Test("A successful link reports success")
	func successResult() throws {
		let router = TestRouter(initialTab: .home)

		#expect(router.handleDeepLink(url: try url("myapp://cover/player")).isSuccess)
	}

	@Test("The router's route format sets the default prefixes")
	func routeFormatPrefixes() throws {
		let router = TestRouter(initialTab: .home)
		router.routeFormat.coverPrefix = "full"

		#expect(router.handleDeepLink(url: try url("myapp://full/player")).isSuccess)
		#expect(router.presentedFullscreenCover?.cover == .player)
	}

	@Test("Percent-encoded components are decoded before matching")
	func percentEncoded() throws {
		let router = TestRouter(initialTab: .home)

		#expect(router.handleDeepLink(url: try url("myapp://%70rofile/%66riend/5")).isSuccess)
		#expect(router[.profile] == [.friend(id: 5)])
	}

	@Test("Query parameters reach destination parsing")
	func queryParameters() throws {
		let router = Router<TestTab, QueryDestination, TestSheet, TestCover>(initialTab: .home)

		#expect(router.handleDeepLink(url: try url("myapp://home/search?q=rosary")).isSuccess)
		#expect(router[.home] == [.search(query: "rosary")])
	}

	@Test("A destination that claims to consume nothing is rejected instead of looping")
	func zeroConsumption() throws {
		let router = Router<TestTab, StuckDestination, TestSheet, TestCover>(initialTab: .home)

		let result = router.handleDeepLink(url: try url("myapp://home/stuck"))

		#expect(result.failure == .unconsumedComponents(["stuck"]))
	}
}

private enum QueryDestination: URLRoutableDestination {
	case search(query: String)

	static func destination(
		consuming pathComponents: ArraySlice<String>,
		parameters: [String: String],
	) -> (destination: QueryDestination, consumed: Int)? {
		guard pathComponents.first == "search", let query = parameters["q"] else { return nil }
		return (.search(query: query), 1)
	}

	var pathComponents: [String] {
		["search"]
	}
}

private enum StuckDestination: URLRoutableDestination {
	case stuck

	static func destination(
		consuming _: ArraySlice<String>,
		parameters _: [String: String],
	) -> (destination: StuckDestination, consumed: Int)? {
		(.stuck, 0)
	}

	var pathComponents: [String] {
		["stuck"]
	}
}
