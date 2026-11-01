extension Router {
	/// The router's entire navigation state as a plain value.
	///
	/// Read one from ``Router/snapshot``, rebuild a router with ``Router/init(snapshot:)``, or
	/// apply one to a live router with ``Router/restore(_:)``. `Snapshot` is `Codable` when all
	/// four routing types are, so apps opt into persistence by conforming their enums:
	///
	/// ```swift
	/// enum AppTab: String, Codable, RouterTab { case home, profile }
	/// ```
	///
	/// Empty stacks are dropped from ``paths``, so a tab that was pushed onto and popped back to
	/// its root compares equal to one that was never touched. Encoded stacks are listed in tab
	/// order when `Tab` is `Comparable`, and otherwise sorted by each tab's description.
	public struct Snapshot: Hashable, Sendable {
		/// The selected tab.
		public var selectedTab: Tab

		/// The non-empty navigation stack of each tab.
		public var paths: [Tab: [Destination]] {
			didSet { paths = paths.filter { !$0.value.isEmpty } }
		}

		/// The presented sheet and its stack, or `nil` when no sheet is presented.
		public var presentedSheet: SheetPresentation<Sheet, Destination>?

		/// The presented full-screen cover and its stack, or `nil` when no cover is presented.
		public var presentedFullscreenCover: FullscreenCoverPresentation<FullscreenCover, Destination>?

		/// A cover waiting to replace the one being dismissed, or `nil` when nothing is queued.
		public var pendingFullscreenCover: FullscreenCover?

		/// Creates a snapshot from its parts.
		/// - Parameters:
		///   - selectedTab: The selected tab.
		///   - paths: Each tab's navigation stack. Empty stacks are dropped. Defaults to empty.
		///   - presentedSheet: The presented sheet. Defaults to `nil`.
		///   - presentedFullscreenCover: The presented full-screen cover. Defaults to `nil`.
		///   - pendingFullscreenCover: A queued replacement cover. Defaults to `nil`.
		public init(
			selectedTab: Tab,
			paths: [Tab: [Destination]] = [:],
			presentedSheet: SheetPresentation<Sheet, Destination>? = nil,
			presentedFullscreenCover: FullscreenCoverPresentation<FullscreenCover, Destination>? = nil,
			pendingFullscreenCover: FullscreenCover? = nil,
		) {
			self.selectedTab = selectedTab
			self.paths = paths.filter { !$0.value.isEmpty }
			self.presentedSheet = presentedSheet
			self.presentedFullscreenCover = presentedFullscreenCover
			self.pendingFullscreenCover = pendingFullscreenCover
		}

		var orderedTabs: [Tab] {
			let tabs = Array(paths.keys)
			return tabs.sortedIfComparable() ?? tabs.sorted { String(describing: $0) < String(describing: $1) }
		}
	}
}

extension Router.Snapshot: Codable
where Tab: Codable, Destination: Codable, Sheet: Codable, FullscreenCover: Codable {
	private enum CodingKeys: String, CodingKey {
		case selectedTab
		case paths
		case presentedSheet
		case presentedFullscreenCover
		case pendingFullscreenCover
	}

	private enum PathCodingKeys: String, CodingKey {
		case tab
		case stack
	}

	// A dictionary keyed by a non-string type encodes as an unordered array, so paths are
	// written as entries in a fixed tab order to keep encoded fixtures byte-stable across runs.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(selectedTab, forKey: .selectedTab)
		try container.encodeIfPresent(presentedSheet, forKey: .presentedSheet)
		try container.encodeIfPresent(presentedFullscreenCover, forKey: .presentedFullscreenCover)
		try container.encodeIfPresent(pendingFullscreenCover, forKey: .pendingFullscreenCover)

		var pathsContainer = container.nestedUnkeyedContainer(forKey: .paths)
		for tab in orderedTabs {
			var entry = pathsContainer.nestedContainer(keyedBy: PathCodingKeys.self)
			try entry.encode(tab, forKey: .tab)
			try entry.encode(paths[tab, default: []], forKey: .stack)
		}
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		var paths: [Tab: [Destination]] = [:]
		if container.contains(.paths) {
			var pathsContainer = try container.nestedUnkeyedContainer(forKey: .paths)
			while !pathsContainer.isAtEnd {
				let entry = try pathsContainer.nestedContainer(keyedBy: PathCodingKeys.self)
				let tab = try entry.decode(Tab.self, forKey: .tab)
				guard paths[tab] == nil else {
					throw DecodingError.dataCorruptedError(
						forKey: .tab,
						in: entry,
						debugDescription: "Duplicate stack for tab \(tab).",
					)
				}
				paths[tab] = try entry.decode([Destination].self, forKey: .stack)
			}
		}

		self.init(
			selectedTab: try container.decode(Tab.self, forKey: .selectedTab),
			paths: paths,
			presentedSheet: try container.decodeIfPresent(
				SheetPresentation<Sheet, Destination>.self,
				forKey: .presentedSheet,
			),
			presentedFullscreenCover: try container.decodeIfPresent(
				FullscreenCoverPresentation<FullscreenCover, Destination>.self,
				forKey: .presentedFullscreenCover,
			),
			pendingFullscreenCover: try container.decodeIfPresent(
				FullscreenCover.self,
				forKey: .pendingFullscreenCover,
			),
		)
	}
}
