// sortDefsChildren.swift
// Plugin to sort children of <defs> for better compression
// okooo5km(十里)

/// Sort children of `<defs>` elements to improve compression.
///
/// Children are sorted by:
/// 1. Frequency (most frequent element names first)
/// 2. Element name length (longer names first)
/// 3. Element name alphabetically (reversed, to group similar names)
///
/// Non-element children (text, comments, etc.) maintain their relative
/// position among themselves.
public func makeSortDefsChildrenPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "sortDefsChildren") { _, _, _ in
        Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard node.name == "defs" else { return .continue }

                    // Count element name frequencies
                    var frequencies: [String: Int] = [:]
                    for child in node.children {
                        if case .element(let el) = child {
                            frequencies[el.name, default: 0] += 1
                        }
                    }

                    // Extract only element children for sorting
                    var elements = node.children.compactMap { child -> XastChild? in
                        if case .element = child { return child }
                        return nil
                    }

                    elements.sort { a, b in
                        guard case .element(let aEl) = a,
                              case .element(let bEl) = b else {
                            return false
                        }

                        let aFreq = frequencies[aEl.name] ?? 0
                        let bFreq = frequencies[bEl.name] ?? 0

                        // Sort by frequency (descending)
                        if aFreq != bFreq {
                            return aFreq > bFreq
                        }

                        // Sort by name length (descending)
                        if aEl.name.count != bEl.name.count {
                            return aEl.name.count > bEl.name.count
                        }

                        // Sort by name (reversed alphabetical to group similar names)
                        if aEl.name != bEl.name {
                            return aEl.name > bEl.name
                        }

                        return false
                    }

                    // Rebuild children: keep non-element nodes (whitespace, comments)
                    // interspersed with sorted elements
                    var newChildren: [XastChild] = []
                    var elementIdx = 0

                    for child in node.children {
                        if case .element = child {
                            if elementIdx < elements.count {
                                newChildren.append(elements[elementIdx])
                                elementIdx += 1
                            }
                        } else {
                            newChildren.append(child)
                        }
                    }
                    // Append any remaining sorted elements
                    while elementIdx < elements.count {
                        newChildren.append(elements[elementIdx])
                        elementIdx += 1
                    }

                    node.children = newChildren

                    return .continue
                }
            )
        )
    }
}
