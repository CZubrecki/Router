import SwiftUI
import Testing
import RouterUI

@MainActor
@Suite("Navigation stack bindings")
struct BindingTests {
	// MARK: - Tab path binding

	@Test("The path binding reads and writes the tab's stack")
	func pathBinding() {
		let router = TestRouter(initialTab: .home)
		let binding = router.pathBinding(for: .home)

		#expect(binding.wrappedValue.isEmpty)

		router.navigate(to: .photos)

		#expect(binding.wrappedValue == [.photos])

		binding.wrappedValue = [.settings]

		#expect(router[.home] == [.settings])
	}

	// MARK: - Sheet path binding

	@Test("The sheet path binding reads empty and swallows writes when nothing is presented")
	func sheetPathBindingWithoutPresentation() {
		let router = TestRouter(initialTab: .home)
		let binding = router.sheetPathBinding()

		#expect(binding.wrappedValue.isEmpty)

		binding.wrappedValue = [.photos]

		#expect(router.presentedSheet == nil)
		#expect(binding.wrappedValue.isEmpty)
	}

	@Test("The sheet path binding reads and writes the presented sheet's stack")
	func sheetPathBinding() {
		let router = TestRouter(initialTab: .home)
		let binding = router.sheetPathBinding()
		router.present(sheet: .checkout)

		router.navigate(to: .photos, in: .sheet)

		#expect(binding.wrappedValue == [.photos])

		binding.wrappedValue = [.settings, .friend(id: 4)]

		#expect(router.presentedSheet?.stack == [.settings, .friend(id: 4)])
		#expect(router.presentedSheet?.sheet == .checkout)
	}

	@Test("A sheet path binding built before presentation still tracks the sheet")
	func sheetPathBindingOutlivesPresentation() {
		let router = TestRouter(initialTab: .home)
		let binding = router.sheetPathBinding()

		router.present(sheet: .login)
		binding.wrappedValue = [.photos]

		#expect(router.presentedSheet?.stack == [.photos])

		router.dismiss(.sheet)

		#expect(binding.wrappedValue.isEmpty)
	}

	// MARK: - Cover path binding

	@Test("The cover path binding reads empty and swallows writes when nothing is presented")
	func coverPathBindingWithoutPresentation() {
		let router = TestRouter(initialTab: .home)
		let binding = router.fullscreenCoverPathBinding()

		#expect(binding.wrappedValue.isEmpty)

		binding.wrappedValue = [.photos]

		#expect(router.presentedFullscreenCover == nil)
		#expect(binding.wrappedValue.isEmpty)
	}

	@Test("The cover path binding reads and writes the presented cover's stack")
	func coverPathBinding() {
		let router = TestRouter(initialTab: .home)
		let binding = router.fullscreenCoverPathBinding()
		router.present(cover: .player)

		router.navigate(to: .photos, in: .cover)

		#expect(binding.wrappedValue == [.photos])

		binding.wrappedValue = [.settings, .friend(id: 6)]

		#expect(router.presentedFullscreenCover?.stack == [.settings, .friend(id: 6)])
		#expect(router.presentedFullscreenCover?.cover == .player)
	}
}
