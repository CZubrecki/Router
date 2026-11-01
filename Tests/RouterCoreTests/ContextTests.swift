import Testing
@testable import RouterCore

@MainActor
@Suite("Contexts")
struct ContextTests {
	@Test("The current-tab default resolves at call time, after a switch")
	func currentTabResolvesLate() {
		let router = TestRouter(initialTab: .home)
		var events: [TestRouter.NavigationEvent] = []
		router.onEvent = { events.append($0) }

		router.switchTab(to: .settings)
		router.navigate(to: .photos)
		router.pop()

		#expect(events == [
			.switchedTab(from: .home, to: .settings),
			.pushed([.photos], in: .tab(.settings)),
			.popped(count: 1, in: .tab(.settings)),
		])
	}

	@Test("Every stack verb accepts every context")
	func everyVerbEveryContext() {
		let contexts: [TestRouter.Context] = [.tab(.profile), .currentTab, .sheet, .cover]
		for context in contexts {
			let router = TestRouter(initialTab: .home)
			router.present(sheet: .login)
			router.present(cover: .player)

			router.navigate(to: .photos, .settings, .friend(id: 1), in: context)
			router.pop(in: context)
			router.popTo(.photos, in: context)
			router.replaceStack([.settings, .photos, .settings], in: context)
			router.pop(2, in: context)

			let stack: [TestDestination] = switch context {
			case .tab(let tab): router[tab]
			case .currentTab: router.currentPath
			case .sheet: router.presentedSheet?.stack ?? []
			case .cover: router.presentedFullscreenCover?.stack ?? []
			}
			#expect(stack == [.settings], "\(context)")

			router.popToRoot(in: context)

			#expect(router.snapshot.paths.isEmpty, "\(context)")
			#expect(router.presentedSheet == SheetPresentation(sheet: .login), "\(context)")
			#expect(router.presentedFullscreenCover == FullscreenCoverPresentation(cover: .player), "\(context)")
		}
	}

	@Test("Dismissing reaches only the named modal")
	func dismissIsTargeted() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .login)
		router.present(cover: .player)

		router.dismiss(.sheet)

		#expect(router.presentedSheet == nil)
		#expect(router.presentedFullscreenCover?.cover == .player)

		router.dismiss(.cover)

		#expect(router.presentedFullscreenCover == nil)
	}
}
