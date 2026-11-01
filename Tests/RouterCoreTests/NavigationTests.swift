import Testing
@testable import RouterCore

@MainActor
@Suite("Tab and stack navigation")
struct NavigationTests {
	@Test("A new router selects its initial tab with every stack empty")
	func startsEmpty() {
		let router = TestRouter(initialTab: .home)

		#expect(router.selectedTab == .home)
		#expect(router.currentPath.isEmpty)
		#expect(router[.profile].isEmpty)
	}

	@Test("Navigating pushes onto the selected tab")
	func navigatePushesOntoSelectedTab() {
		let router = TestRouter(initialTab: .home)

		router.navigate(to: .photos)
		router.navigate(to: .friend(id: 42))

		#expect(router.currentPath == [.photos, .friend(id: 42)])
		#expect(router[.profile].isEmpty)
	}

	@Test("Navigating into another tab leaves the selection alone")
	func navigateIntoOtherTab() {
		let router = TestRouter(initialTab: .home)

		router.navigate(to: .photos, in: .tab(.profile))

		#expect(router.selectedTab == .home)
		#expect(router.currentPath.isEmpty)
		#expect(router[.profile] == [.photos])
	}

	@Test("Variadic navigation pushes in order")
	func variadicNavigate() {
		let router = TestRouter(initialTab: .home)

		router.navigate(to: .photos, .settings, .friend(id: 7))

		#expect(router.currentPath == [.photos, .settings, .friend(id: 7)])
	}

	@Test("Tab stacks survive switching away and back")
	func stacksArePerTab() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)

		router.switchTab(to: .profile)
		router.navigate(to: .settings)
		router.switchTab(to: .home)

		#expect(router.currentPath == [.photos])
		#expect(router[.profile] == [.settings])
	}

	@Test("The default context follows the selected tab after a switch")
	func currentTabFollowsSwitch() {
		let router = TestRouter(initialTab: .home)

		router.switchTab(to: .profile)
		router.navigate(to: .friend(id: 1))

		#expect(router.selectedTab == .profile)
		#expect(router[.profile] == [.friend(id: 1)])
		#expect(router[.home].isEmpty)
	}

	@Test("Replacing a stack installs it rather than appending")
	func replaceStack() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, in: .tab(.profile))

		router.replaceStack([.settings, .friend(id: 3)], in: .tab(.profile))

		#expect(router[.profile] == [.settings, .friend(id: 3)])

		router.replaceStack([.photos])

		#expect(router.currentPath == [.photos])

		router.replaceStack([])

		#expect(router.currentPath.isEmpty)
	}

	@Test("Stack verbs reach into a presented sheet or cover and ignore absent ones")
	func modalContexts() {
		let router = TestRouter(initialTab: .home)
		router.replaceStack([.photos], in: .sheet)
		router.popTo(.photos, in: .cover)

		#expect(router.snapshot == TestRouter.Snapshot(selectedTab: .home))

		router.present(sheet: .checkout)
		router.replaceStack([.photos, .settings, .friend(id: 1)], in: .sheet)
		router.popTo(.settings, in: .sheet)

		#expect(router.presentedSheet?.stack == [.photos, .settings])
		#expect(router.currentPath.isEmpty)
	}

	@Test("Popping removes from the top")
	func pop() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .settings, .friend(id: 9))

		router.pop()

		#expect(router.currentPath == [.photos, .settings])

		router.pop(2)

		#expect(router.currentPath.isEmpty)
	}

	@Test("Popping past the root empties the stack without trapping")
	func popBeyondDepth() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)

		router.pop(10)

		#expect(router.currentPath.isEmpty)
	}

	@Test("Popping an empty stack is a no-op")
	func popEmptyStack() {
		let router = TestRouter(initialTab: .home)

		router.pop()

		#expect(router.currentPath.isEmpty)
	}

	@Test("Popping to a destination keeps that destination on top")
	func popTo() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .settings, .friend(id: 5))

		router.popTo(.settings)

		#expect(router.currentPath == [.photos, .settings])
	}

	@Test("Popping to a destination that isn't in the stack changes nothing")
	func popToMissingDestination() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .settings)

		router.popTo(.friend(id: 404))

		#expect(router.currentPath == [.photos, .settings])
	}

	@Test("Popping to a repeated destination truncates at its first occurrence")
	func popToRepeatedDestination() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .settings, .photos, .friend(id: 1))

		router.popTo(.photos)

		#expect(router.currentPath == [.photos])
	}

	@Test("Popping to root clears the selected tab, or a named one")
	func popToRoot() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .settings)
		router.navigate(to: .friend(id: 2), in: .tab(.profile))

		router.popToRoot()

		#expect(router.currentPath.isEmpty)
		#expect(router[.profile] == [.friend(id: 2)])

		router.popToRoot(in: .tab(.profile))

		#expect(router[.profile].isEmpty)
	}

	@Test("Popping everything to root clears every tab but keeps the selection")
	func popAllToRoot() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)
		router.navigate(to: .settings, in: .tab(.profile))
		router.switchTab(to: .profile)

		router.popAllToRoot()

		#expect(router[.home].isEmpty)
		#expect(router[.profile].isEmpty)
		#expect(router.selectedTab == .profile)
	}

	@Test("A tab's stack can be replaced through the subscript")
	func subscriptWrites() {
		let router = TestRouter(initialTab: .home)

		router[.profile] = [.photos, .settings]

		#expect(router[.profile] == [.photos, .settings])
	}

}
