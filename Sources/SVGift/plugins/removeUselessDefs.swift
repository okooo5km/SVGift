// removeUselessDefs.swift
// Plugin to remove useless <defs> and non-rendering elements without id
// okooo5km(十里)

import Foundation

/// Remove useless `<defs>` elements and non-rendering elements without `id`.
///
/// A `<defs>` is considered useless if it contains no elements with an `id`
/// attribute and no `<style>` elements. Non-rendering elements (clipPath,
/// filter, linearGradient, etc.) without an `id` are also removed since
/// they cannot be referenced.
public func makeRemoveUselessDefsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeUselessDefs") { _, _, _ in
        let nonRendering = elemsGroups["nonRendering"] ?? []

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    let isDefs = node.name == "defs"
                    let isNonRenderingWithoutId = nonRendering.contains(node.name)
                        && node.attributes["id"] == nil

                    guard isDefs || isNonRenderingWithoutId else {
                        return .continue
                    }

                    // Collect useful children recursively
                    let useful = collectUsefulNodes(from: node.children)

                    if useful.isEmpty {
                        detachNodeFromParent(.element(node), from: parent)
                    } else {
                        node.children = useful
                    }

                    return .continue
                }
            )
        )
    }
}

/// Recursively collect children that have an `id` attribute or are `<style>` elements.
/// For other container-like children, recurse into their children.
private func collectUsefulNodes(from children: [XastChild]) -> [XastChild] {
    var result: [XastChild] = []

    for child in children {
        guard case .element(let el) = child else { continue }

        if el.attributes["id"] != nil || el.name == "style" {
            result.append(child)
        } else {
            // Recurse into this element's children
            let nested = collectUsefulNodes(from: el.children)
            result.append(contentsOf: nested)
        }
    }

    return result
}
