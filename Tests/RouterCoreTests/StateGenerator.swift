import RouterCore

/// A deterministic SplitMix64 generator, so property-style tests replay the same states on
/// every run and a failure always reproduces.
struct SeededGenerator: RandomNumberGenerator {
	private var state: UInt64

	init(seed: UInt64) {
		state = seed
	}

	mutating func next() -> UInt64 {
		state &+= 0x9E37_79B9_7F4A_7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
		z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
		return z ^ (z >> 31)
	}
}

enum StateGenerator {
	static let iterations = 300

	/// Random snapshots: a random selected tab, each tab's stack 0 to 4 deep, and a random sheet,
	/// cover, both, or neither, each with a 0 to 4 deep stack.
	static func snapshots(count: Int = iterations, seed: UInt64 = 0x5EED) -> [TestRouter.Snapshot] {
		var generator = SeededGenerator(seed: seed)
		return (0..<count).map { _ in snapshot(using: &generator) }
	}

	static func snapshot(using generator: inout SeededGenerator) -> TestRouter.Snapshot {
		var paths: [TestTab: [TestDestination]] = [:]
		for tab in TestTab.allCases {
			paths[tab] = stack(using: &generator)
		}

		let sheet = Bool.random(using: &generator)
			? TestSheet.allCases.randomElement(using: &generator).map {
				SheetPresentation(sheet: $0, stack: stack(using: &generator))
			}
			: nil

		let cover = Bool.random(using: &generator)
			? TestCover.allCases.randomElement(using: &generator).map {
				FullscreenCoverPresentation(cover: $0, stack: stack(using: &generator))
			}
			: nil

		return TestRouter.Snapshot(
			selectedTab: TestTab.allCases.randomElement(using: &generator)!,
			paths: paths,
			presentedSheet: sheet,
			presentedFullscreenCover: cover,
		)
	}

	static func stack(using generator: inout SeededGenerator) -> [TestDestination] {
		(0..<Int.random(in: 0...4, using: &generator)).map { _ in
			switch Int.random(in: 0..<3, using: &generator) {
			case 0: .friend(id: Int.random(in: 0...999, using: &generator))
			case 1: .photos
			default: .settings
			}
		}
	}
}
