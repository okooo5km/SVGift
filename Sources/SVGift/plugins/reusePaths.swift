// reusePaths.swift
// Plugin to find identical paths and reuse them via <use> + <defs>
// okooo5km(十里)

import Foundation

/// Finds `<path>` elements with the same d, fill, and stroke, and converts them
/// to `<use>` elements referencing a single `<path>` def.
public func makeReusePathsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "reusePaths") { root, _, _ in
        let stylesheet = collectStylesheet(root)

        // Group paths by (d + stroke + fill) key, maintaining insertion order
        var orderedKeys: [String] = []
        var pathGroups: [String: [XastElement]] = [:]
        var svgDefs: XastElement? = nil
        var hrefs: Set<String> = []

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    // Collect path elements
                    if node.name == "path", let d = node.attributes["d"] {
                        let fill = node.attributes["fill"] ?? ""
                        let stroke = node.attributes["stroke"] ?? ""
                        let key = d + ";s:" + stroke + ";f:" + fill
                        if pathGroups[key] == nil {
                            orderedKeys.append(key)
                        }
                        pathGroups[key, default: []].append(node)
                    }

                    // Find first <defs> that is a direct child of <svg>
                    if svgDefs == nil && node.name == "defs" {
                        if case .element(let parent) = parentNode, parent.name == "svg" {
                            svgDefs = node
                        }
                    }

                    // Collect use hrefs
                    if node.name == "use" {
                        for name in ["href", "xlink:href"] {
                            if let href = node.attributes[name],
                               href.hasPrefix("#"), href.count > 1 {
                                hrefs.insert(String(href.dropFirst()))
                            }
                        }
                    }

                    return .continue
                },
                exit: { node, parentNode in
                    guard node.name == "svg" else { return }
                    if case .root = parentNode {} else { return }

                    let defsTag = svgDefs ?? XastElement(name: "defs")
                    var index = 0

                    for key in orderedKeys {
                        guard let list = pathGroups[key], list.count > 1 else { continue }

                        // Create reusable path definition
                        let reusablePath = XastElement(name: "path")
                        for attr in ["fill", "stroke", "d"] {
                            if let val = list[0].attributes[attr] {
                                reusablePath.attributes[attr] = val
                            }
                        }

                        // Determine ID for the reusable path
                        let originalId = list[0].attributes["id"]
                        if originalId == nil
                            || hrefs.contains(originalId!)
                            || stylesheet.rules.contains(where: { $0.selectorText == "#\(originalId!)" }) {
                            reusablePath.attributes["id"] = "reuse-\(index)"
                            index += 1
                        } else {
                            reusablePath.attributes["id"] = originalId
                            list[0].attributes.removeValue(forKey: "id")
                        }

                        defsTag.children.append(.element(reusablePath))

                        // Convert paths to <use>
                        for pathNode in list {
                            pathNode.attributes.removeValue(forKey: "d")
                            pathNode.attributes.removeValue(forKey: "stroke")
                            pathNode.attributes.removeValue(forKey: "fill")

                            // Check if this path is in defs and can be cleaned up
                            let isInDefs = defsTag.children.contains { child in
                                if case .element(let el) = child { return el === pathNode }
                                return false
                            }

                            if isInDefs && pathNode.children.isEmpty {
                                if pathNode.attributes.isEmpty {
                                    detachNodeFromParent(.element(pathNode), from: .element(defsTag))
                                    continue
                                }
                                if pathNode.attributes.count == 1 && pathNode.attributes["id"] != nil {
                                    let oldId = pathNode.attributes["id"]!
                                    detachNodeFromParent(.element(pathNode), from: .element(defsTag))
                                    // Update references
                                    let newHref = "#\(reusablePath.attributes["id"]!)"
                                    updateHrefs(in: node, oldId: oldId, newHref: newHref)
                                    continue
                                }
                            }

                            pathNode.name = "use"
                            pathNode.attributes["xlink:href"] = "#\(reusablePath.attributes["id"]!)"
                        }
                    }

                    if !defsTag.children.isEmpty {
                        if node.attributes["xmlns:xlink"] == nil {
                            node.attributes["xmlns:xlink"] = "http://www.w3.org/1999/xlink"
                        }
                        if svgDefs == nil {
                            node.children.insert(.element(defsTag), at: 0)
                        }
                    }
                }
            )
        )
    }
}

/// Update href/xlink:href references from oldId to newHref in all descendants.
private func updateHrefs(in element: XastElement, oldId: String, newHref: String) {
    for child in element.children {
        if case .element(let el) = child {
            for name in ["href", "xlink:href"] {
                if let val = el.attributes[name], val == "#\(oldId)" {
                    el.attributes[name] = newHref
                }
            }
            updateHrefs(in: el, oldId: oldId, newHref: newHref)
        }
    }
}
