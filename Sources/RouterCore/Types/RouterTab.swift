/// A value that identifies a tab the router manages.
///
/// Conform a `Hashable` enum (or struct) to `RouterTab` to describe every tab in the app.
/// Display details (title, image, role) live in `TabPresentable` in `RouterUI`, so this protocol
/// and everything that depends on it build without SwiftUI.
///
/// ## Example
///
/// ```swift
/// enum AppTab: Hashable, Sendable, RouterTab {
///     case home, profile, search, settings
/// }
/// ```
public protocol RouterTab: Hashable, Sendable { }
