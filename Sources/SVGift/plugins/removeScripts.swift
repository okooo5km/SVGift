// removeScripts.swift
// Plugin to remove scripts and event handler attributes from SVG
// okooo5km(十里)

import Foundation

/// Collect all event handler attribute names from attrsGroups.
private let eventHandlerAttrs: Set<String> = {
    var result = Set<String>()
    for groupName in ["animationEvent", "graphicalEvent", "documentEvent", "documentElementEvent", "globalEvent"] {
        if let attrs = attrsGroups[groupName] {
            result.formUnion(attrs)
        }
    }
    return result
}()

/// Remove `<script>` elements, event handler attributes, and collapse
/// `<a>` elements with `javascript:` hrefs.
///
/// Parameters: none
///
/// Behavior:
/// - Removes all `<script>` elements
/// - Removes all event handler attributes from every element
/// - For `<a>` elements whose `href` or `xlink:href` (or any namespace `*:href`)
///   starts with `javascript:`, the `<a>` is replaced by its non-text children in the parent
public func makeRemoveScriptsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeScripts") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // Remove <script> elements
                    if node.name == "script" {
                        detachNodeFromParent(.element(node), from: parent)
                        return .continue
                    }

                    // Remove event handler attributes from all elements
                    for attr in eventHandlerAttrs {
                        if node.attributes[attr] != nil {
                            node.attributes[attr] = nil
                        }
                    }

                    return .continue
                },
                exit: { node, parent in
                    // Collapse <a> with javascript: href (exit so children are already processed)
                    guard node.name == "a" else { return }

                    for key in node.attributes.keys {
                        if key == "href" || key.hasSuffix(":href") {
                            guard let value = node.attributes[key],
                                  value.trimmingCharacters(in: .init(charactersIn: " \t\n\r\u{000C}"))
                                      .hasPrefix("javascript:") else {
                                continue
                            }

                            // Filter out text children, keep only non-text children
                            let usefulChildren = node.children.filter { child in
                                if case .text = child { return false }
                                return true
                            }

                            // Splice useful children into parent in place of this <a>
                            let nodeChild = XastChild.element(node)
                            switch parent {
                            case .root(let root):
                                if let idx = root.children.firstIndex(where: { $0.isIdentical(to: nodeChild) }) {
                                    root.children.replaceSubrange(idx...idx, with: usefulChildren)
                                }
                            case .element(let element):
                                if let idx = element.children.firstIndex(where: { $0.isIdentical(to: nodeChild) }) {
                                    element.children.replaceSubrange(idx...idx, with: usefulChildren)
                                }
                            }
                        }
                    }
                }
            )
        )
    }
}

