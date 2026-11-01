import Testing
@testable import RouterCore

/// Each 0.2 name must do exactly what its replacement does: same resulting state, same events.
@MainActor
@Suite("Deprecated 0.2 names")
struct DeprecatedAPITests {
	private typealias Event = TestRouter.NavigationEvent

	private static let start = TestRouter.Snapshot(
		selectedTab: .home,
		paths: [.home: [.photos, .settings, .friend(id: 1)], .profile: [.photos, .settings]],
		presentedSheet: SheetPresentation(sheet: .checkout, stack: [.photos, .settings]),
		presentedFullscreenCover: FullscreenCoverPresentation(cover: .player, stack: [.settings, .photos]),
	)

	private func run(_ body: (TestRouter) -> Void) -> (TestRouter.Snapshot, [Event]) {
		let router = TestRouter(snapshot: Self.start)
		var events: [Event] = []
		router.onEvent = { events.append($0) }
		body(router)
		return (router.snapshot, events)
	}

	private func expectEquivalent(
		changes: Bool = true,
		_ old: (TestRouter) -> Void,
		_ new: (TestRouter) -> Void,
		sourceLocation: SourceLocation = #_sourceLocation,
	) {
		let (oldState, oldEvents) = run(old)
		let (newState, newEvents) = run(new)
		#expect(oldState == newState, sourceLocation: sourceLocation)
		#expect(oldEvents == newEvents, sourceLocation: sourceLocation)
		#expect((oldState != Self.start) == changes, sourceLocation: sourceLocation)
	}

	@available(*, deprecated)
	@Test("Tab navigation by tab name")
	func tabNavigation() {
		expectEquivalent({ $0.navigate(to: .photos, in: .profile) }, { $0.navigate(to: .photos, in: .tab(.profile)) })
		expectEquivalent(
			{ $0.navigate(to: .photos, .settings, in: .settings) },
			{ $0.navigate(to: .photos, .settings, in: .tab(.settings)) },
		)
	}

	@available(*, deprecated)
	@Test("Switching tab while pushing or resetting")
	func compoundSwitchTab() {
		expectEquivalent(
			{ $0.switchTab(to: .profile, navigatingTo: .friend(id: 9)) },
			{ $0.switchTab(to: .profile); $0.navigate(to: .friend(id: 9), in: .tab(.profile)) },
		)
		expectEquivalent({ $0.switchTab(to: .profile, navigatingTo: nil) }, { $0.switchTab(to: .profile) })
		expectEquivalent(
			{ $0.switchTab(to: .profile, resetTo: .settings, .photos) },
			{ $0.switchTab(to: .profile); $0.replaceStack([.settings, .photos], in: .tab(.profile)) },
		)
	}

	@available(*, deprecated)
	@Test("Popping a named or optional tab")
	func popsByTab() {
		expectEquivalent({ $0.popToRoot(in: .profile) }, { $0.popToRoot(in: .tab(.profile)) })
		expectEquivalent({ $0.popToRoot(in: nil) }, { $0.popToRoot() })
		expectEquivalent({ $0.popTo(.photos, in: .profile) }, { $0.popTo(.photos, in: .tab(.profile)) })
		expectEquivalent({ $0.popTo(.photos, in: nil) }, { $0.popTo(.photos) })
	}

	@available(*, deprecated)
	@Test("Sheet stack and dismissal")
	func sheetNames() {
		expectEquivalent({ $0.navigateInSheet(to: .friend(id: 2)) }, { $0.navigate(to: .friend(id: 2), in: .sheet) })
		expectEquivalent({ $0.navigateInSheet(to: .photos, .photos) }, { $0.navigate(to: .photos, .photos, in: .sheet) })
		expectEquivalent({ $0.popInSheet() }, { $0.pop(in: .sheet) })
		expectEquivalent({ $0.popInSheet(5) }, { $0.pop(5, in: .sheet) })
		expectEquivalent({ $0.popInSheetToRoot() }, { $0.popToRoot(in: .sheet) })
		expectEquivalent({ $0.dismissSheet() }, { $0.dismiss(.sheet) })
	}

	@available(*, deprecated)
	@Test("Cover presentation, stack, and dismissal")
	func coverNames() {
		expectEquivalent({ $0.present(fullscreenCover: .onboarding) }, { $0.present(cover: .onboarding) })
		expectEquivalent({ $0.replace(fullscreenCover: .onboarding) }, { $0.replace(cover: .onboarding) })
		expectEquivalent({ $0.navigateInFullscreenCover(to: .friend(id: 3)) }, { $0.navigate(to: .friend(id: 3), in: .cover) })
		expectEquivalent({ $0.navigateInFullscreenCover(to: .photos, .settings) }, { $0.navigate(to: .photos, .settings, in: .cover) })
		expectEquivalent({ $0.popInFullscreenCover() }, { $0.pop(in: .cover) })
		expectEquivalent({ $0.popInFullscreenCover(2) }, { $0.pop(2, in: .cover) })
		expectEquivalent({ $0.popInFullscreenCoverToRoot() }, { $0.popToRoot(in: .cover) })
		expectEquivalent({ $0.dismissFullscreenCover() }, { $0.dismiss(.cover) })
	}

	@available(*, deprecated)
	@Test("Draining the cover queue is a no-op that returns nil")
	func takePendingIsNoOp() {
		expectEquivalent(changes: false, { _ = $0.takePendingFullscreenCover() }, { _ in })

		let router = TestRouter(snapshot: Self.start)
		router.replace(cover: .onboarding)

		#expect(router.takePendingFullscreenCover() == nil)
		#expect(router.pendingFullscreenCover == .onboarding)
	}
}
