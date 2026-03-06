// cleanupEnableBackground.swift
// Plugin to remove or cleanup enable-background attribute when possible
// okooo5km(十里)

import Foundation

/// Regex matching `new 0 0 <width> <height>` in enable-background values.
private let regEnableBackground = try! NSRegularExpression(
    pattern: #"^new\s0\s0\s([-+]?\d*\.?\d+([eE][-+]?\d+)?)\s([-+]?\d*\.?\d+([eE][-+]?\d+)?)$"#
)

/// Remove or cleanup `enable-background` attribute when it coincides with
/// the element's width/height box.
///
/// If no `<filter>` elements exist in the document, removes all
/// `enable-background` attributes/declarations. Otherwise, for `<svg>`,
/// `<mask>`, and `<pattern>` elements, simplifies redundant values.
///
/// @see https://www.w3.org/TR/SVG11/filters.html#EnableBackgroundProperty
public func makeCleanupEnableBackgroundPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "cleanupEnableBackground") { root, _, _ in
        // Pre-scan: check if any <filter> element exists
        var hasFilter = false
        visit(root, visitor: Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if node.name == "filter" {
                        hasFilter = true
                    }
                    return .continue
                }
            )
        ))

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    // Handle enable-background in style attribute
                    var styleDecls: [CSSDeclaration]? = nil
                    var styleEnableBGIndex: Int? = nil

                    if let styleValue = node.attributes["style"] {
                        var decls = parseCSSDeclarations(styleValue)
                        // Find last enable-background declaration
                        var lastIdx: Int? = nil
                        for (i, decl) in decls.enumerated() {
                            if decl.name == "enable-background" {
                                lastIdx = i
                            }
                        }
                        // Remove duplicates, keep only last
                        if lastIdx != nil {
                            var indicesToRemove: [Int] = []
                            for (i, decl) in decls.enumerated() {
                                if decl.name == "enable-background" && i != lastIdx {
                                    indicesToRemove.append(i)
                                }
                            }
                            for i in indicesToRemove.reversed() {
                                decls.remove(at: i)
                            }
                            // Recalculate lastIdx after removal
                            lastIdx = decls.firstIndex(where: { $0.name == "enable-background" })
                        }
                        styleDecls = decls
                        styleEnableBGIndex = lastIdx
                    }

                    if !hasFilter {
                        // No filters: remove all enable-background
                        node.attributes["enable-background"] = nil

                        if var decls = styleDecls {
                            if let idx = styleEnableBGIndex {
                                decls.remove(at: idx)
                            }
                            if decls.isEmpty {
                                node.attributes["style"] = nil
                            } else {
                                node.attributes["style"] = decls
                                    .map { "\($0.name):\($0.value)" }
                                    .joined(separator: ";")
                            }
                        }

                        return .continue
                    }

                    // Has filters: cleanup on svg/mask/pattern with dimensions
                    let hasDimensions =
                        node.attributes["width"] != nil
                        && node.attributes["height"] != nil

                    if (node.name == "svg" || node.name == "mask" || node.name == "pattern")
                        && hasDimensions
                    {
                        let width = node.attributes["width"] ?? ""
                        let height = node.attributes["height"] ?? ""

                        // Cleanup attribute value
                        if let attrValue = node.attributes["enable-background"] {
                            let cleaned = cleanupEnableBGValue(
                                attrValue,
                                nodeName: node.name,
                                width: width,
                                height: height
                            )
                            if let cleaned = cleaned {
                                node.attributes["enable-background"] = cleaned
                            } else {
                                node.attributes["enable-background"] = nil
                            }
                        }

                        // Cleanup style declaration
                        if var decls = styleDecls, let idx = styleEnableBGIndex {
                            let styleValue = decls[idx].value
                            let cleaned = cleanupEnableBGValue(
                                styleValue,
                                nodeName: node.name,
                                width: width,
                                height: height
                            )
                            if let cleaned = cleaned {
                                decls[idx] = CSSDeclaration(
                                    name: "enable-background",
                                    value: cleaned,
                                    important: decls[idx].important
                                )
                            } else {
                                decls.remove(at: idx)
                            }
                            styleDecls = decls
                        }
                    }

                    // Write back style if modified
                    if let decls = styleDecls {
                        if decls.isEmpty {
                            node.attributes["style"] = nil
                        } else {
                            node.attributes["style"] = decls
                                .map { "\($0.name):\($0.value)" }
                                .joined(separator: ";")
                        }
                    }

                    return .continue
                }
            )
        )
    }
}

/// Clean up an enable-background value. Returns the cleaned value,
/// or nil if it should be removed entirely.
private func cleanupEnableBGValue(
    _ value: String,
    nodeName: String,
    width: String,
    height: String
) -> String? {
    let nsValue = value as NSString
    let range = NSRange(location: 0, length: nsValue.length)

    guard let match = regEnableBackground.firstMatch(in: value, range: range) else {
        return value
    }

    // Extract matched width and height
    guard let wRange = Range(match.range(at: 1), in: value),
          let hRange = Range(match.range(at: 3), in: value)
    else {
        return value
    }

    let matchedWidth = String(value[wRange])
    let matchedHeight = String(value[hRange])

    if width == matchedWidth && height == matchedHeight {
        // For svg, remove entirely; for mask/pattern, simplify to "new"
        return nodeName == "svg" ? nil : "new"
    }

    return value
}
