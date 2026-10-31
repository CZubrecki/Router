/// A value that identifies a sheet the router can present.
///
/// Conformers must be `Hashable` so the router can key per-sheet navigation state by identity.
///
/// ## Example
///
/// ```swift
/// enum AppSheet: Hashable, Sendable, RouterSheet {
///     case login
///     case composeMessage(recipient: String)
/// }
///
/// // Present:
/// router.present(sheet: .login)
///
/// // Resolve in your view tree:
/// .sheet(item: $router.presentedSheet) { presentation in
///     switch presentation.sheet {
///     case .login:                     LoginView()
///     case .composeMessage(let to):    ComposeView(recipient: to)
///     }
/// }
/// ```
public protocol RouterSheet: Hashable, Sendable { }

/// A presented sheet bundled with its navigation stack.
///
/// The router stores presentation and navigation as a single value to prevent the two from
/// drifting out of sync. Conforms to `Identifiable` so it works directly with SwiftUI's
/// `.sheet(item:)` modifier.
public struct SheetPresentation<
	Sheet: RouterSheet,
	Destination: RouterDestination,
>: Identifiable, Hashable, Sendable {
	/// The identity of the presented sheet.
	public let sheet: Sheet

	/// The destinations pushed within the sheet, in push order.
	public var stack: [Destination]

	/// The identifier used by SwiftUI's `.sheet(item:)` to track presentation identity.
	public var id: Sheet { sheet }

	/// Creates a presentation for a sheet with an optional initial stack.
	/// - Parameters:
	///   - sheet: The sheet to present.
	///   - stack: The destinations already pushed within the sheet. Defaults to empty.
	public init(sheet: Sheet, stack: [Destination] = []) {
		self.sheet = sheet
		self.stack = stack
	}
}

extension SheetPresentation: Codable where Sheet: Codable, Destination: Codable { }
