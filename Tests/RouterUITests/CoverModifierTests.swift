#if os(iOS)
import RouterUI
import SwiftUI
import Testing

private struct CoverHost: View {
	@State private var router = TestRouter(initialTab: .home)

	var body: some View {
		Color.clear
			.fullScreenCover(router: router, onDismiss: {}) { cover in
				NavigationStack(path: router.fullscreenCoverPathBinding()) {
					Text(String(describing: cover))
				}
			}
	}
}

@MainActor
@Suite("Full-screen cover modifier")
struct CoverModifierTests {
	@Test("The cover modifier builds against RouterUI alone")
	func modifierBuilds() {
		_ = CoverHost()
	}
}
#endif
