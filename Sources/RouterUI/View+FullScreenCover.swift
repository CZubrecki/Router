import RouterCore
import SwiftUI

@available(macOS, unavailable)
public extension View {
	/// Presents the router's full-screen cover and reports its lifecycle back to the router.
	///
	/// Prefer this over binding `.fullScreenCover(item:)` to ``Router/presentedFullscreenCover``
	/// directly. It calls ``Router/coverDidAppear()`` and ``Router/coverDidDismiss()``, so
	/// ``Router/replace(cover:)`` presents the replacement only after the outgoing cover has
	/// finished animating out.
	///
	/// ## Example
	///
	/// ```swift
	/// RootView()
	///     .fullScreenCover(router: router) { cover in
	///         NavigationStack(path: router.fullscreenCoverPathBinding()) {
	///             CoverRoot(cover)
	///         }
	///     }
	/// ```
	///
	/// - Parameters:
	///   - router: The router whose cover should be presented.
	///   - onDismiss: Called after the router has been told the cover was dismissed.
	///   - content: Builds the view for the presented cover.
	func fullScreenCover<Tab, Destination, Sheet, FullscreenCover, Content: View>(
		router: Router<Tab, Destination, Sheet, FullscreenCover>,
		onDismiss: (() -> Void)? = nil,
		@ViewBuilder content: @escaping (FullscreenCover) -> Content,
	) -> some View {
		fullScreenCover(
			item: Binding(
				get: { router.presentedFullscreenCover },
				set: { router.presentedFullscreenCover = $0 },
			),
			onDismiss: {
				router.coverDidDismiss()
				onDismiss?()
			},
			content: { presentation in
				content(presentation.cover)
					.onAppear { router.coverDidAppear() }
			},
		)
	}
}
