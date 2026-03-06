// removeDeprecatedAttrs.swift
// Plugin to remove deprecated attributes from SVG elements
// okooo5km(十里)

import Foundation

/// Remove deprecated attributes from SVG elements.
///
/// Removes attributes that are deprecated in the SVG specification.
/// By default, only safe deprecated attributes are removed. Set
/// `removeUnsafe` to `"true"` to also remove unsafe deprecated attributes.
///
/// Parameters:
/// - `removeUnsafe`: `"true"` to also remove unsafe deprecated attributes. Default: `"false"`.
public func makeRemoveDeprecatedAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeDeprecatedAttrs") { root, params, _ in
        let removeUnsafe = params["removeUnsafe"] == "true"

        let stylesheet = collectStylesheet(root)

        // Collect attribute names used in CSS selectors
        let cssReferencedAttrs = collectCSSReferencedAttrs(stylesheet: stylesheet)

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard let elemConfig = elems[node.name] else {
                        return .continue
                    }

                    // Handle xml:lang → lang deduplication (core attrsGroup)
                    if elemConfig.attrsGroups.contains("core") {
                        if node.attributes["xml:lang"] != nil
                            && node.attributes["lang"] != nil
                            && !cssReferencedAttrs.contains("xml:lang") {
                            node.attributes["xml:lang"] = nil
                        }
                    }

                    // Process attrsGroups deprecated entries
                    for groupName in elemConfig.attrsGroups {
                        guard let deprecated = attrsGroupsDeprecated[groupName] else {
                            continue
                        }
                        removeDeprecatedFromNode(
                            node: node,
                            deprecated: deprecated,
                            removeUnsafe: removeUnsafe,
                            cssReferencedAttrs: cssReferencedAttrs
                        )
                    }

                    // Process element-specific deprecated attrs
                    if let deprecated = elemConfig.deprecated {
                        removeDeprecatedFromNode(
                            node: node,
                            deprecated: deprecated,
                            removeUnsafe: removeUnsafe,
                            cssReferencedAttrs: cssReferencedAttrs
                        )
                    }

                    return .continue
                }
            )
        )
    }
}

/// Remove deprecated attributes from a node based on a deprecation config.
private func removeDeprecatedFromNode(
    node: XastElement,
    deprecated: DeprecatedAttrs,
    removeUnsafe: Bool,
    cssReferencedAttrs: Set<String>
) {
    for attr in deprecated.safe {
        if node.attributes[attr] != nil && !cssReferencedAttrs.contains(attr) {
            node.attributes[attr] = nil
        }
    }

    if removeUnsafe {
        for attr in deprecated.unsafe {
            if node.attributes[attr] != nil && !cssReferencedAttrs.contains(attr) {
                node.attributes[attr] = nil
            }
        }
    }
}

/// Collect attribute names referenced by CSS attribute selectors in the stylesheet.
private func collectCSSReferencedAttrs(stylesheet: Stylesheet) -> Set<String> {
    var attrs: Set<String> = []

    for rule in stylesheet.rules {
        if let selectorList = try? parseSelector(rule.selectorText) {
            for selector in selectorList.selectors {
                for segment in selector.segments {
                    for component in segment.compound.components {
                        if case .attribute(let name, _, _) = component {
                            attrs.insert(name)
                        }
                    }
                }
            }
        }
    }

    return attrs
}

/// Check if a CSS selector string contains an attribute selector matching a given name.
private func includesAttrSelector(selectorText: String, attrName: String) -> Bool {
    guard let selectorList = try? parseSelector(selectorText) else {
        return false
    }

    for selector in selectorList.selectors {
        for segment in selector.segments {
            for component in segment.compound.components {
                if case .attribute(let name, _, _) = component, name == attrName {
                    return true
                }
            }
        }
    }

    return false
}
