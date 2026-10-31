import Foundation
import Observation

/// A source of truth for tab selection, navigation stacks, and modal presentation.
///
/// `Router` is observable and main-actor-isolated. Create one instance per app and share it
/// through the SwiftUI environment. The class lives in `RouterCore`, which imports only
/// Foundation and Observation, so it also runs headless on macOS (tests, CLIs). The SwiftUI
/// bindings used below come from `RouterUI`.
///
/// ## Usage
///
/// ```swift
/// // 1. Define your routing types.
/// enum AppTab: Hashable, Sendable, RouterTab { case home, profile, settings }
/// enum AppDestination: Hashable, Sendable, RouterDestination { case detail(id: Int) }
/// enum AppSheet: Hashable, Sendable, RouterSheet { case login }
/// enum AppCover: Hashable, Sendable, RouterFullScreenCover { case onboarding }
///
/// // 2. Create one router for the app.
/// @State private var router = Router<AppTab, AppDestination, AppSheet, AppCover>(
///     initialTab: .home
/// )
///
/// // 3. Wire it into the view tree.
/// var body: some View {
///     @Bindable var router = router
///     TabView(selection: $router.selectedTab) {
///         Tab("Home", systemImage: "house", value: AppTab.home) {
///             NavigationStack(path: router.pathBinding(for: .home)) {
///                 HomeRoot()
///                     .navigationDestination(for: AppDestination.self) { destination in
///                         // resolve destination view
///                     }
///             }
///         }
///         // ... other tabs
///     }
///     .sheet(item: $router.presentedSheet) { presentation in
///         // resolve sheet view from presentation.sheet
///     }
///     .fullScreenCover(item: $router.presentedFullscreenCover) { presentation in
///         // resolve cover view from presentation.cover
///     }
/// }
/// ```
@Observable
@MainActor
public final class Router<
	Tab: RouterTab,
	Destination: RouterDestination,
	Sheet: RouterSheet,
	FullscreenCover: RouterFullScreenCover,
> {
	/// The currently selected tab.
	public var selectedTab: Tab

	/// The sheet currently presented over the selected tab — bundled with its navigation stack —
	/// or `nil` when no sheet is presented.
	public var presentedSheet: SheetPresentation<Sheet, Destination>?

	/// The full-screen cover currently presented — bundled with its navigation stack — or `nil`
	/// when no cover is presented.
	public var presentedFullscreenCover: FullscreenCoverPresentation<FullscreenCover, Destination>?

	/// A cover queued by ``replace(fullscreenCover:)``, waiting for the outgoing cover to finish
	/// dismissing, or `nil` when nothing is queued.
	public private(set) var pendingFullscreenCover: FullscreenCover?

	private var paths: [Tab: [Destination]] = [:]

	/// Creates a router with the given initial tab selected.
	/// - Parameter initialTab: The tab to display when the router is first used.
	public init(initialTab: Tab) {
		selectedTab = initialTab
	}

	/// Creates a router in the state captured by a snapshot.
	/// - Parameter snapshot: The state to start from.
	public convenience init(snapshot: Snapshot) {
		self.init(initialTab: snapshot.selectedTab)
		restore(snapshot)
	}

	/// The router's entire navigation state as a value.
	///
	/// Encode it (when the routing types are `Codable`) to persist state, print it from a CLI, or
	/// compare it in tests.
	public var snapshot: Snapshot {
		Snapshot(
			selectedTab: selectedTab,
			paths: paths,
			presentedSheet: presentedSheet,
			presentedFullscreenCover: presentedFullscreenCover,
			pendingFullscreenCover: pendingFullscreenCover,
		)
	}

	/// Replaces the router's entire navigation state with a snapshot's.
	/// - Parameter snapshot: The state to apply.
	public func restore(_ snapshot: Snapshot) {
		selectedTab = snapshot.selectedTab
		paths = snapshot.paths
		presentedSheet = snapshot.presentedSheet
		presentedFullscreenCover = snapshot.presentedFullscreenCover
		pendingFullscreenCover = snapshot.pendingFullscreenCover
	}

	/// Accesses the navigation stack for a tab.
	///
	/// Reads return an empty array when no destinations have been pushed onto the tab yet.
	/// - Parameter tab: The tab whose stack should be read or replaced.
	public subscript(tab: Tab) -> [Destination] {
		get { paths[tab, default: []] }
		set { paths[tab] = newValue }
	}

	/// The navigation stack of the currently selected tab.
	///
	/// Equivalent to `self[selectedTab]`. Reads return an empty array when no destinations have
	/// been pushed onto the selected tab yet.
	public var currentPath: [Destination] {
		get { paths[selectedTab, default: []] }
		set { paths[selectedTab] = newValue }
	}

	/// Pushes a destination onto the currently selected tab's navigation stack.
	/// - Parameter destination: The destination to push.
	public func navigate(to destination: Destination) {
		paths[selectedTab, default: []].append(destination)
	}

	/// Pushes a destination onto a specific tab's navigation stack.
	/// - Parameters:
	///   - destination: The destination to push.
	///   - tab: The tab whose stack should receive the destination.
	public func navigate(to destination: Destination, in tab: Tab) {
		paths[tab, default: []].append(destination)
	}

	/// Pushes a sequence of destinations onto the currently selected tab's navigation stack.
	/// - Parameter destinations: The destinations to push, in order.
	public func navigate(to destinations: Destination...) {
		paths[selectedTab, default: []].append(contentsOf: destinations)
	}

	/// Pushes a sequence of destinations onto a specific tab's navigation stack.
	/// - Parameters:
	///   - destinations: The destinations to push, in order.
	///   - tab: The tab whose stack should receive the destinations.
	public func navigate(to destinations: Destination..., in tab: Tab) {
		paths[tab, default: []].append(contentsOf: destinations)
	}

	/// Switches to a tab and optionally pushes a destination onto that tab's stack.
	///
	/// Useful for deep links and notification taps — "open the Profile tab and push the friend's
	/// detail screen" in one call.
	/// - Parameters:
	///   - tab: The tab to select.
	///   - destination: A destination to push onto the tab's stack after switching, or `nil` to
	///     leave the stack untouched. Defaults to `nil`.
	public func switchTab(to tab: Tab, navigatingTo destination: Destination? = nil) {
		selectedTab = tab
		if let destination {
			paths[tab, default: []].append(destination)
		}
	}

	/// Switches to a tab and replaces that tab's navigation stack with the given destinations.
	/// - Parameters:
	///   - tab: The tab to select.
	///   - destinations: The destinations to install as the tab's new stack, in order.
	public func switchTab(to tab: Tab, resetTo destinations: Destination...) {
		selectedTab = tab
		paths[tab] = destinations
	}

	/// Pushes a destination onto the currently presented sheet's navigation stack.
	///
	/// No-op when no sheet is presented.
	/// - Parameter destination: The destination to push.
	public func navigateInSheet(to destination: Destination) {
		presentedSheet?.stack.append(destination)
	}

	/// Pushes a sequence of destinations onto the currently presented sheet's navigation stack.
	///
	/// No-op when no sheet is presented.
	/// - Parameter destinations: The destinations to push, in order.
	public func navigateInSheet(to destinations: Destination...) {
		presentedSheet?.stack.append(contentsOf: destinations)
	}

	/// Removes the top destinations from the currently presented sheet's navigation stack.
	///
	/// No-op when no sheet is presented. If `count` exceeds the stack depth, the stack is
	/// emptied without trapping.
	/// - Parameter count: The number of destinations to remove. Defaults to `1`.
	public func popInSheet(_ count: Int = 1) {
		let currentCount = presentedSheet?.stack.count ?? 0
		guard currentCount > 0 else { return }
		let removeCount = min(count, currentCount)
		presentedSheet?.stack.removeLast(removeCount)
	}

	/// Clears the navigation stack inside the currently presented sheet without dismissing it.
	///
	/// No-op when no sheet is presented.
	public func popInSheetToRoot() {
		presentedSheet?.stack.removeAll()
	}

	/// Removes the top destinations from the currently selected tab's navigation stack.
	///
	/// If `count` exceeds the stack depth, the stack is emptied without trapping.
	/// - Parameter count: The number of destinations to remove. Defaults to `1`.
	public func pop(_ count: Int = 1) {
		let currentCount = paths[selectedTab, default: []].count
		let removeCount = min(count, currentCount)
		paths[selectedTab]?.removeLast(removeCount)
	}

	/// Clears the navigation stack for a tab.
	/// - Parameter tab: The tab to clear, or `nil` to clear the currently selected tab.
	///   Defaults to `nil`.
	public func popToRoot(in tab: Tab? = nil) {
		paths[tab ?? selectedTab] = []
	}

	/// Pops a tab's navigation stack back to a specific destination, keeping that destination
	/// on top.
	///
	/// No-op if the destination isn't present in the stack. If the destination appears more than
	/// once, the stack is truncated at its first occurrence.
	/// - Parameters:
	///   - destination: The destination to pop back to.
	///   - tab: The tab whose stack should be popped, or `nil` to use the currently selected
	///     tab. Defaults to `nil`.
	public func popTo(_ destination: Destination, in tab: Tab? = nil) {
		let targetTab = tab ?? selectedTab
		guard let index = paths[targetTab, default: []].firstIndex(of: destination) else { return }
		paths[targetTab] = Array(paths[targetTab, default: []].prefix(through: index))
	}

	/// Clears the navigation stacks of every tab.
	///
	/// Use at sign-out or other "reset the whole app" moments.
	public func popAllToRoot() {
		paths.removeAll()
	}

	/// Presents a sheet, replacing any currently presented sheet.
	/// - Parameter sheet: The sheet to present.
	public func present(sheet: Sheet) {
		presentedSheet = SheetPresentation(sheet: sheet)
	}

	/// Dismisses the currently presented sheet and clears its navigation stack.
	public func dismissSheet() {
		presentedSheet = nil
	}

	/// Presents a full-screen cover, replacing any currently presented cover.
	/// - Parameter fullscreenCover: The cover to present.
	public func present(fullscreenCover: FullscreenCover) {
		presentedFullscreenCover = FullscreenCoverPresentation(cover: fullscreenCover)
	}

	/// Swaps the presented full-screen cover for a different one.
	///
	/// SwiftUI cannot dismiss one cover and present another in the same update — the incoming
	/// presentation is dropped. When a cover is already showing, this dismisses it and queues the
	/// replacement in ``pendingFullscreenCover`` instead; the host presents the queued cover once
	/// dismissal completes:
	///
	/// ```swift
	/// .fullScreenCover(item: $router.presentedFullscreenCover) { presentation in
	///     view(for: presentation.cover)
	/// } onDismiss: {
	///     if let next = router.takePendingFullscreenCover() {
	///         // A cover can't be presented from within its predecessor's dismissal.
	///         DispatchQueue.main.async { router.present(fullscreenCover: next) }
	///     }
	/// }
	/// ```
	///
	/// When nothing is presented or queued this presents immediately and queues nothing. Replacing
	/// again before the queue drains supersedes the queued cover rather than presenting into a
	/// window that is still dismissing.
	/// - Parameter fullscreenCover: The cover that should end up presented.
	public func replace(fullscreenCover: FullscreenCover) {
		guard presentedFullscreenCover != nil || pendingFullscreenCover != nil else {
			present(fullscreenCover: fullscreenCover)
			return
		}

		pendingFullscreenCover = fullscreenCover
		presentedFullscreenCover = nil
	}

	/// Consumes the cover queued by ``replace(fullscreenCover:)``.
	///
	/// Call from the host's dismissal handler. Returns `nil` — and does nothing — when no
	/// replacement is queued, so it is safe to call on every dismissal.
	/// - Returns: The queued cover, or `nil` if none was queued.
	public func takePendingFullscreenCover() -> FullscreenCover? {
		defer { pendingFullscreenCover = nil }
		return pendingFullscreenCover
	}

	/// Pushes a destination onto the currently presented full-screen cover's navigation stack.
	///
	/// No-op when no cover is presented.
	/// - Parameter destination: The destination to push.
	public func navigateInFullscreenCover(to destination: Destination) {
		presentedFullscreenCover?.stack.append(destination)
	}

	/// Pushes a sequence of destinations onto the currently presented full-screen cover's
	/// navigation stack.
	///
	/// No-op when no cover is presented.
	/// - Parameter destinations: The destinations to push, in order.
	public func navigateInFullscreenCover(to destinations: Destination...) {
		presentedFullscreenCover?.stack.append(contentsOf: destinations)
	}

	/// Removes the top destinations from the currently presented full-screen cover's
	/// navigation stack.
	///
	/// No-op when no cover is presented. If `count` exceeds the stack depth, the stack is
	/// emptied without trapping.
	/// - Parameter count: The number of destinations to remove. Defaults to `1`.
	public func popInFullscreenCover(_ count: Int = 1) {
		let currentCount = presentedFullscreenCover?.stack.count ?? 0
		guard currentCount > 0 else { return }
		let removeCount = min(count, currentCount)
		presentedFullscreenCover?.stack.removeLast(removeCount)
	}

	/// Clears the navigation stack inside the currently presented full-screen cover without
	/// dismissing it.
	///
	/// No-op when no cover is presented.
	public func popInFullscreenCoverToRoot() {
		presentedFullscreenCover?.stack.removeAll()
	}

	/// Dismisses the currently presented full-screen cover and clears its navigation stack.
	///
	/// Also discards any cover queued by ``replace(fullscreenCover:)`` — an explicit dismissal
	/// means nothing should end up presented. Hosts draining the queue in their dismissal handler
	/// should call ``takePendingFullscreenCover()`` rather than this method.
	public func dismissFullscreenCover() {
		presentedFullscreenCover = nil
		pendingFullscreenCover = nil
	}
}
