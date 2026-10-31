import Foundation
import Testing
@testable import RouterCore

@MainActor
@Suite("Snapshots")
struct SnapshotTests {
	private func encode(_ snapshot: TestRouter.Snapshot) throws -> Data {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		return try encoder.encode(snapshot)
	}

	@Test("A new router's snapshot holds only the initial tab")
	func initialSnapshot() {
		let router = TestRouter(initialTab: .profile)

		#expect(router.snapshot == TestRouter.Snapshot(selectedTab: .profile))
	}

	@Test("The snapshot reflects every part of the router's state")
	func snapshotCapturesState() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos, .friend(id: 1))
		router.navigate(to: .settings, in: .tab(.profile))
		router.present(sheet: .checkout)
		router.navigate(to: .photos, in: .sheet)
		router.present(cover: .player)
		router.replace(cover: .onboarding)

		#expect(router.snapshot == TestRouter.Snapshot(
			selectedTab: .home,
			paths: [.home: [.photos, .friend(id: 1)], .profile: [.settings]],
			presentedSheet: SheetPresentation(sheet: .checkout, stack: [.photos]),
			pendingFullscreenCover: .onboarding,
		))
	}

	@Test("A stack popped back to its root compares equal to one never pushed")
	func emptyStacksAreDropped() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)
		router.pop()

		var snapshot = TestRouter.Snapshot(selectedTab: .home, paths: [.profile: []])
		#expect(snapshot.paths.isEmpty)
		snapshot.paths[.settings] = []

		#expect(router.snapshot == snapshot)
		#expect(snapshot.paths.isEmpty)
	}

	@Test("Restoring replaces all five fields")
	func restoreReplacesEverything() {
		let router = TestRouter(initialTab: .home)
		router.navigate(to: .photos)
		router.navigate(to: .friend(id: 2), in: .tab(.settings))
		router.present(sheet: .login)
		router.present(cover: .player)
		router.replace(cover: .onboarding)
		let target = TestRouter.Snapshot(
			selectedTab: .profile,
			paths: [.profile: [.settings]],
			presentedFullscreenCover: FullscreenCoverPresentation(cover: .player, stack: [.photos]),
		)

		router.restore(target)

		#expect(router.selectedTab == .profile)
		#expect(router[.home].isEmpty)
		#expect(router[.settings].isEmpty)
		#expect(router[.profile] == [.settings])
		#expect(router.presentedSheet == nil)
		#expect(router.presentedFullscreenCover?.cover == .player)
		#expect(router.presentedFullscreenCover?.stack == [.photos])
		#expect(router.pendingFullscreenCover == nil)
		#expect(router.snapshot == target)
	}

	@Test("Router(snapshot:).snapshot round-trips every generated state")
	func routerRoundTrip() {
		for snapshot in StateGenerator.snapshots() {
			#expect(TestRouter(snapshot: snapshot).snapshot == snapshot)
		}
	}

	@Test("A pending cover survives the router round trip")
	func pendingCoverRoundTrip() {
		let snapshot = TestRouter.Snapshot(selectedTab: .home, pendingFullscreenCover: .player)

		#expect(TestRouter(snapshot: snapshot).snapshot == snapshot)
	}

	@Test("JSON decoding round-trips every generated state")
	func jsonRoundTrip() throws {
		for snapshot in StateGenerator.snapshots() {
			let decoded = try JSONDecoder().decode(TestRouter.Snapshot.self, from: encode(snapshot))
			#expect(decoded == snapshot)
		}
	}

	@Test("JSON encoding is byte-stable regardless of how the state was built")
	func jsonIsStable() throws {
		let forward = TestRouter(initialTab: .home)
		forward.navigate(to: .photos, in: .tab(.home))
		forward.navigate(to: .settings, in: .tab(.profile))
		forward.navigate(to: .friend(id: 3), in: .tab(.settings))

		let backward = TestRouter(initialTab: .home)
		backward.navigate(to: .friend(id: 3), in: .tab(.settings))
		backward.navigate(to: .settings, in: .tab(.profile))
		backward.navigate(to: .photos, in: .tab(.home))

		#expect(try encode(forward.snapshot) == encode(backward.snapshot))
		for snapshot in StateGenerator.snapshots(count: 50) {
			#expect(try encode(snapshot) == encode(TestRouter(snapshot: snapshot).snapshot))
		}
	}

	@Test("Encoded JSON has a readable, fixture-friendly shape")
	func jsonShape() throws {
		let snapshot = TestRouter.Snapshot(
			selectedTab: .profile,
			paths: [.profile: [.photos], .home: [.settings]],
			presentedSheet: SheetPresentation(sheet: .login),
		)

		let json = try #require(String(data: encode(snapshot), encoding: .utf8))

		#expect(json == #"{"paths":[{"stack":[{"settings":{}}],"tab":"home"},{"stack":[{"photos":{}}],"tab":"profile"}],"presentedSheet":{"sheet":"login","stack":[]},"selectedTab":"profile"}"#)
	}

	@Test("Decoding rejects two stacks for the same tab")
	func duplicateTabRejected() {
		let json = Data(#"{"selectedTab":"home","paths":[{"tab":"home","stack":[]},{"tab":"home","stack":[]}]}"#.utf8)

		#expect(throws: DecodingError.self) {
			try JSONDecoder().decode(TestRouter.Snapshot.self, from: json)
		}
	}

	@Test("Decoding tolerates a snapshot with no paths key")
	func missingPathsDecodes() throws {
		let json = Data(#"{"selectedTab":"settings"}"#.utf8)

		let snapshot = try JSONDecoder().decode(TestRouter.Snapshot.self, from: json)

		#expect(snapshot == TestRouter.Snapshot(selectedTab: .settings))
	}

	@Test("Codable conformance is absent when the routing types are not Codable")
	func codableIsConditional() {
		enum PlainTab: RouterTab { case only }
		enum PlainDestination: RouterDestination { case only }
		typealias PlainRouter = Router<PlainTab, PlainDestination, TestSheet, TestCover>
		let snapshot = PlainRouter(initialTab: .only).snapshot

		#expect(!((snapshot as Any) is any Encodable))
		#expect(!((snapshot as Any) is any Decodable))
		#expect((TestRouter(initialTab: .home).snapshot as Any) is any Codable)
		#expect((SheetPresentation<TestSheet, TestDestination>(sheet: .login) as Any) is any Codable)
		#expect(!((SheetPresentation<TestSheet, PlainDestination>(sheet: .login) as Any) is any Codable))
	}
}
