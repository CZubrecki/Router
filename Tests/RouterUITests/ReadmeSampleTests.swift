#if os(iOS)
import RouterUI
import SwiftUI
import Testing

// The 0.2 README quick start, changed only by moving tab details to TabPresentable. If this stops
// compiling, apps upgrading from 0.2 need more than the documented one-line migration.
private enum AppTab: Hashable, Sendable, RouterTab {
	case home, profile, settings
}

extension AppTab: TabPresentable {
	var title: LocalizedStringKey? {
		switch self {
		case .home: "Home"
		case .profile: "Profile"
		case .settings: "Settings"
		}
	}

	var image: TabImage? {
		switch self {
		case .home: .systemImage("house")
		case .profile: .systemImage("person.circle")
		case .settings: .systemImage("gear")
		}
	}
}

private enum AppDestination: Hashable, Sendable, RouterDestination {
	case friend(id: Int)
	case settings
}

private enum AppSheet: Hashable, Sendable, RouterSheet {
	case login
}

private enum AppCover: Hashable, Sendable, RouterFullScreenCover {
	case onboarding
}

private typealias AppRouter = Router<AppTab, AppDestination, AppSheet, AppCover>

private struct RootView: View {
	@State private var router = AppRouter(initialTab: .home)

	var body: some View {
		@Bindable var router = router
		TabView(selection: $router.selectedTab) {
			Tab(value: AppTab.home) {
				NavigationStack(path: router.pathBinding(for: .home)) {
					Text("Home")
						.navigationDestination(for: AppDestination.self) { _ in
							Text("Destination")
						}
				}
			} label: {
				Label("Home", systemImage: "house")
			}
		}
		.sheet(item: $router.presentedSheet) { _ in
			Text("Sheet")
		}
		.fullScreenCover(item: $router.presentedFullscreenCover) { _ in
			Text("Cover")
		}
		.environment(router)
	}
}

@MainActor
@Suite("0.2 README sample")
struct ReadmeSampleTests {
	@Test("The 0.2 quick start builds against RouterUI alone")
	func quickStartBuilds() {
		_ = RootView()
	}
}
#endif
