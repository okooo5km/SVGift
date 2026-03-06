// removeHiddenElems.swift
// Plugin to remove hidden elements with disabled rendering
// okooo5km(十里)

import Foundation

/// Remove hidden elements:
/// - display="none", visibility="hidden", opacity="0"
/// - circle/ellipse with zero radius
/// - rect with zero width/height
/// - pattern/image with zero width/height
/// - path with empty d, polyline/polygon with empty points
public func makeRemoveHiddenElemsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeHiddenElems") { root, params, _ in
        let isHidden = params["isHidden"] != "false"
        let displayNone = params["displayNone"] != "false"
        let opacity0 = params["opacity0"] != "false"
        let circleR0 = params["circleR0"] != "false"
        let ellipseRX0 = params["ellipseRX0"] != "false"
        let ellipseRY0 = params["ellipseRY0"] != "false"
        let rectWidth0 = params["rectWidth0"] != "false"
        let rectHeight0 = params["rectHeight0"] != "false"
        let patternWidth0 = params["patternWidth0"] != "false"
        let patternHeight0 = params["patternHeight0"] != "false"
        let imageWidth0 = params["imageWidth0"] != "false"
        let imageHeight0 = params["imageHeight0"] != "false"
        let pathEmptyD = params["pathEmptyD"] != "false"
        let polylineEmptyPoints = params["polylineEmptyPoints"] != "false"
        let polygonEmptyPoints = params["polygonEmptyPoints"] != "false"

        let stylesheet = collectStylesheet(root)
        let nonRendering = elemsGroups["nonRendering"] ?? []

        // Phase 1: Pre-scan for opacity=0 and non-rendering elements
        var nonRenderedNodes: [(XastElement, XastParent)] = []
        preVisitForHidden(
            children: root.children, parent: .root(root),
            stylesheet: stylesheet, nonRendering: nonRendering,
            opacity0: opacity0, nonRenderedNodes: &nonRenderedNodes
        )

        // Pre-scan: collect ALL references from the entire tree
        var allReferences: Set<String> = []
        collectAllReferences(children: root.children, allReferences: &allReferences)

        // State for the main visitor
        var removedDefIds: Set<String> = []
        var allDefs: [(XastElement, XastParent)] = []
        var referencesById: [String: [(node: XastElement, parent: XastParent)]] = [:]
        var deoptimized = false

        func removeElement(_ node: XastChild, _ parentNode: XastParent) {
            if case .element(let el) = node,
               el.attributes["id"] != nil,
               case .element(let parent) = parentNode,
               parent.name == "defs" {
                removedDefIds.insert(el.attributes["id"]!)
            }
            detachNodeFromParent(node, from: parentNode)
        }

        let elementCallbacks = VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    // Deoptimize if styles or scripts present
                    if (node.name == "style" && !node.children.isEmpty)
                        || hasScripts(node) {
                        deoptimized = true
                        return .continue
                    }

                    if node.name == "defs" {
                        allDefs.append((node, parentNode))
                    }

                    // Track use references
                    if node.name == "use" {
                        for attr in node.attributes.keys {
                            if attr != "href" && !attr.hasSuffix(":href") { continue }
                            let value = node.attributes[attr]!
                            if value.hasPrefix("#") {
                                let id = String(value.dropFirst())
                                referencesById[id, default: []].append((node: node, parent: parentNode))
                            }
                        }
                    }

                    // circle r="0"
                    if circleR0 && node.name == "circle"
                        && node.children.isEmpty && node.attributes["r"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // ellipse rx="0"
                    if ellipseRX0 && node.name == "ellipse"
                        && node.children.isEmpty && node.attributes["rx"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // ellipse ry="0"
                    if ellipseRY0 && node.name == "ellipse"
                        && node.children.isEmpty && node.attributes["ry"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // rect width="0"
                    if rectWidth0 && node.name == "rect"
                        && node.children.isEmpty && node.attributes["width"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // rect height="0"
                    if rectHeight0 && rectWidth0 && node.name == "rect"
                        && node.children.isEmpty && node.attributes["height"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // pattern width="0"
                    if patternWidth0 && node.name == "pattern"
                        && node.attributes["width"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // pattern height="0"
                    if patternHeight0 && node.name == "pattern"
                        && node.attributes["height"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // image width="0"
                    if imageWidth0 && node.name == "image"
                        && node.attributes["width"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // image height="0"
                    if imageHeight0 && node.name == "image"
                        && node.attributes["height"] == "0" {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // polyline without points
                    if polylineEmptyPoints && node.name == "polyline"
                        && node.attributes["points"] == nil {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    // polygon without points
                    if polygonEmptyPoints && node.name == "polygon"
                        && node.attributes["points"] == nil {
                        removeElement(.element(node), parentNode); return .continue
                    }

                    let computed = computeStyle(stylesheet: stylesheet, node: node)

                    // visibility="hidden"
                    if isHidden {
                        if let vis = computed["visibility"],
                           case .static(let value, _) = vis, value == "hidden" {
                            // keep if any descendant enables visibility
                            if !hasDescendantWithVisibility(node) {
                                removeElement(.element(node), parentNode); return .continue
                            }
                        }
                    }

                    // display="none"
                    if displayNone {
                        if let disp = computed["display"],
                           case .static(let value, _) = disp, value == "none",
                           node.name != "marker" {
                            removeElement(.element(node), parentNode); return .continue
                        }
                    }

                    // path with empty d
                    if pathEmptyD && node.name == "path" {
                        guard let d = node.attributes["d"] else {
                            removeElement(.element(node), parentNode); return .continue
                        }
                        let pathData = parsePathData(d)
                        if pathData.isEmpty {
                            removeElement(.element(node), parentNode); return .continue
                        }
                        if pathData.count == 1
                            && computed["marker-start"] == nil
                            && computed["marker-end"] == nil {
                            removeElement(.element(node), parentNode); return .continue
                        }
                    }

                    // Collect all references
                    for (name, value) in node.attributes {
                        let ids = findReferences(attribute: name, value: value)
                        for id in ids {
                            allReferences.insert(id)
                        }
                    }

                    return .continue
                }
            )

        let rootCallbacks = VisitorCallbacks<XastRoot>(
                exit: { _, _ in
                    // Remove <use> elements referencing removed defs
                    for id in removedDefIds {
                        if let refs = referencesById[id] {
                            for ref in refs {
                                detachNodeFromParent(.element(ref.node), from: ref.parent)
                            }
                        }
                    }

                    // Remove unreferenced non-rendering nodes
                    if !deoptimized {
                        for (node, parent) in nonRenderedNodes {
                            if canRemoveNonRenderingNode(node, allReferences: allReferences) {
                                detachNodeFromParent(.element(node), from: parent)
                            }
                        }
                    }

                    // Remove empty defs
                    for (defsNode, defsParent) in allDefs {
                        if defsNode.children.isEmpty {
                            detachNodeFromParent(.element(defsNode), from: defsParent)
                        }
                    }
                }
            )

        return Visitor(root: rootCallbacks, element: elementCallbacks)
    }
}

// MARK: - Helpers

/// Pre-visit to find non-rendering and opacity=0 elements.
private func preVisitForHidden(
    children: [XastChild],
    parent: XastParent,
    stylesheet: Stylesheet,
    nonRendering: Set<String>,
    opacity0: Bool,
    nonRenderedNodes: inout [(XastElement, XastParent)]
) {
    for child in children {
        guard case .element(let node) = child else { continue }

        if nonRendering.contains(node.name) {
            nonRenderedNodes.append((node, parent))
            continue // skip children
        }

        if opacity0 {
            let computed = computeStyle(stylesheet: stylesheet, node: node)
            if let op = computed["opacity"],
               case .static(let value, _) = op, value == "0" {
                if node.name == "path" {
                    nonRenderedNodes.append((node, parent))
                    continue
                }
                // Remove non-path elements with opacity 0 in place
                detachNodeFromParent(.element(node), from: parent)
                continue
            }
        }

        preVisitForHidden(
            children: node.children, parent: .element(node),
            stylesheet: stylesheet, nonRendering: nonRendering,
            opacity0: opacity0, nonRenderedNodes: &nonRenderedNodes
        )
    }
}

/// Check if a non-rendering node can be safely removed (no referenced IDs).
private func canRemoveNonRenderingNode(_ node: XastElement, allReferences: Set<String>) -> Bool {
    if let id = node.attributes["id"], allReferences.contains(id) {
        return false
    }
    for child in node.children {
        if case .element(let el) = child {
            if !canRemoveNonRenderingNode(el, allReferences: allReferences) {
                return false
            }
        }
    }
    return true
}

/// Check if any descendant has visibility="visible".
private func hasDescendantWithVisibility(_ node: XastElement) -> Bool {
    for child in node.children {
        if case .element(let el) = child {
            if el.attributes["visibility"] == "visible" { return true }
            if hasDescendantWithVisibility(el) { return true }
        }
    }
    return false
}

/// Recursively collect all ID references from the entire tree.
private func collectAllReferences(children: [XastChild], allReferences: inout Set<String>) {
    for child in children {
        guard case .element(let node) = child else { continue }
        for (name, value) in node.attributes {
            let ids = findReferences(attribute: name, value: value)
            for id in ids {
                allReferences.insert(id)
            }
        }
        collectAllReferences(children: node.children, allReferences: &allReferences)
    }
}
