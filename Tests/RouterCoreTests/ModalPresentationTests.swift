import Foundation
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
		router.navigate(to: .photos, in: .sheet)

		router.present(sheet: .checkout)

		#expect(router.presentedSheet?.sheet == .checkout)
		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Navigating inside a sheet pushes onto the sheet's own stack")
	func navigateInSheet() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)

		router.navigate(to: .photos, in: .sheet)
		router.navigate(to: .settings, .friend(id: 8), in: .sheet)

		#expect(router.presentedSheet?.stack == [.photos, .settings, .friend(id: 8)])
		#expect(router.currentPath.isEmpty)
	}

	@Test("Sheet navigation is ignored when no sheet is presented")
	func navigateInSheetWithoutPresentation() {
		let router = TestRouter(initialTab: .home)

		router.navigate(to: .photos, in: .sheet)
		router.pop(in: .sheet)
		router.popToRoot(in: .sheet)

		#expect(router.presentedSheet == nil)
	}

	@Test("Popping inside a sheet removes from the top and clamps to the stack depth")
	func popInSheet() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.navigate(to: .photos, .settings, in: .sheet)

		router.pop(in: .sheet)

		#expect(router.presentedSheet?.stack == [.photos])

		router.pop(10, in: .sheet)

		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Popping a sheet to root keeps it presented")
	func popInSheetToRoot() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.navigate(to: .photos, .settings, in: .sheet)

		router.popToRoot(in: .sheet)

		#expect(router.presentedSheet?.sheet == .checkout)
		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Dismissing a sheet discards its stack with it")
	func dismissSheet() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.navigate(to: .photos, in: .sheet)

		router.dismiss(.sheet)

		#expect(router.presentedSheet == nil)

		router.present(sheet: .checkout)

		#expect(router.presentedSheet?.stack.isEmpty == true)
	}

	@Test("Presenting a sheet leaves tab navigation untouched")
	func sheetDoesNotDisturbTabs() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)

		router.present(sheet: .login)
		router.navigate(to: .settings, in: .sheet)

		#expect(router.currentPath == [.photos])
	}

	// MARK: - Covers

	@Test("Presenting a cover stores it with an empty stack")
	func presentCover() {
		let router = TestRouter(initialTab: .home)

		router.present(cover: .onboarding)

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.presentedFullscreenCover?.stack.isEmpty == true)
	}

	@Test("Navigating inside a cover pushes onto the cover's own stack")
	func navigateInCover() {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .onboarding)

		router.navigate(to: .photos, in: .cover)
		router.navigate(to: .settings, .friend(id: 2), in: .cover)

		#expect(router.presentedFullscreenCover?.stack == [.photos, .settings, .friend(id: 2)])
		#expect(router.currentPath.isEmpty)
	}

	@Test("Cover navigation is ignored when no cover is presented")
	func navigateInCoverWithoutPresentation() {
		let router = TestRouter(initialTab: .home)

		router.navigate(to: .photos, in: .cover)
		router.pop(in: .cover)
		router.popToRoot(in: .cover)

		#expect(router.presentedFullscreenCover == nil)
	}

	@Test("Popping inside a cover removes from the top and clamps to the stack depth")
	func popInCover() {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .onboarding)
		router.navigate(to: .photos, .settings, in: .cover)

		router.pop(in: .cover)

		#expect(router.presentedFullscreenCover?.stack == [.photos])

		router.pop(10, in: .cover)

		#expect(router.presentedFullscreenCover?.stack.isEmpty == true)
	}

	@Test("Dismissing a cover discards its stack with it")
	func dismissCover() {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .onboarding)
		router.navigate(to: .photos, in: .cover)

		router.dismiss(.cover)

		#expect(router.presentedFullscreenCover == nil)
	}

	@Test("Sheets and covers hold independent stacks")
	func sheetAndCoverStacksAreIndependent() {
		let router = TestRouter(initialTab: .home)
		router.present(sheet: .checkout)
		router.present(cover: .onboarding)

		router.navigate(to: .photos, in: .sheet)
		router.navigate(to: .settings, in: .cover)

		#expect(router.presentedSheet?.stack == [.photos])
		#expect(router.presentedFullscreenCover?.stack == [.settings])
	}

	// MARK: - Cover replacement

	@Test("Replacing with no cover presented presents immediately and queues nothing")
	func replaceWithNothingPresented() {
		let router = TestRouter(initialTab: .home)

		router.replace(cover: .onboarding)

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.pendingFullscreenCover == nil)
	}

	@Test("Replacing a live cover dismisses it and queues the replacement")
	func replaceWhilePresented() {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.navigate(to: .photos, in: .cover)

		router.replace(cover: .onboarding)

		#expect(router.presentedFullscreenCover == nil)
		#expect(router.pendingFullscreenCover == .onboarding)
	}

	@Test("The router presents the queued replacement itself on the next main-actor turn")
	func replacementPresentsItself() async {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.navigate(to: .photos, in: .cover)

		router.replace(cover: .onboarding)
		await router.pendingCoverTask?.value

		#expect(router.presentedFullscreenCover == FullscreenCoverPresentation(cover: .onboarding))
		#expect(router.pendingFullscreenCover == nil)
		#expect(router.pendingCoverTask == nil)
	}

	@Test("A cover dismissed through its binding hands off to the queued replacement")
	func bindingDismissalHandsOff() async {
		let router = TestRouter(initialTab: .home)
		router.restore(TestRouter.Snapshot(selectedTab: .home, pendingFullscreenCover: .player))
		router.presentedFullscreenCover = FullscreenCoverPresentation(cover: .onboarding)

		#expect(router.pendingFullscreenCover == nil)

		router.restore(TestRouter.Snapshot(
			selectedTab: .home,
			presentedFullscreenCover: FullscreenCoverPresentation(cover: .onboarding),
			pendingFullscreenCover: .player,
		))
		router.presentedFullscreenCover = nil
		await router.pendingCoverTask?.value

		#expect(router.presentedFullscreenCover?.cover == .player)
	}

	@Test("A restored snapshot with a queued cover presents it")
	func restoredPendingCoverPresents() async {
		let router = TestRouter(snapshot: TestRouter.Snapshot(selectedTab: .home, pendingFullscreenCover: .player))

		#expect(router.pendingFullscreenCover == .player)

		await router.pendingCoverTask?.value

		#expect(router.presentedFullscreenCover?.cover == .player)
		#expect(router.pendingFullscreenCover == nil)
	}

	@Test("Presenting or deep-linking a cover directly supersedes a queued replacement")
	func directPresentationSupersedes() async throws {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.replace(cover: .onboarding)
		let task = try #require(router.pendingCoverTask)

		router.present(cover: .player)
		await task.value

		#expect(router.presentedFullscreenCover?.cover == .player)
		#expect(router.pendingFullscreenCover == nil)

		router.replace(cover: .onboarding)
		router.handleDeepLink(url: try #require(URL(string: "myapp://cover/player/photos")))
		await router.pendingCoverTask?.value

		#expect(router.presentedFullscreenCover == FullscreenCoverPresentation(cover: .player, stack: [.photos]))
		#expect(router.pendingFullscreenCover == nil)
	}

	@Test("Replacing twice before the handoff presents only the latest replacement")
	func replaceTwiceKeepsLatest() async {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)

		router.replace(cover: .onboarding)
		router.replace(cover: .player)

		#expect(router.pendingFullscreenCover == .player)

		await router.pendingCoverTask?.value

		#expect(router.presentedFullscreenCover?.cover == .player)
	}

	@Test("Dismissing cancels a queued replacement")
	func dismissClearsPendingCover() async throws {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.replace(cover: .onboarding)
		let task = try #require(router.pendingCoverTask)

		router.dismiss(.cover)
		await task.value

		#expect(router.pendingFullscreenCover == nil)
		#expect(router.presentedFullscreenCover == nil)
		#expect(router.pendingCoverTask == nil)
	}

	// MARK: - Host handoff

	@Test("A replacement waits for the host to finish dismissing a cover it showed")
	func replacementWaitsForHostDismissal() async {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.coverDidAppear()

		router.replace(cover: .onboarding)
		for _ in 0..<10 { await Task.yield() }

		#expect(router.pendingCoverTask == nil)
		#expect(router.presentedFullscreenCover == nil)
		#expect(router.pendingFullscreenCover == .onboarding)

		router.coverDidDismiss()

		#expect(router.presentedFullscreenCover == FullscreenCoverPresentation(cover: .onboarding))
		#expect(router.pendingFullscreenCover == nil)
	}

	@Test("A host dismissal ends the wait for every later replacement")
	func hostDismissalResetsHandoff() async {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.coverDidAppear()
		router.dismiss(.cover)
		router.coverDidDismiss()

		#expect(router.presentedFullscreenCover == nil)

		router.present(cover: .player)
		router.replace(cover: .onboarding)
		await router.pendingCoverTask?.value

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
	}

	@Test("A host dismissal before the next turn presents the replacement at once")
	func hostDismissalPreemptsTask() async throws {
		let router = TestRouter(initialTab: .home)
		var presented: [TestCover] = []
		router.onEvent = { event in
			if case let .presented(.cover(cover)) = event { presented.append(cover) }
		}
		router.present(cover: .player)
		router.replace(cover: .onboarding)
		let task = try #require(router.pendingCoverTask)

		router.coverDidDismiss()
		await task.value

		#expect(router.presentedFullscreenCover?.cover == .onboarding)
		#expect(router.pendingCoverTask == nil)
		#expect(presented == [.player, .onboarding])
	}

	@Test("A cover dismissed through its binding while the host shows it waits for the host")
	func bindingDismissalWaitsForHost() async {
		let router = TestRouter(initialTab: .home)
		router.restore(TestRouter.Snapshot(
			selectedTab: .home,
			presentedFullscreenCover: FullscreenCoverPresentation(cover: .onboarding),
			pendingFullscreenCover: .player,
		))
		router.coverDidAppear()

		router.presentedFullscreenCover = nil
		for _ in 0..<10 { await Task.yield() }

		#expect(router.presentedFullscreenCover == nil)

		router.coverDidDismiss()

		#expect(router.presentedFullscreenCover?.cover == .player)
	}

	@Test("A host dismissal with nothing queued presents nothing")
	func hostDismissalWithoutQueue() {
		let router = TestRouter(initialTab: .home)
		router.present(cover: .player)
		router.coverDidAppear()
		router.dismiss(.cover)

		router.coverDidDismiss()

		#expect(router.presentedFullscreenCover == nil)
		#expect(router.pendingFullscreenCover == nil)
	}
}
