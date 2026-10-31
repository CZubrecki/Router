public extension Router {
	@available(*, deprecated, message: "Use navigate(to:in: .tab(tab))")
	func navigate(to destinations: Destination..., in tab: Tab) {
		push(destinations, in: .tab(tab))
	}

	@available(*, deprecated, message: "Use switchTab(to:) followed by navigate(to:in: .tab(tab))")
	func switchTab(to tab: Tab, navigatingTo destination: Destination?) {
		switchTab(to: tab)
		if let destination {
			navigate(to: destination, in: .tab(tab))
		}
	}

	@available(*, deprecated, message: "Use switchTab(to:) followed by replaceStack(_:in: .tab(tab))")
	func switchTab(to tab: Tab, resetTo destinations: Destination...) {
		switchTab(to: tab)
		replaceStack(destinations, in: .tab(tab))
	}

	@available(*, deprecated, message: "Use popToRoot(in: .tab(tab)), or popToRoot() for the selected tab")
	func popToRoot(in tab: Tab?) {
		popToRoot(in: tab.map(Context.tab) ?? .currentTab)
	}

	@available(*, deprecated, message: "Use popTo(_:in: .tab(tab)), or popTo(_:) for the selected tab")
	func popTo(_ destination: Destination, in tab: Tab?) {
		popTo(destination, in: tab.map(Context.tab) ?? .currentTab)
	}

	@available(*, deprecated, message: "Use navigate(to:in: .sheet)")
	func navigateInSheet(to destinations: Destination...) {
		push(destinations, in: .sheet)
	}

	@available(*, deprecated, message: "Use pop(_:in: .sheet)")
	func popInSheet(_ count: Int = 1) {
		pop(count, in: .sheet)
	}

	@available(*, deprecated, message: "Use popToRoot(in: .sheet)")
	func popInSheetToRoot() {
		popToRoot(in: .sheet)
	}

	@available(*, deprecated, message: "Use dismiss(.sheet)")
	func dismissSheet() {
		dismiss(.sheet)
	}

	@available(*, deprecated, renamed: "present(cover:)")
	func present(fullscreenCover: FullscreenCover) {
		present(cover: fullscreenCover)
	}

	@available(*, deprecated, renamed: "replace(cover:)")
	func replace(fullscreenCover: FullscreenCover) {
		replace(cover: fullscreenCover)
	}

	@available(*, deprecated, message: "The router now presents the queued cover itself. Remove the onDismiss handler.")
	func takePendingFullscreenCover() -> FullscreenCover? {
		nil
	}

	@available(*, deprecated, message: "Use navigate(to:in: .cover)")
	func navigateInFullscreenCover(to destinations: Destination...) {
		push(destinations, in: .cover)
	}

	@available(*, deprecated, message: "Use pop(_:in: .cover)")
	func popInFullscreenCover(_ count: Int = 1) {
		pop(count, in: .cover)
	}

	@available(*, deprecated, message: "Use popToRoot(in: .cover)")
	func popInFullscreenCoverToRoot() {
		popToRoot(in: .cover)
	}

	@available(*, deprecated, message: "Use dismiss(.cover)")
	func dismissFullscreenCover() {
		dismiss(.cover)
	}
}
