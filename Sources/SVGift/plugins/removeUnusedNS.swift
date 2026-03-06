// removeUnusedNS.swift
// Plugin to remove unused namespace declarations
// okooo5km(十里)

/// Remove unused namespace declarations from the `<svg>` element.
///
/// Collects all `xmlns:*` declarations on the root `<svg>` element,
/// then walks the tree to check if each namespace prefix is actually
/// used in element names or attribute names. Unused declarations are
/// removed on exit.
public func makeRemoveUnusedNSPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeUnusedNS") { _, _, _ in
        var unusedNamespaces: Set<String> = []

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // Collect namespace declarations from root svg element
                    if node.name == "svg" {
                        if case .root = parent {
                            for key in node.attributes.keys {
                                if key.hasPrefix("xmlns:") {
                                    let local = String(key.dropFirst("xmlns:".count))
                                    unusedNamespaces.insert(local)
                                }
                            }
                        }
                    }

                    guard !unusedNamespaces.isEmpty else { return .continue }

                    // Check element name for namespace usage
                    if node.name.contains(":") {
                        let ns = String(node.name.split(separator: ":").first ?? "")
                        unusedNamespaces.remove(ns)
                    }

                    // Check attribute names for namespace usage
                    for key in node.attributes.keys {
                        if key.contains(":") {
                            let ns = String(key.split(separator: ":").first ?? "")
                            unusedNamespaces.remove(ns)
                        }
                    }

                    return .continue
                },
                exit: { node, parent in
                    // Remove unused namespace attributes from svg element on exit
                    if node.name == "svg" {
                        if case .root = parent {
                            for ns in unusedNamespaces {
                                node.attributes.removeValue(forKey: "xmlns:\(ns)")
                            }
                        }
                    }
                }
            )
        )
    }
}
