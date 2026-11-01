import RouterUI
import SwiftUI

enum DemoTab: String, RouterTab { case home }
enum DemoDestination: RouterDestination { case step }
enum DemoSheet: String, RouterSheet { case unused }
enum DemoCover: String, RouterFullScreenCover {
	case red, green

	var other: DemoCover { self == .red ? .green : .red }
	var color: Color { self == .red ? .red : .green }
}

typealias DemoRouter = Router<DemoTab, DemoDestination, DemoSheet, DemoCover>

enum HostMode: String, CaseIterable, Identifiable {
	case modifier = "fullScreenCover(router:)"
	case binding = "Plain item binding"

	var id: Self { self }
}

@MainActor
@Observable
final class SwapLog {
	var lines: [String] = []
	var onScreen: DemoCover?

	func add(_ line: String) {
		let time = Date.now.formatted(.dateTime.minute().second().secondFraction(.fractional(3)))
		let entry = "\(time) \(line)"
		print("[CoverSwap] \(entry)")
		lines.insert(entry, at: 0)
		lines = Array(lines.prefix(40))
	}
}

extension DemoRouter.NavigationEvent {
	var summary: String {
		switch self {
		case let .switchedTab(from, to): "switched tab \(from) -> \(to)"
		case let .pushed(destinations, context): "pushed \(destinations) in \(context.summary)"
		case let .popped(count, context): "popped \(count) in \(context.summary)"
		case let .stackReplaced(destinations, context): "replaced stack with \(destinations) in \(context.summary)"
		case let .presented(presentation): "presented \(presentation.summary)"
		case let .dismissed(presentation): "dismissed \(presentation.summary)"
		case let .deepLinkHandled(url): "handled \(url)"
		case let .deepLinkRejected(url, error): "rejected \(url): \(error)"
		case .restored: "restored"
		}
	}
}

extension DemoRouter.Context {
	var summary: String {
		switch self {
		case let .tab(tab): "tab \(tab)"
		case .currentTab: "current tab"
		case .sheet: "sheet"
		case .cover: "cover"
		}
	}
}

extension DemoRouter.Presentation {
	var summary: String {
		switch self {
		case let .sheet(sheet): "sheet \(sheet)"
		case let .cover(cover): "cover \(cover)"
		}
	}
}

@main
struct CoverSwapDemoApp: App {
	@State private var router = DemoRouter(initialTab: .home)
	@State private var log = SwapLog()

	var body: some Scene {
		WindowGroup {
			HomeView()
				.environment(router)
				.environment(log)
				.onAppear {
					router.onEvent = { [log] event in log.add("router \(event.summary)") }
				}
		}
	}
}

struct HomeView: View {
	@Environment(DemoRouter.self) private var router
	@Environment(SwapLog.self) private var log
	@State private var mode = HostMode.modifier

	var body: some View {
		NavigationStack {
			List {
				Section("Host") {
					Picker("Cover host", selection: $mode) {
						ForEach(HostMode.allCases) { Text($0.rawValue).tag($0) }
					}
					.pickerStyle(.inline)
					.labelsHidden()
					.onChange(of: mode, initial: true) { log.add("mode \(mode.rawValue)") }
				}

				Section("Swap") {
					Button("Present red") {
						log.add("tap present red")
						router.present(cover: .red)
					}
					Button("Present red, swap to green after 0.1s") {
						log.add("tap present red, swap after 0.1s")
						router.present(cover: .red)
						Task {
							try? await Task.sleep(for: .milliseconds(100))
							router.replace(cover: .green)
						}
					}
					Button("Present red, swap to green after 1s") {
						log.add("tap present red, swap after 1s")
						router.present(cover: .red)
						Task {
							try? await Task.sleep(for: .seconds(1))
							router.replace(cover: .green)
						}
					}
				}

				if let stuck = router.presentedFullscreenCover?.cover, log.onScreen == nil {
					Section {
						Label(
							"Router says \(stuck.rawValue) is presented, but you are looking at home: the cover was dropped.",
							systemImage: "exclamationmark.triangle.fill",
						)
						.foregroundStyle(.red)
					}
				}

				Section("Log") {
					ForEach(Array(log.lines.enumerated()), id: \.offset) { _, line in
						Text(line).font(.caption.monospaced())
					}
				}
			}
			.navigationTitle("Cover swap")
		}
		.modifier(CoverHost(mode: mode))
	}
}

struct CoverHost: ViewModifier {
	let mode: HostMode
	@Environment(DemoRouter.self) private var router
	@Environment(SwapLog.self) private var log

	func body(content: Content) -> some View {
		switch mode {
		case .modifier:
			content.fullScreenCover(router: router, onDismiss: { dismissed() }) { cover in
				CoverView(cover: cover)
			}
		case .binding:
			@Bindable var router = router
			content.fullScreenCover(item: $router.presentedFullscreenCover, onDismiss: { dismissed() }) {
				CoverView(cover: $0.cover)
			}
		}
	}

	private func dismissed() {
		log.onScreen = nil
		log.add("host onDismiss")
	}
}

struct CoverView: View {
	let cover: DemoCover
	@Environment(DemoRouter.self) private var router
	@Environment(SwapLog.self) private var log

	var body: some View {
		VStack(spacing: 24) {
			Text(cover.rawValue.uppercased())
				.font(.system(size: 72, weight: .black))
			Button("Swap to \(cover.other.rawValue)") {
				log.add("tap swap to \(cover.other.rawValue)")
				router.replace(cover: cover.other)
			}
				.buttonStyle(.borderedProminent)
				.tint(.black)
			Button("Dismiss") {
				log.add("tap dismiss")
				router.dismiss(.cover)
			}
				.buttonStyle(.bordered)
				.tint(.black)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(cover.color.gradient)
		.onAppear {
			log.onScreen = cover
			log.add("on screen: \(cover.rawValue)")
		}
	}
}
