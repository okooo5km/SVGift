// collapseGroups.swift
// Plugin to collapse useless <g> wrapper elements
// okooo5km(十里)

import Foundation

/// Collapse useless `<g>` wrapper elements.
///
/// When a `<g>` element has no attributes, its children are spliced into
/// the parent in place of the group. When a `<g>` has attributes and
/// exactly one child element, the attributes are merged onto the child
/// and the group is unwrapped.
public func makeCollapseGroupsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "collapseGroups") { root, _, _ in
        let stylesheet = collectStylesheet(root)
        let animationElems = elemsGroups["animation"] ?? []

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                exit: { node, parent in
                    // Only process <g> elements
                    guard node.name == "g" else { return }

                    // Skip if parent is root (svg is wrapped in root)
                    if case .root = parent { return }

                    // Skip if parent is <switch>
                    if case .element(let parentEl) = parent, parentEl.name == "switch" {
                        return
                    }

                    // Skip empty groups (handled by removeEmptyContainers)
                    guard !node.children.isEmpty else { return }

                    // Case 1: <g> has attributes and exactly 1 child element
                    if node.attributes.count != 0 && node.children.count == 1 {
                        if case .element(let firstChild) = node.children[0] {
                            // Check if g has filter (attribute or computed style)
                            let nodeHasFilter: Bool = {
                                if node.attributes["filter"] != nil { return true }
                                let computed = computeStyle(stylesheet: stylesheet, node: node)
                                if let filterVal = computed["filter"] {
                                    switch filterVal {
                                    case .static(let value, _):
                                        return !value.isEmpty && value != "none"
                                    case .dynamic:
                                        return true
                                    }
                                }
                                return false
                            }()

                            if firstChild.attributes["id"] == nil
                                && !nodeHasFilter
                                && (node.attributes["class"] == nil || firstChild.attributes["class"] == nil)
                                && ((node.attributes["clip-path"] == nil && node.attributes["mask"] == nil)
                                    || (firstChild.name == "g"
                                        && node.attributes["transform"] == nil
                                        && firstChild.attributes["transform"] == nil))
                            {
                                // Build new child attributes by copying child's attrs first,
                                // then merging g's attrs on top
                                var newChildPairs: [(key: String, value: String)] = []
                                for (key, value) in firstChild.attributes {
                                    newChildPairs.append((key: key, value: value))
                                }

                                var shouldReturn = false
                                for (name, value) in node.attributes {
                                    // Check for animated attribute conflict
                                    if hasAnimatedAttr(node: firstChild, name: name) {
                                        shouldReturn = true
                                        break
                                    }

                                    let existingIndex = newChildPairs.firstIndex(where: { $0.key == name })
                                    if existingIndex == nil {
                                        // Child doesn't have this attr — copy from g
                                        newChildPairs.append((key: name, value: value))
                                    } else if name == "transform" {
                                        // Concatenate: parent transform first, then child transform
                                        newChildPairs[existingIndex!] = (key: name, value: value + " " + newChildPairs[existingIndex!].value)
                                    } else if newChildPairs[existingIndex!].value == "inherit" {
                                        // Child inherits — use parent's value
                                        newChildPairs[existingIndex!] = (key: name, value: value)
                                    } else if !inheritableAttrs.contains(name) && newChildPairs[existingIndex!].value != value {
                                        // Non-inheritable attr with different value — bail
                                        shouldReturn = true
                                        break
                                    }
                                    // else: inheritable attr with different value, or same value — keep child's
                                }

                                if shouldReturn { /* skip merge */ } else {
                                    // Clear g's attributes
                                    node.attributes.removeAll()
                                    // Set child's attributes to the merged result
                                    firstChild.attributes = OrderedAttributes(newChildPairs)
                                }
                            }
                        }
                    }

                    // Case 2: <g> has no attributes — splice children into parent
                    if node.attributes.isEmpty {
                        // Check that none of the children are animation elements
                        let hasAnimation = node.children.contains { child in
                            if case .element(let el) = child {
                                return animationElems.contains(el.name)
                            }
                            return false
                        }
                        if hasAnimation { return }

                        // Splice g's children into parent, replacing g
                        guard case .element(let parentEl) = parent else { return }

                        guard let gIndex = parentEl.children.firstIndex(where: {
                            if case .element(let el) = $0 { return el === node }
                            return false
                        }) else { return }

                        var newChildren = parentEl.children
                        newChildren.remove(at: gIndex)
                        newChildren.insert(contentsOf: node.children, at: gIndex)
                        parentEl.children = newChildren
                    }
                }
            )
        )
    }
}

/// Check if any animation child of the node targets the given attribute name.
/// Recursively checks nested elements.
private func hasAnimatedAttr(node: XastElement, name: String) -> Bool {
    let animationElems = elemsGroups["animation"] ?? []

    for child in node.children {
        guard case .element(let el) = child else { continue }

        if animationElems.contains(el.name) {
            if el.attributes["attributeName"] == name {
                return true
            }
        }

        // Recurse
        if hasAnimatedAttr(node: el, name: name) {
            return true
        }
    }

    return false
}
