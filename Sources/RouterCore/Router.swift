import Foundation
import Observation

/// A source of truth for tab selection, navigation stacks, and modal presentation.
///
/// `Router` is observable and main-actor-isolated. Create one instance per app and share it
/// through the SwiftUI environment. The class lives in `RouterCore`, which imports only
/// Foundation and Observation, so it also runs headless on macOS (tests, CLIs). The SwiftUI
/// bindings used below come from `RouterUI`.
///
/// Every change to the router's state is reported as a ``NavigationEvent`` through ``events``
/// and ``onEvent``, including writes that come from SwiftUI bindings.
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
	/// Where a navigation stack lives: a specific tab, whichever tab is selected, or the presented
	/// sheet or cover.
	public enum Context: Hashable, Sendable {
		/// The stack of a specific tab.
		case tab(Tab)
		/// The stack of the selected tab. Events always report the resolved ``tab(_:)`` instead.
		case currentTab
		/// The stack inside the presented sheet.
		case sheet
		/// The stack inside the presented full-screen cover.
		case cover
	}

	/// A modal the router can present.
	public enum Presentation: Hashable, Sendable {
		/// A sheet.
		case sheet(Sheet)
		/// A full-screen cover.
		case cover(FullscreenCover)
	}

	/// A change to the router's state, delivered after the change is applied.
	///
	/// Contexts in events are always concrete: ``Context/currentTab`` is reported as the
	/// ``Context/tab(_:)`` it resolved to.
	public enum NavigationEvent: Hashable, Sendable {
		/// The selected tab changed.
		case switchedTab(from: Tab, to: Tab)
		/// Destinations were pushed onto a stack, in push order.
		case pushed([Destination], in: Context)
		/// Destinations were popped off the top of a stack.
		case popped(count: Int, in: Context)
		/// A stack was replaced with new contents.
		case stackReplaced([Destination], in: Context)
		/// A sheet or cover was presented, replacing any presented modal of the same kind.
		case presented(Presentation)
		/// A sheet or cover was dismissed.
		case dismissed(Presentation)
		/// A deep link was applied. Read ``Router/snapshot`` for the resulting state.
		case deepLinkHandled(URL)
		/// A deep link was rejected and the router left unchanged.
		case deepLinkRejected(URL, DeepLinkError)
		/// The whole state was replaced by ``Router/restore(_:)``.
		case restored
	}

	/// The currently selected tab.
	///
	/// Setting it is equivalent to ``switchTab(to:)``.
	public var selectedTab: Tab {
		get { tabSelection }
		set { select(newValue) }
	}

	/// The sheet currently presented over the selected tab, bundled with its navigation stack,
	/// or `nil` when no sheet is presented.
	///
	/// Writes, including those from SwiftUI bindings, emit the matching event: presenting,
	/// dismissing, or a push, pop, or replacement within the sheet's stack.
	public var presentedSheet: SheetPresentation<Sheet, Destination>? {
		get { sheetState }
		set { assignSheet(newValue) }
	}

	/// The full-screen cover currently presented, bundled with its navigation stack, or `nil`
	/// when no cover is presented.
	///
	/// Writes, including those from SwiftUI bindings, emit the matching event: presenting,
	/// dismissing, or a push, pop, or replacement within the cover's stack.
	public var presentedFullscreenCover: FullscreenCoverPresentation<FullscreenCover, Destination>? {
		get { coverState }
		set { assignCover(newValue) }
	}

	/// A cover queued by ``replace(cover:)``, which the router presents on the next main-actor
	/// turn, or `nil` when nothing is queued.
	public private(set) var pendingFullscreenCover: FullscreenCover?

	/// The URL scheme and reserved prefixes used to render and parse routes.
	public var routeFormat = RouteFormat()

	/// Called synchronously on the main actor with every event, after the state change it
	/// describes. Intended for a debug socket or analytics bridge.
	@ObservationIgnored
	public var onEvent: ((NavigationEvent) -> Void)?

	private var tabSelection: Tab
	private var paths: [Tab: [Destination]] = [:]
	private var sheetState: SheetPresentation<Sheet, Destination>?
	private var coverState: FullscreenCoverPresentation<FullscreenCover, Destination>?

	@ObservationIgnored
	private var continuations: [UUID: AsyncStream<NavigationEvent>.Continuation] = [:]

	/// Creates a router with the given initial tab selected.
	/// - Parameter initialTab: The tab to display when the router is first used.
	public init(initialTab: Tab) {
		tabSelection = initialTab
	}

	/// Creates a router in the state captured by a snapshot.
	/// - Parameter snapshot: The state to start from.
	public convenience init(snapshot: Snapshot) {
		self.init(initialTab: snapshot.selectedTab)
		restore(snapshot)
	}

	deinit {
		for continuation in continuations.values {
			continuation.finish()
		}
	}

	// MARK: - Snapshots

	/// The router's entire navigation state as a value.
	///
	/// Encode it (when the routing types are `Codable`) to persist state, print it from a CLI, or
	/// compare it in tests.
	public var snapshot: Snapshot {
		Snapshot(
			selectedTab: tabSelection,
			paths: paths,
			presentedSheet: sheetState,
			presentedFullscreenCover: coverState,
			pendingFullscreenCover: pendingFullscreenCover,
		)
	}

	/// Replaces the router's entire navigation state with a snapshot's.
	///
	/// Emits ``NavigationEvent/restored`` unless the router is already in that state.
	/// - Parameter snapshot: The state to apply.
	public func restore(_ snapshot: Snapshot) {
		guard snapshot != self.snapshot else { return }
		tabSelection = snapshot.selectedTab
		paths = snapshot.paths
		sheetState = snapshot.presentedSheet
		coverState = snapshot.presentedFullscreenCover
		pendingFullscreenCover = snapshot.pendingFullscreenCover
		emit(.restored)
		schedulePendingCover()
	}

	// MARK: - Events

	/// A stream of every event from the moment it is created.
	///
	/// Each access returns a new, independent stream. The stream finishes when the router is
	/// deallocated. Nothing is buffered or built while no stream or ``onEvent`` handler exists.
	public var events: AsyncStream<NavigationEvent> {
		let (stream, continuation) = AsyncStream.makeStream(of: NavigationEvent.self)
		let id = UUID()
		continuations[id] = continuation
		continuation.onTermination = { [weak self] _ in
			Task { @MainActor in
				self?.continuations[id] = nil
			}
		}
		return stream
	}

	var hasEventConsumers: Bool {
		onEvent != nil || !continuations.isEmpty
	}

	func emit(_ event: @autoclosure () -> NavigationEvent) {
		guard hasEventConsumers else { return }
		let event = event()
		for continuation in continuations.values {
			continuation.yield(event)
		}
		onEvent?(event)
	}

	// MARK: - Path access

	/// Accesses the navigation stack for a tab.
	///
	/// Reads return an empty array when no destinations have been pushed onto the tab yet. Writes
	/// emit a push, pop, or replacement event depending on how the stack changed.
	/// - Parameter tab: The tab whose stack should be read or replaced.
	public subscript(tab: Tab) -> [Destination] {
		get { stack(in: .tab(tab)) }
		set { assignStack(newValue, in: .tab(tab)) }
	}

	/// The navigation stack of the currently selected tab.
	///
	/// Equivalent to `self[selectedTab]`. Reads return an empty array when no destinations have
	/// been pushed onto the selected tab yet.
	public var currentPath: [Destination] {
		get { stack(in: .currentTab) }
		set { assignStack(newValue, in: .currentTab) }
	}

	// MARK: - Stacks

	/// Pushes destinations onto a navigation stack.
	///
	/// No-op when the context is ``Context/sheet`` or ``Context/cover`` and nothing of that kind
	/// is presented.
	/// - Parameters:
	///   - destinations: The destinations to push, in order.
	///   - context: The stack to push onto. Defaults to the selected tab.
	public func navigate(to destinations: Destination..., in context: Context = .currentTab) {
		push(destinations, in: context)
	}

	/// Removes the top destinations from a navigation stack.
	///
	/// If `count` exceeds the stack depth, the stack is emptied without trapping.
	/// - Parameters:
	///   - count: The number of destinations to remove. Defaults to `1`.
	///   - context: The stack to pop. Defaults to the selected tab.
	public func pop(_ count: Int = 1, in context: Context = .currentTab) {
		popStack(count, in: context)
	}

	/// Clears a navigation stack. A presented sheet or cover stays presented.
	/// - Parameter context: The stack to clear. Defaults to the selected tab.
	public func popToRoot(in context: Context = .currentTab) {
		popStack(stack(in: context).count, in: context)
	}

	/// Pops a navigation stack back to a destination, keeping that destination on top.
	///
	/// No-op if the destination isn't in the stack. If it appears more than once, the stack is
	/// truncated at its first occurrence.
	/// - Parameters:
	///   - destination: The destination to pop back to.
	///   - context: The stack to pop. Defaults to the selected tab.
	public func popTo(_ destination: Destination, in context: Context = .currentTab) {
		let current = stack(in: context)
		guard let index = current.firstIndex(of: destination) else { return }
		popStack(current.count - index - 1, in: context)
	}

	/// Replaces a navigation stack's contents.
	/// - Parameters:
	///   - destinations: The new stack, bottom first.
	///   - context: The stack to replace. Defaults to the selected tab.
	public func replaceStack(_ destinations: [Destination], in context: Context = .currentTab) {
		guard let context = resolve(context), stack(in: context) != destinations else { return }
		writeStack(destinations, in: context)
		emit(.stackReplaced(destinations, in: context))
	}

	/// Clears the navigation stacks of every tab.
	///
	/// Use at sign-out or other "reset the whole app" moments. Emits one pop event per tab that
	/// had a non-empty stack.
	public func popAllToRoot() {
		let tabs = paths.keys.sorted { String(describing: $0) < String(describing: $1) }
		for tab in tabs {
			popToRoot(in: .tab(tab))
		}
	}

	// MARK: - Tabs

	/// Selects a tab. Each tab keeps its own stack.
	/// - Parameter tab: The tab to select.
	public func switchTab(to tab: Tab) {
		select(tab)
	}

	// MARK: - Modals

	/// The kind of modal ``dismiss(_:)`` closes.
	public enum Modal: Hashable, Sendable {
		/// The presented sheet.
		case sheet
		/// The presented full-screen cover.
		case cover
	}

	/// Presents a sheet with an empty stack, replacing any presented sheet.
	/// - Parameter sheet: The sheet to present.
	public func present(sheet: Sheet) {
		let presentation = SheetPresentation<Sheet, Destination>(sheet: sheet)
		guard sheetState != presentation else { return }
		sheetState = presentation
		emit(.presented(.sheet(sheet)))
	}

	/// Presents a full-screen cover with an empty stack, replacing any presented cover and
	/// cancelling a replacement queued by ``replace(cover:)``.
	/// - Parameter cover: The cover to present.
	public func present(cover: FullscreenCover) {
		cancelPendingCover()
		let presentation = FullscreenCoverPresentation<FullscreenCover, Destination>(cover: cover)
		guard coverState != presentation else { return }
		coverState = presentation
		emit(.presented(.cover(cover)))
	}

	/// Swaps the presented full-screen cover for a different one.
	///
	/// SwiftUI drops a cover presented in the same update that dismisses another. When a cover is
	/// showing, this dismisses it and queues the replacement in ``pendingFullscreenCover``; the
	/// router presents the queued cover itself on the next main-actor turn, so the host needs no
	/// `onDismiss` handler. With nothing presented this presents immediately. Replacing again
	/// before the queue drains supersedes the queued cover.
	///
	/// Emits the outgoing cover's dismissal now and the replacement's presentation when it
	/// happens.
	/// - Parameter cover: The cover that should end up presented.
	public func replace(cover: FullscreenCover) {
		guard coverState != nil || pendingFullscreenCover != nil else {
			present(cover: cover)
			return
		}

		pendingFullscreenCover = cover
		if let outgoing = coverState?.cover {
			coverState = nil
			emit(.dismissed(.cover(outgoing)))
		}
		schedulePendingCover()
	}

	/// Dismisses the presented sheet or full-screen cover, discarding its stack.
	///
	/// Dismissing the cover also cancels a replacement queued by ``replace(cover:)``.
	/// - Parameter modal: Which modal to dismiss.
	public func dismiss(_ modal: Modal) {
		switch modal {
		case .sheet:
			guard let sheet = sheetState?.sheet else { return }
			sheetState = nil
			emit(.dismissed(.sheet(sheet)))
		case .cover:
			cancelPendingCover()
			guard let cover = coverState?.cover else { return }
			coverState = nil
			emit(.dismissed(.cover(cover)))
		}
	}

	// MARK: - Cover replacement

	@ObservationIgnored
	private(set) var pendingCoverTask: Task<Void, Never>?

	private func schedulePendingCover() {
		guard coverState == nil, pendingFullscreenCover != nil, pendingCoverTask == nil else { return }
		pendingCoverTask = Task { [weak self] in
			self?.presentPendingCover()
		}
	}

	private func presentPendingCover() {
		pendingCoverTask = nil
		guard !Task.isCancelled, coverState == nil, let next = pendingFullscreenCover else { return }
		pendingFullscreenCover = nil
		coverState = FullscreenCoverPresentation(cover: next)
		emit(.presented(.cover(next)))
	}

	private func cancelPendingCover() {
		pendingFullscreenCover = nil
		pendingCoverTask?.cancel()
		pendingCoverTask = nil
	}

	// MARK: - Deep links

	func apply(_ target: DeepLinkTarget, from url: URL) {
		switch target {
		case let .tab(tab, stack):
			tabSelection = tab
			writeStack(stack, in: .tab(tab))
		case let .sheet(sheet, stack):
			sheetState = SheetPresentation(sheet: sheet, stack: stack)
		case let .cover(cover, stack):
			cancelPendingCover()
			coverState = FullscreenCoverPresentation(cover: cover, stack: stack)
		}
		emit(.deepLinkHandled(url))
	}

	// MARK: - Stack primitives

	private func resolve(_ context: Context) -> Context? {
		switch context {
		case .tab: context
		case .currentTab: .tab(tabSelection)
		case .sheet: sheetState == nil ? nil : .sheet
		case .cover: coverState == nil ? nil : .cover
		}
	}

	private func stack(in context: Context) -> [Destination] {
		switch context {
		case let .tab(tab): paths[tab, default: []]
		case .currentTab: paths[tabSelection, default: []]
		case .sheet: sheetState?.stack ?? []
		case .cover: coverState?.stack ?? []
		}
	}

	private func writeStack(_ stack: [Destination], in context: Context) {
		switch context {
		case let .tab(tab): paths[tab] = stack.isEmpty ? nil : stack
		case .currentTab: paths[tabSelection] = stack.isEmpty ? nil : stack
		case .sheet: sheetState?.stack = stack
		case .cover: coverState?.stack = stack
		}
	}

	private func select(_ tab: Tab) {
		guard tab != tabSelection else { return }
		let previous = tabSelection
		tabSelection = tab
		emit(.switchedTab(from: previous, to: tab))
	}

	func push(_ destinations: [Destination], in context: Context) {
		guard !destinations.isEmpty, let context = resolve(context) else { return }
		writeStack(stack(in: context) + destinations, in: context)
		emit(.pushed(destinations, in: context))
	}

	private func popStack(_ count: Int, in context: Context) {
		guard let context = resolve(context) else { return }
		let current = stack(in: context)
		let removed = min(max(count, 0), current.count)
		guard removed > 0 else { return }
		writeStack(Array(current.dropLast(removed)), in: context)
		emit(.popped(count: removed, in: context))
	}

	// MARK: - Property writes

	private func assignStack(_ new: [Destination], in context: Context) {
		guard let context = resolve(context) else { return }
		let old = stack(in: context)
		guard old != new else { return }
		writeStack(new, in: context)
		emit(Self.stackChange(from: old, to: new, in: context))
	}

	private func assignSheet(_ new: SheetPresentation<Sheet, Destination>?) {
		let old = sheetState
		guard old != new else { return }
		sheetState = new
		switch (old, new) {
		case let (old?, new?) where old.sheet == new.sheet:
			emit(Self.stackChange(from: old.stack, to: new.stack, in: .sheet))
		case let (_, new?):
			emit(.presented(.sheet(new.sheet)))
		case let (old?, nil):
			emit(.dismissed(.sheet(old.sheet)))
		case (nil, nil):
			break
		}
	}

	private func assignCover(_ new: FullscreenCoverPresentation<FullscreenCover, Destination>?) {
		let old = coverState
		guard old != new else { return }
		coverState = new
		switch (old, new) {
		case let (old?, new?) where old.cover == new.cover:
			emit(Self.stackChange(from: old.stack, to: new.stack, in: .cover))
		case let (_, new?):
			cancelPendingCover()
			emit(.presented(.cover(new.cover)))
		case let (old?, nil):
			emit(.dismissed(.cover(old.cover)))
			schedulePendingCover()
		case (nil, nil):
			break
		}
	}

	private static func stackChange(
		from old: [Destination],
		to new: [Destination],
		in context: Context,
	) -> NavigationEvent {
		if new.starts(with: old) {
			return .pushed(Array(new.dropFirst(old.count)), in: context)
		}
		if old.starts(with: new) {
			return .popped(count: old.count - new.count, in: context)
		}
		return .stackReplaced(new, in: context)
	}
}
