// moveElemsAttrsToGroup.swift
// Plugin to move common child element attributes to the parent group
// okooo5km(十里)

import Foundation

/// Move common attributes of group children to the group.
///
/// When all element children of a `<g>` share the same inheritable
/// attribute value, that attribute is promoted to the group and removed
/// from the children. Special rules:
/// - `transform` is not moved if the group has `filter`, `clip-path`, or `mask`
/// - `transform` is not moved if all children are path elements
///   (so convertPathData can still apply transforms to path data)
/// - The plugin is disabled when `<style>` elements are present
///   (selectors may rely on specific attributes)
public func makeMoveElemsAttrsToGroupPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "moveElemsAttrsToGroup") { root, _, _ in
        // Pre-scan: check for <style> elements
        var deoptimizedWithStyles = false
        visit(root, visitor: Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if node.name == "style" {
                        deoptimizedWithStyles = true
                    }
                    return .continue
                }
            )
        ))

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                exit: { node, _ in
                    guard node.name == "g", node.children.count > 1 else { return }
                    guard !deoptimizedWithStyles else { return }

                    // Collect common inheritable attributes across all element children
                    var commonAttributes: [(key: String, value: String)] = []
                    var initial = true
                    var everyChildIsPath = true

                    for child in node.children {
                        guard case .element(let childElem) = child else { continue }

                        if !pathElems.contains(childElem.name) {
                            everyChildIsPath = false
                        }

                        if initial {
                            initial = false
                            // Collect all inheritable attributes from first element child
                            for (name, value) in childElem.attributes {
                                if inheritableAttrs.contains(name) {
                                    commonAttributes.append((key: name, value: value))
                                }
                            }
                        } else {
                            // Keep only attributes that match across all children
                            commonAttributes = commonAttributes.filter { attr in
                                childElem.attributes[attr.key] == attr.value
                            }
                        }
                    }

                    guard !commonAttributes.isEmpty else { return }

                    // Preserve transform on children when group has filter/clip-path/mask
                    if node.attributes["filter"] != nil
                        || node.attributes["clip-path"] != nil
                        || node.attributes["mask"] != nil
                    {
                        commonAttributes.removeAll { $0.key == "transform" }
                    }

                    // Preserve transform when all children are path elements
                    if everyChildIsPath {
                        commonAttributes.removeAll { $0.key == "transform" }
                    }

                    guard !commonAttributes.isEmpty else { return }

                    // Move common attributes to group
                    for attr in commonAttributes {
                        if attr.key == "transform" {
                            if let existing = node.attributes["transform"] {
                                node.attributes["transform"] = "\(existing) \(attr.value)"
                            } else {
                                node.attributes["transform"] = attr.value
                            }
                        } else {
                            node.attributes[attr.key] = attr.value
                        }
                    }

                    // Remove common attributes from children
                    let commonKeys = Set(commonAttributes.map { $0.key })
                    for child in node.children {
                        if case .element(let childElem) = child {
                            for key in commonKeys {
                                childElem.attributes[key] = nil
                            }
                        }
                    }
                }
            )
        )
    }
}
