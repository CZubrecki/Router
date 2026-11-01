import Foundation
import Testing
@testable import RouterCore

@MainActor
@Suite("Navigation events")
struct EventTests {
	private typealias Event = TestRouter.NavigationEvent

	private final class Recorder {
		var events: [Event] = []
	}

	private func record(_ router: TestRouter) -> Recorder {
		let recorder = Recorder()
		router.onEvent = { recorder.events.append($0) }
		return recorder
	}

	private func collect<S: AsyncSequence>(_ sequence: S) async throws -> [Event] where S.Element == Event {
		var events: [Event] = []
		for try await event in sequence {
			events.append(event)
		}
		return events
	}

	private func url(_ string: String) throws -> URL {
		try #require(URL(string: string))
	}

	// MARK: - One event per method

	@Test("Tab navigation emits one push with the resolved tab")
	func tabNavigation() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.navigate(to: .photos)
		router.navigate(to: .settings, in: .profile)
		router.navigate(to: .photos, .friend(id: 1))
		router.navigate(to: .settings, .photos, in: .settings)

		#expect(recorder.events == [
			.pushed([.photos], in: .tab(.home)),
			.pushed([.settings], in: .tab(.profile)),
			.pushed([.photos, .friend(id: 1)], in: .tab(.home)),
			.pushed([.settings, .photos], in: .tab(.settings)),
		])
	}

	@Test("Pops emit the number of destinations actually removed")
	func pops() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .settings, .friend(id: 1), .photos)
		router.navigate(to: .settings, in: .profile)
		let recorder = record(router)

		router.pop()
		router.popTo(.photos)
		router.pop(10)
		router.popToRoot(in: .profile)

		#expect(recorder.events == [
			.popped(count: 1, in: .tab(.home)),
			.popped(count: 2, in: .tab(.home)),
			.popped(count: 1, in: .tab(.home)),
			.popped(count: 1, in: .tab(.profile)),
		])
	}

	@Test("Popping the selected tab to root reports the tab it resolved to")
	func popToRootCurrentTab() {
		let router = TestRouter(initialTab: .settings)
		router.navigate(to: .photos, .photos)
		let recorder = record(router)

		router.popToRoot()

		#expect(recorder.events == [.popped(count: 2, in: .tab(.settings))])
	}

	@Test("Switching tab emits the old and new tab")
	func switchTab() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.switchTab(to: .profile)
		router.selectedTab = .settings

		#expect(recorder.events == [
			.switchedTab(from: .home, to: .profile),
			.switchedTab(from: .profile, to: .settings),
		])
	}

	@Test("Compound tab switches emit one event per part that changed")
	func compoundSwitchTab() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .settings)
		let recorder = record(router)

		router.switchTab(to: .profile, navigatingTo: .friend(id: 1))
		router.switchTab(to: .settings, resetTo: .settings)
		router.switchTab(to: .settings, resetTo: .settings)

		#expect(recorder.events == [
			.switchedTab(from: .home, to: .profile),
			.pushed([.friend(id: 1)], in: .tab(.profile)),
			.switchedTab(from: .profile, to: .settings),
			.stackReplaced([.settings], in: .tab(.settings)),
		])
	}

	@Test("Popping every tab emits a pop per non-empty tab in a stable order")
	func popAllToRoot() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .settings)
		router.navigate(to: .photos, .settings, in: .home)
		let recorder = record(router)

		router.popAllToRoot()

		#expect(recorder.events == [
			.popped(count: 2, in: .tab(.home)),
			.popped(count: 1, in: .tab(.settings)),
		])
	}

	@Test("Sheet methods emit presentation, stack, and dismissal events")
	func sheetMethods() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.present(sheet: .checkout)
		router.navigateInSheet(to: .photos)
		router.navigateInSheet(to: .settings, .photos)
		router.popInSheet()
		router.popInSheetToRoot()
		router.dismissSheet()

		#expect(recorder.events == [
			.presented(.sheet(.checkout)),
			.pushed([.photos], in: .sheet),
			.pushed([.settings, .photos], in: .sheet),
			.popped(count: 1, in: .sheet),
			.popped(count: 2, in: .sheet),
			.dismissed(.sheet(.checkout)),
		])
	}

	@Test("Cover methods emit presentation, stack, and dismissal events")
	func coverMethods() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.present(fullscreenCover: .player)
		router.navigateInFullscreenCover(to: .photos)
		router.navigateInFullscreenCover(to: .settings, .photos)
		router.popInFullscreenCover(2)
		router.popInFullscreenCoverToRoot()
		router.dismissFullscreenCover()

		#expect(recorder.events == [
			.presented(.cover(.player)),
			.pushed([.photos], in: .cover),
			.pushed([.settings, .photos], in: .cover),
			.popped(count: 2, in: .cover),
			.popped(count: 1, in: .cover),
			.dismissed(.cover(.player)),
		])
	}

	@Test("Replacing a cover reports the outgoing dismissal, then the replacement's presentation")
	func replaceCover() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.replace(fullscreenCover: .player)
		router.replace(fullscreenCover: .onboarding)
		if let next = router.takePendingFullscreenCover() {
			router.present(fullscreenCover: next)
		}

		#expect(recorder.events == [
			.presented(.cover(.player)),
			.dismissed(.cover(.player)),
			.presented(.cover(.onboarding)),
		])
	}

	@Test("Restoring emits a single restored event")
	func restore() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.restore(TestRouter.Snapshot(selectedTab: .profile, paths: [.home: [.photos]]))

		#expect(recorder.events == [.restored])
	}

	@Test("A deep link emits one handled event and no per-field events")
	func deepLinkHandled() throws {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)
		let link = try url("myapp://profile/friend/42")

		router.handleDeepLink(url: link)

		#expect(recorder.events == [.deepLinkHandled(link)])
	}

	@Test("A rejected deep link emits the URL and the error")
	func deepLinkRejected() throws {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)
		let link = try url("myapp://nowhere")

		router.handleDeepLink(url: link)

		#expect(recorder.events == [.deepLinkRejected(link, .unknownTab("nowhere"))])
	}

	// MARK: - No-ops

	@Test("Calls that change nothing emit nothing")
	func noOps() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .profile)
		let recorder = record(router)

		router.pop()
		router.pop(0)
		router.pop(-1)
		router.popToRoot()
		router.popTo(.settings, in: .profile)
		router.popToRoot(in: .profile)
		router.navigate(to: .photos, in: .profile)
		router.popToRoot(in: .profile)
		router.popAllToRoot()
		router.switchTab(to: .home)
		router.selectedTab = .home
		router.navigateInSheet(to: .photos)
		router.popInSheet()
		router.popInSheetToRoot()
		router.dismissSheet()
		router.navigateInFullscreenCover(to: .photos)
		router.popInFullscreenCover()
		router.popInFullscreenCoverToRoot()
		router.dismissFullscreenCover()
		router.present(sheet: .login)
		router.present(sheet: .login)
		router.present(fullscreenCover: .player)
		router.present(fullscreenCover: .player)
		router.restore(router.snapshot)
		router[.settings] = []
		router.currentPath = router.currentPath
		router.presentedSheet = router.presentedSheet

		#expect(recorder.events == [
			.popped(count: 1, in: .tab(.profile)),
			.pushed([.photos], in: .tab(.profile)),
			.popped(count: 1, in: .tab(.profile)),
			.presented(.sheet(.login)),
			.presented(.cover(.player)),
		])
	}

	// MARK: - Property writes

	@Test("Stack writes report a push, pop, or replacement by how the stack changed")
	func stackWrites() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router[.profile] = [.photos]
		router[.profile] = [.photos, .settings, .photos]
		router[.profile] = [.photos]
		router[.profile] = [.settings]
		router.currentPath = [.friend(id: 3)]

		#expect(recorder.events == [
			.pushed([.photos], in: .tab(.profile)),
			.pushed([.settings, .photos], in: .tab(.profile)),
			.popped(count: 2, in: .tab(.profile)),
			.stackReplaced([.settings], in: .tab(.profile)),
			.pushed([.friend(id: 3)], in: .tab(.home)),
		])
	}

	@Test("Sheet property writes report presentation, stack changes, and dismissal")
	func sheetWrites() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.presentedSheet = SheetPresentation(sheet: .login)
		router.presentedSheet?.stack.append(.photos)
		router.presentedSheet?.stack = [.settings]
		router.presentedSheet = SheetPresentation(sheet: .checkout, stack: [.photos])
		router.presentedSheet = nil

		#expect(recorder.events == [
			.presented(.sheet(.login)),
			.pushed([.photos], in: .sheet),
			.stackReplaced([.settings], in: .sheet),
			.presented(.sheet(.checkout)),
			.dismissed(.sheet(.checkout)),
		])
	}

	@Test("Cover property writes report presentation, stack changes, and dismissal")
	func coverWrites() {
		let router = TestRouter(initialTab: .home)
		let recorder = record(router)

		router.presentedFullscreenCover = FullscreenCoverPresentation(cover: .player)
		router.presentedFullscreenCover?.stack = [.photos, .settings]
		router.presentedFullscreenCover?.stack.removeLast()
		router.presentedFullscreenCover = FullscreenCoverPresentation(cover: .onboarding)
		router.presentedFullscreenCover = nil

		#expect(recorder.events == [
			.presented(.cover(.player)),
			.pushed([.photos, .settings], in: .cover),
			.popped(count: 1, in: .cover),
			.presented(.cover(.onboarding)),
			.dismissed(.cover(.onboarding)),
		])
	}

	// MARK: - Delivery

	@Test("Handlers see the state after the change")
	func handlersSeeNewState() {
		let router = TestRouter(initialTab: .home)
		var observed: [TestRouter.Snapshot] = []
		router.onEvent = { _ in observed.append(router.snapshot) }

		router.navigate(to: .photos)
		router.present(sheet: .login)

		#expect(observed == [
			TestRouter.Snapshot(selectedTab: .home, paths: [.home: [.photos]]),
			TestRouter.Snapshot(
				selectedTab: .home,
				paths: [.home: [.photos]],
				presentedSheet: SheetPresentation(sheet: .login),
			),
		])
	}

	@Test("Every stream receives every event in call order")
	func streamsReceiveEvents() async throws {
		let router = TestRouter(initialTab: .home)
		let first = router.events
		let second = router.events

		router.navigate(to: .photos)
		router.switchTab(to: .profile)
		router.present(sheet: .login)

		let expected: [Event] = [
			.pushed([.photos], in: .tab(.home)),
			.switchedTab(from: .home, to: .profile),
			.presented(.sheet(.login)),
		]
		#expect(try await collect(first.prefix(3)) == expected)
		#expect(try await collect(second.prefix(3)) == expected)
	}

	@Test("Streams finish when the router is deallocated")
	func streamsFinishOnDeinit() async throws {
		var router: TestRouter? = TestRouter(initialTab: .home)
		let stream = router!.events
		router?.navigate(to: .photos)

		router = nil

		#expect(try await collect(stream) == [.pushed([.photos], in: .tab(.home))])
	}

	@Test("A cancelled stream stops being a consumer")
	func cancelledStreamDetaches() async {
		let router = TestRouter(initialTab: .home)
		let task = Task { for await _ in router.events {} }
		while !router.hasEventConsumers {
			await Task.yield()
		}

		task.cancel()
		await task.value
		while router.hasEventConsumers {
			await Task.yield()
		}

		#expect(!router.hasEventConsumers)
	}

	@Test("Nothing is built when no consumer is attached")
	func noCostWithoutConsumers() {
		let router = TestRouter(initialTab: .home)
		var built = 0
		func event() -> Event {
			built += 1
			return .restored
		}

		router.emit(event())
		router.navigate(to: .photos)

		#expect(built == 0)
		#expect(!router.hasEventConsumers)

		router.onEvent = { _ in }
		router.emit(event())

		#expect(built == 1)

		router.onEvent = nil
		router.emit(event())

		#expect(built == 1)
	}
}
