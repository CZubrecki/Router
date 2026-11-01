import RouterCore

enum TestTab: String, Codable, CaseIterable, RouterTab {
	case home, profile, settings
}

enum TestDestination: Codable, RouterDestination {
	case friend(id: Int)
	case photos
	case settings
}

enum TestSheet: String, Codable, CaseIterable, RouterSheet {
	case login
	case checkout
}

enum TestCover: String, Codable, CaseIterable, RouterFullScreenCover {
	case onboarding
	case player
}

typealias TestRouter = Router<TestTab, TestDestination, TestSheet, TestCover>

enum RankedTab: Codable, Comparable, RouterTab {
	case zulu, alpha, mike
}

typealias RankedRouter = Router<RankedTab, TestDestination, TestSheet, TestCover>

// MARK: - Deep linking

extension TestTab: URLRoutableTab {
	static func tab(from path: String) -> TestTab? {
		switch path {
		case "home": .home
		case "profile": .profile
		case "settings": .settings
		default: nil
		}
	}
}

extension TestDestination: URLRoutableDestination {
	static func destination(
		consuming pathComponents: ArraySlice<String>,
		parameters _: [String: String],
	) -> (destination: TestDestination, consumed: Int)? {
		guard let head = pathComponents.first else { return nil }
		switch head {
		case "friend":
			guard let id = pathComponents.dropFirst().first.flatMap(Int.init) else { return nil }
			return (.friend(id: id), 2)
		case "photos":
			return (.photos, 1)
		case "settings":
			return (.settings, 1)
		default:
			return nil
		}
	}

	var pathComponents: [String] {
		switch self {
		case let .friend(id): ["friend", String(id)]
		case .photos: ["photos"]
		case .settings: ["settings"]
		}
	}
}

extension TestSheet: URLRoutableSheet {
	static func sheet(from path: String) -> TestSheet? {
		switch path {
		case "login": .login
		case "checkout": .checkout
		default: nil
		}
	}
}

extension TestCover: URLRoutableFullScreenCover {
	static func cover(from path: String) -> TestCover? {
		switch path {
		case "onboarding": .onboarding
		case "player": .player
		default: nil
		}
	}
}

extension Result {
	var failure: Failure? {
		if case let .failure(error) = self { error } else { nil }
	}

	var isSuccess: Bool {
		if case .success = self { true } else { false }
	}
}
