// removeEmptyContainers.swift
// Plugin to remove empty container elements
// okooo5km(十里)

import Foundation

/// Remove empty container elements.
///
/// Removes container elements (`<g>`, `<defs>`, `<marker>`, `<mask>`, etc.)
/// that have no children. Also cleans up `<use>` elements that reference
/// containers that were removed.
public func makeRemoveEmptyContainersPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeEmptyContainers") { root, _, _ in
        let containerElems = elemsGroups["container"] ?? []
        let stylesheet = collectStylesheet(root)

        // Track removed element IDs and use elements referencing them
        var removedIds: Set<String> = []
        var usesById: [String: [(element: XastElement, parent: XastParent)]] = [:]

        return Visitor(
            root: VisitorCallbacks<XastRoot>(
                exit: { root, _ in
                    // Remove <use> elements that reference removed containers
                    guard !removedIds.isEmpty else { return }
                    for id in removedIds {
                        if let uses = usesById[id] {
                            for use in uses {
                                detachNodeFromParent(.element(use.element), from: use.parent)
                            }
                        }
                    }
                }
            ),
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // Track <use> element references
                    if node.name == "use" {
                        for attr in ["href", "xlink:href"] {
                            if let href = node.attributes[attr],
                               href.hasPrefix("#"), href.count > 1 {
                                let id = String(href.dropFirst())
                                usesById[id, default: []].append((element: node, parent: parent))
                            }
                        }
                    }
                    return .continue
                },
                exit: { node, parent in
                    // Skip the root <svg> element
                    if node.name == "svg" { return }

                    // Only process container elements
                    guard containerElems.contains(node.name) else { return }

                    // Skip non-empty containers
                    guard node.children.isEmpty else { return }

                    // Skip <pattern> with attributes (may be inheriting from another pattern)
                    if node.name == "pattern" && !node.attributes.isEmpty {
                        return
                    }

                    // Skip <mask> with id (may be referenced)
                    if node.name == "mask" && node.attributes["id"] != nil {
                        return
                    }

                    // Skip if parent is <switch>
                    if case .element(let parentEl) = parent, parentEl.name == "switch" {
                        return
                    }

                    // Skip <g> with filter (filter can produce output without children)
                    if node.name == "g" {
                        let computed = computeStyle(stylesheet: stylesheet, node: node)
                        if let filterVal = computed["filter"] {
                            switch filterVal {
                            case .static(let value, _):
                                if !value.isEmpty && value != "none" { return }
                            case .dynamic:
                                return
                            }
                        }
                    }

                    // Record removed id
                    if let id = node.attributes["id"] {
                        removedIds.insert(id)
                    }

                    detachNodeFromParent(.element(node), from: parent)
                }
            )
        )
    }
}
