/// A value that identifies a full-screen cover the router can present.
///
/// Conformers must be `Hashable` so the router can key per-cover navigation state by identity.
///
/// ## Example
///
/// ```swift
/// enum AppCover: Hashable, Sendable, RouterFullScreenCover {
///     case onboarding
///     case videoPlayer(id: UUID)
/// }
///
/// // Present:
/// router.present(fullscreenCover: .onboarding)
///
/// // Resolve in your view tree:
/// .fullScreenCover(item: $router.presentedFullscreenCover) { presentation in
///     switch presentation.cover {
///     case .onboarding:               OnboardingFlow()
///     case .videoPlayer(let id):      VideoPlayer(id: id)
///     }
/// }
/// ```
public protocol RouterFullScreenCover: Hashable, Sendable { }

/// A presented full-screen cover bundled with its navigation stack.
///
/// The router stores presentation and navigation as a single value to prevent the two from
/// drifting out of sync. Conforms to `Identifiable` so it works directly with SwiftUI's
/// `.fullScreenCover(item:)` modifier.
public struct FullscreenCoverPresentation<
	FullscreenCover: RouterFullScreenCover,
	Destination: RouterDestination,
>: Identifiable, Hashable, Sendable {
	/// The identity of the presented cover.
	public let cover: FullscreenCover

	/// The destinations pushed within the cover, in push order.
	public var stack: [Destination]

	/// The identifier used by SwiftUI's `.fullScreenCover(item:)` to track presentation identity.
	public var id: FullscreenCover { cover }

	/// Creates a presentation for a cover with an optional initial stack.
	/// - Parameters:
	///   - cover: The cover to present.
	///   - stack: The destinations already pushed within the cover. Defaults to empty.
	public init(cover: FullscreenCover, stack: [Destination] = []) {
		self.cover = cover
		self.stack = stack
	}
}

extension FullscreenCoverPresentation: Codable
where FullscreenCover: Codable, Destination: Codable { }
