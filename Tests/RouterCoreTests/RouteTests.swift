import Foundation
import Testing
@testable import RouterCore

@MainActor
@Suite("Routes")
struct RouteTests {
	private enum PlainSheet: RouterSheet { case only }
	private enum PlainCover: RouterFullScreenCover { case only }
	private typealias PlainModalRouter = Router<TestTab, TestDestination, PlainSheet, PlainCover>

	@Test("A tab route names the selected tab and its stack")
	func tabRoute() {
		let router = TestRouter(initialTab: .home)
		#expect(router.currentRoute == "home")

		router.navigate(to: .friend(id: 42), .photos, in: .profile)
		router.switchTab(to: .profile)

		#expect(router.currentRoute == "profile/friend/42/photos")
	}

	@Test("A presented sheet takes over the route")
	func sheetRoute() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)
		router.present(sheet: .checkout)

		#expect(router.currentRoute == "sheet/checkout")

		router.navigateInSheet(to: .settings)

		#expect(router.currentRoute == "sheet/checkout/settings")
	}

	@Test("A presented cover takes over the route, even over a sheet")
	func coverRoute() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.present(fullscreenCover: .onboarding)
		router.navigateInFullscreenCover(to: .friend(id: 7))

		#expect(router.currentRoute == "cover/onboarding/friend/7")
	}

	@Test("Modals whose types aren't URL-routable are left out of the route")
	func unroutableModals() {
		let router = PlainModalRouter(initialTab: .settings)
		router.navigate(to: .photos)
		router.present(sheet: .only)
		router.present(fullscreenCover: .only)

		#expect(router.currentRoute == "settings/photos")
	}

	@Test("The route uses the router's prefixes, and the static form takes them explicitly")
	func customPrefixes() {
		let router = TestRouter(initialTab: .home)
		router.routeFormat = RouteFormat(scheme: "myapp", sheetPrefix: "modal", coverPrefix: "full")
		router.present(sheet: .login)

		#expect(router.currentRoute == "modal/login")
		#expect(TestRouter.route(for: router.snapshot) == "sheet/login")
		#expect(TestRouter.route(for: router.snapshot, format: router.routeFormat) == "modal/login")
	}

	@Test("Route components are percent-encoded so slashes can't split them")
	func encoding() {
		#expect(RouteFormat.encode("a b/c") == "a%20b%2Fc")
		#expect(RouteFormat.encode("friend") == "friend")
	}

	@Test("Following the current route as a deep link leaves every generated state unchanged")
	func deepLinkRoundTrip() throws {
		for snapshot in StateGenerator.snapshots() {
			let router = TestRouter(snapshot: snapshot)
			let url = try #require(router.routeFormat.url(for: router.currentRoute))

			#expect(router.handleDeepLink(url: url).isSuccess)
			#expect(router.snapshot == snapshot)
		}
	}

	@Test("Navigating to the current route leaves every generated state unchanged")
	func navigateRoundTrip() {
		for snapshot in StateGenerator.snapshots(seed: 0xC0FFEE) {
			let router = TestRouter(snapshot: snapshot)
			router.routeFormat = RouteFormat(scheme: "myapp", sheetPrefix: "s", coverPrefix: "c")

			#expect(router.navigate(route: router.currentRoute).isSuccess)
			#expect(router.snapshot == snapshot)
		}
	}

	@Test("Navigating by route builds the URL with the configured scheme")
	func navigateUsesScheme() throws {
		let router = TestRouter(initialTab: .home)
		router.routeFormat.scheme = "rosary"
		var handled: [URL] = []
		router.onEvent = { event in
			if case let .deepLinkHandled(url) = event { handled.append(url) }
		}

		#expect(router.navigate(route: "/profile/friend/3").isSuccess)

		#expect(handled == [try #require(URL(string: "rosary://profile/friend/3"))])
		#expect(router.selectedTab == .profile)
		#expect(router[.profile] == [.friend(id: 3)])
	}

	@Test("Navigating by route reports failures")
	func navigateFailures() {
		let router = TestRouter(initialTab: .home)

		#expect(router.navigate(route: "").failure == .malformedURL)
		#expect(router.navigate(route: "///").failure == .malformedURL)
		#expect(router.navigate(route: "nowhere").failure == .unknownTab("nowhere"))
		#expect(router.navigate(route: "sheet/checkout/oops").failure == .unconsumedComponents(["oops"]))
		#expect(router.snapshot == TestRouter.Snapshot(selectedTab: .home))
	}

	@Test("String-backed enums get their route names from their raw values")
	func rawValueDefaults() {
		enum RawTab: String, URLRoutableTab { case home, library }
		enum RawSheet: String, URLRoutableSheet { case share }
		enum RawCover: String, URLRoutableFullScreenCover { case reader }
		let router = Router<RawTab, TestDestination, RawSheet, RawCover>(initialTab: .home)

		#expect(router.navigate(route: "library/photos").isSuccess)
		#expect(router.currentRoute == "library/photos")
		#expect(router.navigate(route: "sheet/share").isSuccess)
		#expect(router.currentRoute == "sheet/share")
		#expect(router.navigate(route: "cover/reader").isSuccess)
		#expect(router.currentRoute == "cover/reader")
		#expect(router.navigate(route: "cover/nope").failure == .unknownCover("nope"))
	}
}
