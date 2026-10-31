import Testing
@testable import RouterCore

@MainActor
@Suite("Sheet and full-screen cover presentation")
struct ModalPresentationTests {
	// MARK: - Sheets

	@Test("Presenting a sheet stores it with an empty stack")
	func presentSheet() {
		let router = TestRouter(initialTab: .home)

		router.present(sheet: .login)

		#expect(router.presentedSheet?.sheet == .login)
		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Presenting a second sheet replaces the first, stack included")
	func presentSheetReplaces() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .login)
		router.navigateInSheet(to: .photos)

		router.present(sheet: .checkout)

		#expect(router.presentedSheet?.sheet == .checkout)
		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Navigating inside a sheet pushes onto the sheet's own stack")
	func navigateInSheet() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)

		router.navigateInSheet(to: .photos)
		router.navigateInSheet(to: .settings, .friend(id: 8))

		#expect(router.presentedSheet?.stack == [.photos, .settings, .friend(id: 8)])
		#expect(router.currentPath.isEmpty)
	}

	@Test("Sheet navigation is ignored when no sheet is presented")
	func navigateInSheetWithoutPresentation() {
		let router = TestRouter(initialTab: .home)

		router.navigateInSheet(to: .photos)
		router.popInSheet()
		router.popInSheetToRoot()

		#expect(router.presentedSheet == nil)
	}

	@Test("Popping inside a sheet removes from the top and clamps to the stack depth")
	func popInSheet() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.navigateInSheet(to: .photos, .settings)

		router.popInSheet()

		#expect(router.presentedSheet?.stack == [.photos])

		router.popInSheet(10)

		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Popping a sheet to root keeps it presented")
	func popInSheetToRoot() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.navigateInSheet(to: .photos, .settings)

		router.popInSheetToRoot()

		#expect(router.presentedSheet?.sheet == .checkout)
		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Dismissing a sheet discards its stack with it")
	func dismissSheet() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.navigateInSheet(to: .photos)

		router.dismissSheet()

		#expect(router.presentedSheet == nil)

		router.present(sheet: .checkout)

		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Presenting a sheet leaves tab navigation untouched")
	func sheetDoesNotDisturbTabs() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)

		router.present(sheet: .login)
		router.navigateInSheet(to: .settings)

		#expect(router.currentPath == [.photos])
	}

	// MARK: - Covers

	@Test("Presenting a cover stores it with an empty stack")
	func presentCover() {
		let router = TestRouter(initialTab: .home)

		router.present(fullscreenCover: .onboarding)

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.presentedFullscreenCover?.stack.isEmpty == true)
	}

	@Test("Navigating inside a cover pushes onto the cover's own stack")
	func navigateInCover() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .onboarding)

		router.navigateInFullscreenCover(to: .photos)
		router.navigateInFullscreenCover(to: .settings, .friend(id: 2))

		#expect(router.presentedFullscreenCover?.stack == [.photos, .settings, .friend(id: 2)])
		#expect(router.currentPath.isEmpty)
	}

	@Test("Cover navigation is ignored when no cover is presented")
	func navigateInCoverWithoutPresentation() {
		let router = TestRouter(initialTab: .home)

		router.navigateInFullscreenCover(to: .photos)
		router.popInFullscreenCover()
		router.popInFullscreenCoverToRoot()

		#expect(router.presentedFullscreenCover == nil)
	}

	@Test("Popping inside a cover removes from the top and clamps to the stack depth")
	func popInCover() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .onboarding)
		router.navigateInFullscreenCover(to: .photos, .settings)

		router.popInFullscreenCover()

		#expect(router.presentedFullscreenCover?.stack == [.photos])

		router.popInFullscreenCover(10)

		#expect(router.presentedFullscreenCover?.stack.isEmpty == true)
	}

	@Test("Dismissing a cover discards its stack with it")
	func dismissCover() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .onboarding)
		router.navigateInFullscreenCover(to: .photos)

		router.dismissFullscreenCover()

		#expect(router.presentedFullscreenCover == nil)
	}

	@Test("Sheets and covers hold independent stacks")
	func sheetAndCoverStacksAreIndependent() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.present(fullscreenCover: .onboarding)

		router.navigateInSheet(to: .photos)
		router.navigateInFullscreenCover(to: .settings)

		#expect(router.presentedSheet?.stack == [.photos])
		#expect(router.presentedFullscreenCover?.stack == [.settings])
	}

	// MARK: - Cover replacement

	@Test("Replacing with no cover presented presents immediately and queues nothing")
	func replaceWithNothingPresented() {
		let router = TestRouter(initialTab: .home)

		router.replace(fullscreenCover: .onboarding)

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.pendingFullscreenCover == nil)
	}

	@Test("Replacing a live cover dismisses it and queues the replacement")
	func replaceWhilePresented() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .player)
		router.navigateInFullscreenCover(to: .photos)

		router.replace(fullscreenCover: .onboarding)

		#expect(router.presentedFullscreenCover == nil)
		#expect(router.pendingFullscreenCover == .onboarding)
	}

	@Test("Draining the queue returns the replacement once and clears it")
	func takePendingCover() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .player)
		router.replace(fullscreenCover: .onboarding)

		#expect(router.takePendingFullscreenCover() == .onboarding)
		#expect(router.pendingFullscreenCover == nil)
		#expect(router.takePendingFullscreenCover() == nil)
	}

	@Test("Draining an empty queue is safe on every dismissal")
	func takePendingCoverWhenEmpty() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .onboarding)
		router.dismissFullscreenCover()

		#expect(router.takePendingFullscreenCover() == nil)
	}

	@Test("The full replace round trip leaves only the replacement presented")
	func replaceRoundTrip() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .player)
		router.navigateInFullscreenCover(to: .photos)

		router.replace(fullscreenCover: .onboarding)
		if let next = router.takePendingFullscreenCover() {
			router.present(fullscreenCover: next)
		}

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.presentedFullscreenCover?.stack.isEmpty == true)
		#expect(router.pendingFullscreenCover == nil)
	}

	@Test("Replacing twice before draining keeps only the latest replacement")
	func replaceTwiceKeepsLatest() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .player)

		router.replace(fullscreenCover: .onboarding)
		router.replace(fullscreenCover: .player)

		#expect(router.pendingFullscreenCover == .player)
	}

	@Test("Dismissing cancels a queued replacement")
	func dismissClearsPendingCover() {
		let router = TestRouter(initialTab: .home)
		router.present(fullscreenCover: .player)
		router.replace(fullscreenCover: .onboarding)

		router.dismissFullscreenCover()

		#expect(router.pendingFullscreenCover == nil)
		#expect(router.presentedFullscreenCover == nil)
	}
}
