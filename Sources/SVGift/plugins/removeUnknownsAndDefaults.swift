// removeUnknownsAndDefaults.swift
// Plugin to remove unknown elements/attributes and attributes with default values
// okooo5km(十里)

import Foundation

// MARK: - Additional attribute groups

/// Additional attribute groups needed for element definitions.
/// filterPrimitive and transferFunction are attribute groups in the SVG spec
/// that are referenced by element definitions but not included in the
/// main attrsGroups dictionary in Collections.swift.
private let additionalAttrsGroups: [String: Set<String>] = [
    "filterPrimitive": ["x", "y", "width", "height", "result"],
    "transferFunction": [
        "amplitude", "exponent", "intercept", "offset", "slope",
        "tableValues", "type",
    ],
    // The "animation" group in attrsGroups context (used by "set" element)
    "animation": [
        "begin", "dur", "end", "fill", "max", "min",
        "repeatCount", "repeatDur", "restart",
        "additive", "accumulate",
        "by", "calcMode", "from", "keySplines", "keyTimes", "to", "values",
    ],
]

// MARK: - Pre-computed lookup tables

/// Resolve an attribute group name to its set of attributes,
/// checking both the main attrsGroups and additional groups.
private func resolveAttrsGroup(_ name: String) -> Set<String> {
    if let group = attrsGroups[name] {
        return group
    }
    if let group = additionalAttrsGroups[name] {
        return group
    }
    return []
}

/// Allowed children for each element (expanded from contentGroups + content).
private let allowedChildrenPerElement: [String: Set<String>] = {
    var result: [String: Set<String>] = [:]
    for (name, config) in elems {
        var allowed = Set<String>()
        for groupName in config.contentGroups {
            if let group = elemsGroups[groupName] {
                allowed.formUnion(group)
            }
        }
        allowed.formUnion(config.content)
        result[name] = allowed
    }
    return result
}()

/// Allowed attributes for each element (expanded from attrsGroups + attrs).
private let allowedAttributesPerElement: [String: Set<String>] = {
    var result: [String: Set<String>] = [:]
    for (name, config) in elems {
        var allowed = Set<String>()
        for groupName in config.attrsGroups {
            allowed.formUnion(resolveAttrsGroup(groupName))
        }
        allowed.formUnion(config.attrs)
        result[name] = allowed
    }
    return result
}()

/// Default attribute values for each element (merged from attrsGroupsDefaults + element defaults).
private let attributesDefaultsPerElement: [String: [String: String]] = {
    var result: [String: [String: String]] = [:]
    for (name, config) in elems {
        var defaults: [String: String] = [:]
        for groupName in config.attrsGroups {
            if let groupDefaults = attrsGroupsDefaults[groupName] {
                for (attrName, defaultValue) in groupDefaults {
                    defaults[attrName] = defaultValue
                }
            }
        }
        // Element-level defaults override group defaults
        for (attrName, defaultValue) in config.defaults {
            defaults[attrName] = defaultValue
        }
        result[name] = defaults
    }
    return result
}()

// MARK: - Helper: includesAttrSelector

/// Check if a CSS selector string includes an attribute selector matching the given name.
/// Used to prevent removing default attributes that are targeted by CSS attribute selectors.
private func includesAttrSelector(_ selectorText: String, name: String) -> Bool {
    guard let selectorList = try? parseSelector(selectorText) else { return false }
    for complex in selectorList.selectors {
        for segment in complex.segments {
            for component in segment.compound.components {
                if case .attribute(let attrName, _, _) = component, attrName == name {
                    return true
                }
            }
        }
    }
    return false
}

// MARK: - Standalone regex for instruction cleanup

private let standaloneRegex = try! NSRegularExpression(
    pattern: #"\s*standalone\s*=\s*(["'])no\1"#
)

// MARK: - Plugin

/// Remove unknown elements content and attributes, remove attributes with default values.
///
/// Parameters:
/// - `unknownContent`: Remove unknown child elements. Default `"true"`.
/// - `unknownAttrs`: Remove unknown attributes. Default `"true"`.
/// - `defaultAttrs`: Remove attributes matching their default value. Default `"true"`.
/// - `defaultMarkupDeclarations`: Remove default XML declaration properties (e.g. `standalone="no"`). Default `"true"`.
/// - `uselessOverrides`: Remove attributes that override an identical inherited value. Default `"true"`.
/// - `keepDataAttrs`: Preserve `data-*` attributes. Default `"true"`.
/// - `keepAriaAttrs`: Preserve `aria-*` attributes. Default `"true"`.
/// - `keepRoleAttr`: Preserve `role` attribute. Default `"false"`.
public func makeRemoveUnknownsAndDefaultsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeUnknownsAndDefaults") { root, params, _ in
        let unknownContent = params["unknownContent"] != "false"
        let unknownAttrs = params["unknownAttrs"] != "false"
        let defaultAttrs = params["defaultAttrs"] != "false"
        let defaultMarkupDeclarations = params["defaultMarkupDeclarations"] != "false"
        let uselessOverrides = params["uselessOverrides"] != "false"
        let keepDataAttrs = params["keepDataAttrs"] != "false"
        let keepAriaAttrs = params["keepAriaAttrs"] != "false"
        let keepRoleAttr = params["keepRoleAttr"] == "true"

        let stylesheet = collectStylesheet(root)

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    // Skip namespaced elements
                    if node.name.contains(":") {
                        return .continue
                    }
                    // Skip visiting foreignObject subtree
                    if node.name == "foreignObject" {
                        return .skip
                    }

                    // Remove unknown element's content
                    if unknownContent, case .element(let parentElement) = parentNode {
                        let allowedChildren = allowedChildrenPerElement[parentElement.name]
                        if allowedChildren == nil || allowedChildren!.isEmpty {
                            // Parent has no known children spec — remove if element is unknown
                            if allowedChildrenPerElement[node.name] == nil {
                                detachNodeFromParent(.element(node), from: parentNode)
                                return .continue
                            }
                        } else {
                            // Parent has an explicit list — remove if not in it
                            if !allowedChildren!.contains(node.name) {
                                detachNodeFromParent(.element(node), from: parentNode)
                                return .continue
                            }
                        }
                    }

                    let allowedAttributes = allowedAttributesPerElement[node.name]
                    let attributesDefaults = attributesDefaultsPerElement[node.name]
                    let computedParentStyle: ComputedStyles?
                    if case .element(let parentElement) = parentNode {
                        computedParentStyle = computeStyle(stylesheet: stylesheet, node: parentElement)
                    } else {
                        computedParentStyle = nil
                    }

                    // Iterate over a snapshot of keys since we may delete during iteration
                    let attrKeys = node.attributes.keys
                    for name in attrKeys {
                        guard let value = node.attributes[name] else { continue }

                        if keepDataAttrs && name.hasPrefix("data-") {
                            continue
                        }
                        if keepAriaAttrs && name.hasPrefix("aria-") {
                            continue
                        }
                        if keepRoleAttr && name == "role" {
                            continue
                        }
                        // Skip xmlns attribute
                        if name == "xmlns" {
                            continue
                        }
                        // Skip namespaced attributes except xml:* and xlink:*
                        if name.contains(":") {
                            let prefix = String(name.prefix(while: { $0 != ":" }))
                            if prefix != "xml" && prefix != "xlink" {
                                continue
                            }
                        }

                        // Remove unknown attributes
                        if unknownAttrs,
                           let allowed = allowedAttributes,
                           !allowed.contains(name) {
                            node.attributes[name] = nil
                            continue
                        }

                        // Remove attributes with default values
                        if defaultAttrs,
                           node.attributes["id"] == nil,
                           let defaults = attributesDefaults,
                           let defaultValue = defaults[name],
                           defaultValue == value {
                            // Keep default if parent has own or inherited style for this property
                            if computedParentStyle?[name] == nil
                                && !stylesheet.rules.contains(where: { rule in
                                    includesAttrSelector(rule.selectorText, name: name)
                                }) {
                                node.attributes[name] = nil
                                continue
                            }
                        }

                        // Remove useless overrides
                        if uselessOverrides, node.attributes["id"] == nil {
                            if let parentStyle = computedParentStyle?[name],
                               !presentationNonInheritableGroupAttrs.contains(name) {
                                if case .static(let parentValue, _) = parentStyle,
                                   parentValue == value {
                                    node.attributes[name] = nil
                                }
                            }
                        }
                    }

                    return .continue
                }
            ),
            instruction: defaultMarkupDeclarations ? VisitorCallbacks<XastInstruction>(
                enter: { node, _ in
                    let value = node.value
                    let range = NSRange(value.startIndex..<value.endIndex, in: value)
                    let newValue = standaloneRegex.stringByReplacingMatches(
                        in: value, range: range, withTemplate: ""
                    )
                    if newValue != value {
                        node.value = newValue
                    }
                    return .continue
                }
            ) : nil
        )
    }
}
