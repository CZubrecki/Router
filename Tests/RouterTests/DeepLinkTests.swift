import Foundation
import Testing
@testable import Router

@MainActor
@Suite("Deep linking")
struct DeepLinkTests {
	private func url(_ string: String) throws -> URL {
		try #require(URL(string: string))
	}

	@Test("A tab URL selects the tab and replaces its stack")
	func tabURL() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .profile)

		router.handleDeepLink(url: try url("myapp://profile/friend/42"))

		#expect(router.selectedTab == .profile)
		#expect(router[.profile] == [.friend(id: 42)])
	}

	@Test("A bare tab URL selects the tab and clears its stack")
	func bareTabURL() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .settings)

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

	@Test("Unrecognised path components are skipped")
	func unknownComponentsSkipped() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(url: try url("myapp://home/nonsense/photos"))

		#expect(router[.home] == [.photos])
	}

	@Test("An unrecognised tab leaves the router alone")
	func unknownTab() throws {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)

		router.handleDeepLink(url: try url("myapp://nonsense/photos"))

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

	@Test("A destination missing its argument is skipped rather than mis-parsed")
	func incompleteDestination() throws {
		let router = TestRouter(initialTab: .home)

		router.handleDeepLink(url: try url("myapp://home/friend"))

		#expect(router[.home].isEmpty)
	}
}
