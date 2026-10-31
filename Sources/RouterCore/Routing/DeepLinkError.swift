/// Why a deep link or route was rejected. A rejected link leaves the router unchanged.
public enum DeepLinkError: Error, Hashable, Sendable {
	/// The first component named no tab.
	case unknownTab(String)
	/// The component after the sheet prefix named no sheet.
	case unknownSheet(String)
	/// The component after the cover prefix named no cover.
	case unknownCover(String)
	/// No destination claimed these trailing components.
	case unconsumedComponents([String])
	/// The URL had no route components, or a modal prefix with nothing after it.
	case malformedURL
}
