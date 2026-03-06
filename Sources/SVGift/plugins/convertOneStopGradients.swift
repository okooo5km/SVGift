// convertOneStopGradients.swift
// Plugin to convert one-stop gradients to a plain color
// okooo5km(十里)

import Foundation

/// Convert one-stop (single color) gradients to a plain color.
///
/// When a linearGradient or radialGradient has exactly one stop,
/// all references to it (url(#id)) are replaced with the stop color,
/// and the gradient element is removed.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Element/linearGradient
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Element/radialGradient
public func makeConvertOneStopGradientsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertOneStopGradients") { root, _, _ in
        let stylesheet = collectStylesheet(root)

        // Parent defs that had gradient elements removed
        var effectedDefs: Set<ObjectIdentifier> = []

        // All defs elements with their parents
        var allDefs: [(element: XastElement, parent: XastParent)] = []

        // Gradients to detach after processing
        var gradientsToDetach: [(element: XastElement, parent: XastParent)] = []

        // Count of xlink:href references
        var xlinkHrefCount = 0

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    if node.attributes["xlink:href"] != nil {
                        xlinkHrefCount += 1
                    }

                    if node.name == "defs" {
                        allDefs.append((element: node, parent: parentNode))
                        return .continue
                    }

                    guard node.name == "linearGradient" || node.name == "radialGradient" else {
                        return .continue
                    }

                    // Find stops in this gradient
                    let stops = node.children.compactMap { child -> XastElement? in
                        if case .element(let e) = child, e.name == "stop" {
                            return e
                        }
                        return nil
                    }

                    // If no stops, follow href to find effective node
                    let href = node.attributes["xlink:href"] ?? node.attributes["href"]
                    var effectiveNode: XastElement? = nil

                    if stops.isEmpty, let href = href, href.hasPrefix("#") {
                        let id = String(href.dropFirst())
                        effectiveNode = findElementById(root, id: id)
                    } else {
                        effectiveNode = node
                    }

                    guard let effectiveNode = effectiveNode else {
                        // No effective node found, detach orphan gradient
                        gradientsToDetach.append((element: node, parent: parentNode))
                        return .continue
                    }

                    // Get effective stops
                    let effectiveStops = effectiveNode.children.compactMap { child -> XastElement? in
                        if case .element(let e) = child, e.name == "stop" {
                            return e
                        }
                        return nil
                    }

                    guard effectiveStops.count == 1 else { return .continue }

                    let stopElem = effectiveStops[0]

                    // Mark parent defs as affected
                    if case .element(let parentElem) = parentNode, parentElem.name == "defs" {
                        effectedDefs.insert(ObjectIdentifier(parentElem))
                    }

                    gradientsToDetach.append((element: node, parent: parentNode))

                    // Compute stop color
                    let computedStop = computeStyle(stylesheet: stylesheet, node: stopElem)
                    var color: String? = nil
                    if let stopColor = computedStop["stop-color"] {
                        if case .static(let value, _) = stopColor {
                            color = value
                        }
                    }

                    guard let gradientId = node.attributes["id"] else { return .continue }
                    let selectorVal = "url(#\(gradientId))"

                    // Replace url(#id) in color attributes of all elements
                    replaceGradientReferences(
                        root: root,
                        selectorVal: selectorVal,
                        color: color
                    )

                    return .continue
                },
                exit: { node, _ in
                    guard node.name == "svg" else { return }

                    // Detach all marked gradients
                    for entry in gradientsToDetach {
                        if entry.element.attributes["xlink:href"] != nil {
                            xlinkHrefCount -= 1
                        }
                        detachNodeFromParent(.element(entry.element), from: entry.parent)
                    }

                    // Remove xmlns:xlink if no more xlink:href references
                    if xlinkHrefCount == 0 {
                        node.attributes["xmlns:xlink"] = nil
                    }

                    // Remove empty defs
                    for entry in allDefs {
                        if effectedDefs.contains(ObjectIdentifier(entry.element))
                            && entry.element.children.isEmpty
                        {
                            detachNodeFromParent(.element(entry.element), from: entry.parent)
                        }
                    }
                }
            )
        )
    }
}

// MARK: - Helpers

/// Find an element by its `id` attribute in the AST.
private func findElementById(_ root: XastRoot, id: String) -> XastElement? {
    var result: XastElement? = nil
    visit(root, visitor: Visitor(
        element: VisitorCallbacks<XastElement>(
            enter: { node, _ in
                if node.attributes["id"] == id {
                    result = node
                    return .skip
                }
                return .continue
            }
        )
    ))
    return result
}

/// Replace all references to a gradient url(#id) with a solid color
/// in attributes and style attributes throughout the document.
private func replaceGradientReferences(
    root: XastRoot,
    selectorVal: String,
    color: String?
) {
    let defaultStopColor = attrsGroupsDefaults["presentation"]?["stop-color"] ?? "#000"

    visit(root, visitor: Visitor(
        element: VisitorCallbacks<XastElement>(
            enter: { node, _ in
                // Replace in color attributes
                for attr in colorsProps {
                    if node.attributes[attr] == selectorVal {
                        if let color = color {
                            node.attributes[attr] = color
                        } else {
                            node.attributes[attr] = nil
                        }
                    }
                }

                // Replace in style attribute
                if let style = node.attributes["style"], style.contains(selectorVal) {
                    node.attributes["style"] = style.replacingOccurrences(
                        of: selectorVal,
                        with: color ?? defaultStopColor
                    )
                }

                return .continue
            }
        )
    ))
}
