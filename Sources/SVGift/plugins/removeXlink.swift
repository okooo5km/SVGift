// removeXlink.swift
// Plugin to remove xlink namespace and replace with SVG 2 equivalents
// okooo5km(十里)

import Foundation

/// URI indicating the XLink namespace.
private let xlinkNamespace = "http://www.w3.org/1999/xlink"

/// Map of `xlink:show` values to SVG 2 `target` attribute values.
private let showToTarget: [String: String] = [
    "new": "_blank",
    "replace": "_self",
]

/// Elements that use xlink:href but were deprecated in SVG 2 and therefore
/// don't support the SVG 2 href attribute.
private let legacyElements: Set<String> = [
    "cursor", "filter", "font-face-uri", "glyphRef", "tref",
]

/// Find all attributes matching `prefix:attr` for the given prefixes.
private func findPrefixedAttrs(
    _ node: XastElement,
    prefixes: [String],
    attr: String
) -> [String] {
    return prefixes
        .map { "\($0):\(attr)" }
        .filter { node.attributes[$0] != nil }
}

/// Remove XLink namespace prefixes and convert references to XLink
/// attributes to the native SVG 2 equivalent.
///
/// Parameters:
/// - `includeLegacy`: `"true"` to force operating on legacy elements
///   (cursor, filter, font-face-uri, glyphRef, tref). Default: `"false"`.
///
/// @see https://developer.mozilla.org/en-US/docs/Web/SVG/Attribute/xlink:href
public func makeRemoveXlinkPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeXlink") { _, params, _ in
        let includeLegacy = params["includeLegacy"] == "true"

        // XLink namespace prefixes currently in the stack
        var xlinkPrefixes: [String] = []

        // Prefixes that were overridden in a child element to point to
        // another namespace
        var overriddenPrefixes: [String] = []

        // Prefixes used in one of the legacy elements
        var usedInLegacyElement: [String] = []

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    // Scan xmlns:* attributes for xlink namespace
                    for (key, value) in node.attributes {
                        guard key.hasPrefix("xmlns:") else { continue }
                        let prefix = String(key.dropFirst("xmlns:".count))

                        if value == xlinkNamespace {
                            xlinkPrefixes.append(prefix)
                            continue
                        }

                        if xlinkPrefixes.contains(prefix) {
                            overriddenPrefixes.append(prefix)
                        }
                    }

                    // If any xlink prefix is overridden in this scope, skip
                    if overriddenPrefixes.contains(where: { xlinkPrefixes.contains($0) }) {
                        return .continue
                    }

                    // Handle xlink:show → target
                    let showAttrs = findPrefixedAttrs(node, prefixes: xlinkPrefixes, attr: "show")
                    var showHandled = node.attributes["target"] != nil
                    for attr in showAttrs.reversed() {
                        let value = node.attributes[attr] ?? ""
                        let mapping = showToTarget[value]

                        if showHandled || mapping == nil {
                            node.attributes[attr] = nil
                        } else {
                            if let mapping = mapping {
                                node.attributes["target"] = mapping
                            }
                            node.attributes[attr] = nil
                            showHandled = true
                        }
                    }

                    // Handle xlink:title → <title> child element
                    let titleAttrs = findPrefixedAttrs(node, prefixes: xlinkPrefixes, attr: "title")
                    for attr in titleAttrs.reversed() {
                        let value = node.attributes[attr] ?? ""

                        // Check if a <title> child already exists
                        let hasTitle = node.children.contains { child in
                            if case .element(let e) = child, e.name == "title" {
                                return true
                            }
                            return false
                        }

                        if hasTitle {
                            node.attributes[attr] = nil
                            continue
                        }

                        // Create a <title> element and prepend it
                        let titleElem = XastElement(
                            name: "title",
                            attributes: [:],
                            children: [.text(XastText(value: value))]
                        )
                        node.children.insert(.element(titleElem), at: 0)
                        node.attributes[attr] = nil
                    }

                    // Handle xlink:href → href
                    let hrefAttrs = findPrefixedAttrs(node, prefixes: xlinkPrefixes, attr: "href")

                    if !hrefAttrs.isEmpty
                        && legacyElements.contains(node.name)
                        && !includeLegacy
                    {
                        // Track prefixes used in legacy elements
                        for attr in hrefAttrs {
                            let prefix = String(attr.split(separator: ":", maxSplits: 1).first ?? "")
                            usedInLegacyElement.append(prefix)
                        }
                        return .continue
                    }

                    for attr in hrefAttrs.reversed() {
                        let value = node.attributes[attr] ?? ""

                        if node.attributes["href"] != nil {
                            // href already exists, just remove the xlink version
                            node.attributes[attr] = nil
                            continue
                        }

                        node.attributes["href"] = value
                        node.attributes[attr] = nil
                    }

                    return .continue
                },
                exit: { node, _ in
                    // Clean up remaining xlink-prefixed attributes and xmlns declarations
                    for key in node.attributes.keys {
                        let parts = key.split(separator: ":", maxSplits: 1)
                        let prefix = String(parts.first ?? "")

                        if xlinkPrefixes.contains(prefix)
                            && !overriddenPrefixes.contains(prefix)
                            && !usedInLegacyElement.contains(prefix)
                            && !includeLegacy
                        {
                            // Remove any remaining xlink-prefixed attributes
                            // (xlink:type, xlink:role, xlink:arcrole, xlink:actuate, etc.)
                            node.attributes[key] = nil
                            continue
                        }

                        if key.hasPrefix("xmlns:") {
                            let localName = String(key.dropFirst("xmlns:".count))

                            if !usedInLegacyElement.contains(localName) {
                                if node.attributes[key] == xlinkNamespace {
                                    let index = xlinkPrefixes.firstIndex(of: localName)
                                    if let index = index {
                                        xlinkPrefixes.remove(at: index)
                                    }
                                    node.attributes[key] = nil
                                    continue
                                }

                                if overriddenPrefixes.contains(localName) {
                                    if let index = overriddenPrefixes.firstIndex(of: localName) {
                                        overriddenPrefixes.remove(at: index)
                                    }
                                }
                            }
                        }
                    }
                }
            )
        )
    }
}
