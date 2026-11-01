import RouterUI

enum TestTab: RouterTab {
	case home, profile, settings
}

enum TestDestination: RouterDestination {
	case friend(id: Int)
	case photos
	case settings
}

enum TestSheet: RouterSheet {
	case login
	case checkout
}

enum TestCover: RouterFullScreenCover {
	case onboarding
	case player
}

typealias TestRouter = Router<TestTab, TestDestination, TestSheet, TestCover>
