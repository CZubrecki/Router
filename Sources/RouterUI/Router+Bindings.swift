@_exported import RouterCore
import SwiftUI

public extension Router {
	/// Returns a two-way binding to a tab's navigation stack, suitable for `NavigationStack(path:)`.
	/// - Parameter tab: The tab whose stack should be bound.
	/// - Returns: A binding that reads from and writes to the tab's stack.
	func pathBinding(for tab: Tab) -> Binding<[Destination]> {
		Binding(
			get: { self[tab] },
			set: { self[tab] = $0 },
		)
	}

	/// Returns a two-way binding to the presented sheet's navigation stack, suitable for a
	/// `NavigationStack(path:)` inside the sheet.
	///
	/// Reads return an empty array when no sheet is presented, and writes are discarded, so the
	/// binding is safe to build before anything is presented.
	/// - Returns: A binding that reads from and writes to the presented sheet's stack.
	func sheetPathBinding() -> Binding<[Destination]> {
		Binding(
			get: { self.presentedSheet?.stack ?? [] },
			set: { self.presentedSheet?.stack = $0 },
		)
	}

	/// Returns a two-way binding to the presented full-screen cover's navigation stack, suitable
	/// for a `NavigationStack(path:)` inside the cover.
	///
	/// Reads return an empty array when no cover is presented, and writes are discarded, so the
	/// binding is safe to build before anything is presented.
	/// - Returns: A binding that reads from and writes to the presented cover's stack.
	func fullscreenCoverPathBinding() -> Binding<[Destination]> {
		Binding(
			get: { self.presentedFullscreenCover?.stack ?? [] },
			set: { self.presentedFullscreenCover?.stack = $0 },
		)
	}
}
