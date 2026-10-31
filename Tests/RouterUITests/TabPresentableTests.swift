#if os(iOS)
import RouterUI
import SwiftUI
import Testing

@Suite("Tab presentation")
struct TabPresentableTests {
	private enum BareTab: TabPresentable {
		case only
	}

	private enum PresentableTab: TabPresentable {
		case home, profile, search

		var title: LocalizedStringKey? {
			switch self {
			case .home: "Home"
			case .profile: "Profile"
			case .search: nil
			}
		}

		var image: TabImage? {
			switch self {
			case .home: .systemImage("house")
			case .profile: .asset("ProfileIcon")
			case .search: nil
			}
		}

		var role: TabRole? {
			self == .search ? .search : nil
		}
	}

	@Test("Unimplemented presentation details default to nil")
	func defaults() {
		#expect(BareTab.only.title == nil)
		#expect(BareTab.only.image == nil)
		#expect(BareTab.only.role == nil)
	}

	@Test("Implemented presentation details are returned per tab")
	func customDetails() {
		#expect(PresentableTab.home.title == "Home")
		#expect(PresentableTab.home.image == .systemImage("house"))
		#expect(PresentableTab.profile.image == .asset("ProfileIcon"))
		#expect(PresentableTab.search.title == nil)
		#expect(PresentableTab.search.role == .search)
		#expect(PresentableTab.home.role == nil)
	}
}
#endif
