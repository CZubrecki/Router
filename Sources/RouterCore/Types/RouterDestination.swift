/// A value that identifies a screen the router can push onto a navigation stack.
///
/// Conform an enum (or struct) to `RouterDestination` to enumerate every screen the router
/// knows how to display. `Hashable` is required because SwiftUI's `NavigationStack(path:)`
/// stores destinations by hash identity.
///
/// ## Example
///
/// ```swift
/// enum AppDestination: Hashable, Sendable, RouterDestination {
///     case friend(id: Int)
///     case photoAlbum(id: UUID)
///     case settings
/// }
///
/// // Resolve in your root view:
/// NavigationStack(path: router.pathBinding(for: .home)) {
///     HomeRoot()
///         .navigationDestination(for: AppDestination.self) { destination in
///             switch destination {
///             case .friend(let id):     FriendView(id: id)
///             case .photoAlbum(let id): PhotoAlbumView(id: id)
///             case .settings:           SettingsView()
///             }
///         }
/// }
/// ```
public protocol RouterDestination: Hashable, Sendable { }

