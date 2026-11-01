extension Array {
	func sortedIfComparable() -> [Element]? {
		guard let type = Element.self as? any Comparable.Type else { return nil }
		return sorted(as: type)
	}

	private func sorted<Key: Comparable>(as _: Key.Type) -> [Element] {
		sorted { ($0 as! Key) < ($1 as! Key) }
	}
}
