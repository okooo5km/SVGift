// sortAttrs.swift
// Plugin to sort element attributes for better compression
// okooo5km(十里)

import Foundation

/// Default attribute sort order — common attributes are placed first
/// for better gzip compression.
private let defaultOrder: [String] = [
    "id",
    "width",
    "height",
    "x",
    "x1",
    "x2",
    "y",
    "y1",
    "y2",
    "cx",
    "cy",
    "r",
    "fill",
    "stroke",
    "marker",
    "d",
    "points",
]

/// Sort element attributes for better compression.
///
/// Parameters:
/// - `order`: JSON array of attribute name prefixes defining sort priority
///   (default: id, width, height, x, y, cx, cy, r, fill, stroke, marker, d, points)
/// - `xmlnsOrder`: `"front"` (default) puts xmlns attributes first,
///   `"alphabetical"` sorts them with everything else
public func makeSortAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "sortAttrs") { _, params, _ in
        // Parse order parameter (JSON array string)
        let order: [String]
        if let orderParam = params["order"],
           let data = orderParam.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String] {
            order = parsed
        } else {
            order = defaultOrder
        }

        let xmlnsOrder = params["xmlnsOrder"] ?? "front"

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    let attrs = Array(node.attributes)
                    let sorted = attrs.sorted { a, b in
                        compareAttrs(a.key, b.key, order: order, xmlnsOrder: xmlnsOrder)
                    }

                    // Rebuild attributes in sorted order
                    var newAttrs = OrderedAttributes()
                    for (key, value) in sorted {
                        newAttrs[key] = value
                    }
                    node.attributes = newAttrs

                    return .continue
                }
            )
        )
    }
}

/// Compare two attribute names for sorting.
/// Returns true if `a` should come before `b`.
private func compareAttrs(
    _ aName: String,
    _ bName: String,
    order: [String],
    xmlnsOrder: String
) -> Bool {
    // Sort by namespace priority
    let aPriority = getNsPriority(aName, xmlnsOrder: xmlnsOrder)
    let bPriority = getNsPriority(bName, xmlnsOrder: xmlnsOrder)
    if aPriority != bPriority {
        return aPriority > bPriority
    }

    // Extract first part (before first hyphen)
    let aPart = String(aName.split(separator: "-").first ?? Substring(aName))
    let bPart = String(bName.split(separator: "-").first ?? Substring(bName))

    // If the first parts differ, use order-based sorting
    if aPart != bPart {
        let aIdx = order.firstIndex(of: aPart)
        let bIdx = order.firstIndex(of: bPart)

        if let ai = aIdx, let bi = bIdx {
            return ai < bi
        }
        // Attributes in order list come before others
        if aIdx != nil { return true }
        if bIdx != nil { return false }
    }

    // Alphabetical fallback
    return aName < bName
}

/// Get namespace priority for sorting.
/// Higher values = sorted earlier.
private func getNsPriority(_ name: String, xmlnsOrder: String) -> Int {
    if xmlnsOrder == "front" {
        if name == "xmlns" { return 3 }
        if name.hasPrefix("xmlns:") { return 2 }
    }
    if name.contains(":") { return 1 }
    return 0
}
