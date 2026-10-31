import RouterCore
import SwiftUI

public extension View {
	/// Routes incoming URLs through the given router.
	///
	/// Convenience wrapper around `.onOpenURL { router.handleDeepLink(url: $0) }`. Rejected links
	/// leave the router unchanged and are reported through the router's events.
	///
	/// ## Example
	///
	/// ```swift
	/// RootView()
	///     .onOpenURL(with: router)
	/// ```
	///
	/// - Parameters:
	///   - router: The router that should handle the URL.
	///   - treatHostAsPath: See ``Router/handleDeepLink(url:treatHostAsPath:sheetPrefix:coverPrefix:)``.
	///     Defaults to `true` for custom URL schemes.
	func onOpenURL<Tab, Destination, Sheet, FullscreenCover>(
		with router: Router<Tab, Destination, Sheet, FullscreenCover>,
		treatHostAsPath: Bool = true,
	) -> some View where Tab: URLRoutableTab, Destination: URLRoutableDestination {
		onOpenURL { url in
			router.handleDeepLink(url: url, treatHostAsPath: treatHostAsPath)
		}
	}
}
