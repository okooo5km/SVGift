// removeViewBox.swift
// Plugin to remove viewBox when it matches width/height
// okooo5km(十里)

import Foundation

/// Remove the `viewBox` attribute when it is redundant (matches the element's
/// `width` and `height` with zero offset).
///
/// Parameters: none
///
/// Applies to `<svg>`, `<pattern>`, and `<symbol>` elements.
/// The viewBox is only removed when:
/// - `minX` and `minY` are both 0
/// - `width` from viewBox matches the element's `width` attribute
/// - `height` from viewBox matches the element's `height` attribute
///
/// Nested `<svg>` elements are excluded to avoid breaking scaling.
public func makeRemoveViewBoxPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeViewBox") { _, _, _ in
        var isRootSVG = true

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    guard node.name == "svg" || node.name == "pattern" || node.name == "symbol" else {
                        return .continue
                    }

                    // Skip nested <svg> elements
                    if node.name == "svg" {
                        if isRootSVG {
                            isRootSVG = false
                        } else {
                            return .continue
                        }
                    }

                    guard let viewBoxStr = node.attributes["viewBox"],
                          let widthStr = node.attributes["width"],
                          let heightStr = node.attributes["height"]
                    else {
                        return .continue
                    }

                    // Parse viewBox: "minX minY width height"
                    // Supports both space and comma separators
                    let viewBoxParts = viewBoxStr
                        .components(separatedBy: CharacterSet(charactersIn: ", "))
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    guard viewBoxParts.count == 4,
                          let vbMinX = Double(viewBoxParts[0]),
                          let vbMinY = Double(viewBoxParts[1]),
                          let vbWidth = Double(viewBoxParts[2]),
                          let vbHeight = Double(viewBoxParts[3])
                    else {
                        return .continue
                    }

                    // Strip units from width/height for comparison
                    let widthNumStr = stripUnits(widthStr)
                    let heightNumStr = stripUnits(heightStr)

                    guard let elWidth = Double(widthNumStr),
                          let elHeight = Double(heightNumStr)
                    else {
                        return .continue
                    }

                    if vbMinX == 0 && vbMinY == 0 &&
                       vbWidth == elWidth && vbHeight == elHeight {
                        node.attributes["viewBox"] = nil
                    }

                    return .continue
                }
            )
        )
    }
}

/// Strip common CSS length units from a numeric string
private func stripUnits(_ value: String) -> String {
    let units = ["em", "ex", "px", "pt", "pc", "cm", "mm", "in", "%"]
    var result = value
    for unit in units {
        if result.hasSuffix(unit) {
            result = String(result.dropLast(unit.count))
            break
        }
    }
    return result
}
