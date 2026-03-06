// convertShapeToPath.swift
// Plugin to convert basic shapes to more compact path form
// okooo5km(十里)

import Foundation

/// Convert basic shape elements (rect, line, polyline, polygon, circle, ellipse)
/// to `<path>` elements.
///
/// Parameters:
/// - `convertArcs`: `"true"` to also convert circle/ellipse using arc commands.
/// - `floatPrecision`: Precision for stringifyPathData.
public func makeConvertShapeToPathPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertShapeToPath") { _, params, _ in
        let convertArcs = params["convertArcs"] == "true"
        let precision: Int?
        if let fp = params["floatPrecision"] {
            precision = Int(fp)
        } else {
            precision = nil
        }

        let regNumber = try! NSRegularExpression(
            pattern: "[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?"
        )

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    // rect → path (no rx/ry, no percentage values)
                    if node.name == "rect" &&
                        node.attributes["width"] != nil &&
                        node.attributes["height"] != nil &&
                        node.attributes["rx"] == nil &&
                        node.attributes["ry"] == nil {

                        let xStr = node.attributes["x"] ?? "0"
                        let yStr = node.attributes["y"] ?? "0"
                        let wStr = node.attributes["width"]!
                        let hStr = node.attributes["height"]!

                        guard let x = parseShapeNum(xStr),
                              let y = parseShapeNum(yStr),
                              let w = parseShapeNum(wStr),
                              let h = parseShapeNum(hStr) else {
                            return .continue
                        }

                        let pathData: [PathDataItem] = [
                            PathDataItem(command: "M", args: [x, y]),
                            PathDataItem(command: "H", args: [x + w]),
                            PathDataItem(command: "V", args: [y + h]),
                            PathDataItem(command: "H", args: [x]),
                            PathDataItem(command: "z", args: []),
                        ]
                        node.name = "path"
                        node.attributes["d"] = stringifyPathData(pathData, precision: precision)
                        node.attributes.removeValue(forKey: "x")
                        node.attributes.removeValue(forKey: "y")
                        node.attributes.removeValue(forKey: "width")
                        node.attributes.removeValue(forKey: "height")
                    }

                    // line → path
                    if node.name == "line" {
                        let x1Str = node.attributes["x1"] ?? "0"
                        let y1Str = node.attributes["y1"] ?? "0"
                        let x2Str = node.attributes["x2"] ?? "0"
                        let y2Str = node.attributes["y2"] ?? "0"

                        guard let x1 = parseShapeNum(x1Str),
                              let y1 = parseShapeNum(y1Str),
                              let x2 = parseShapeNum(x2Str),
                              let y2 = parseShapeNum(y2Str) else {
                            return .continue
                        }

                        let pathData: [PathDataItem] = [
                            PathDataItem(command: "M", args: [x1, y1]),
                            PathDataItem(command: "L", args: [x2, y2]),
                        ]
                        node.name = "path"
                        node.attributes["d"] = stringifyPathData(pathData, precision: precision)
                        node.attributes.removeValue(forKey: "x1")
                        node.attributes.removeValue(forKey: "y1")
                        node.attributes.removeValue(forKey: "x2")
                        node.attributes.removeValue(forKey: "y2")
                    }

                    // polyline / polygon → path
                    if (node.name == "polyline" || node.name == "polygon"),
                       let points = node.attributes["points"] {
                        let range = NSRange(points.startIndex..<points.endIndex, in: points)
                        let matches = regNumber.matches(in: points, range: range)
                        let coords = matches.compactMap { m -> Double? in
                            Double(String(points[Range(m.range, in: points)!]))
                        }

                        if coords.count < 4 {
                            detachNodeFromParent(.element(node), from: parentNode)
                            return .continue
                        }

                        var pathData: [PathDataItem] = []
                        var i = 0
                        while i + 1 < coords.count {
                            let cmd: Character = (i == 0) ? "M" : "L"
                            pathData.append(PathDataItem(command: cmd, args: [coords[i], coords[i + 1]]))
                            i += 2
                        }
                        if node.name == "polygon" {
                            pathData.append(PathDataItem(command: "z", args: []))
                        }

                        node.name = "path"
                        node.attributes["d"] = stringifyPathData(pathData, precision: precision)
                        node.attributes.removeValue(forKey: "points")
                    }

                    // circle → path (only when convertArcs is enabled)
                    if node.name == "circle" && convertArcs {
                        let cx = Double(node.attributes["cx"] ?? "0") ?? 0
                        let cy = Double(node.attributes["cy"] ?? "0") ?? 0
                        let r = Double(node.attributes["r"] ?? "0") ?? 0

                        if (cx - cy + r).isNaN { return .continue }

                        let pathData: [PathDataItem] = [
                            PathDataItem(command: "M", args: [cx, cy - r]),
                            PathDataItem(command: "A", args: [r, r, 0, 1, 0, cx, cy + r]),
                            PathDataItem(command: "A", args: [r, r, 0, 1, 0, cx, cy - r]),
                            PathDataItem(command: "z", args: []),
                        ]
                        node.name = "path"
                        node.attributes["d"] = stringifyPathData(pathData, precision: precision)
                        node.attributes.removeValue(forKey: "cx")
                        node.attributes.removeValue(forKey: "cy")
                        node.attributes.removeValue(forKey: "r")
                    }

                    // ellipse → path (only when convertArcs is enabled)
                    if node.name == "ellipse" && convertArcs {
                        let ecx = Double(node.attributes["cx"] ?? "0") ?? 0
                        let ecy = Double(node.attributes["cy"] ?? "0") ?? 0
                        let rx = Double(node.attributes["rx"] ?? "0") ?? 0
                        let ry = Double(node.attributes["ry"] ?? "0") ?? 0

                        if (ecx - ecy + rx - ry).isNaN { return .continue }

                        let pathData: [PathDataItem] = [
                            PathDataItem(command: "M", args: [ecx, ecy - ry]),
                            PathDataItem(command: "A", args: [rx, ry, 0, 1, 0, ecx, ecy + ry]),
                            PathDataItem(command: "A", args: [rx, ry, 0, 1, 0, ecx, ecy - ry]),
                            PathDataItem(command: "z", args: []),
                        ]
                        node.name = "path"
                        node.attributes["d"] = stringifyPathData(pathData, precision: precision)
                        node.attributes.removeValue(forKey: "cx")
                        node.attributes.removeValue(forKey: "cy")
                        node.attributes.removeValue(forKey: "rx")
                        node.attributes.removeValue(forKey: "ry")
                    }

                    return .continue
                }
            )
        )
    }
}

/// Parse a numeric string for shape conversion.
/// Returns nil if the value contains '%' or non-numeric units.
private func parseShapeNum(_ str: String) -> Double? {
    if str.contains("%") { return nil }
    // Also reject strings with non-numeric unit suffixes like "pt", "em", etc.
    let trimmed = str.trimmingCharacters(in: .whitespaces)
    if let val = Double(trimmed) {
        return val
    }
    // Check for units appended: try stripping known unit suffixes
    let units = ["px", "pt", "pc", "mm", "cm", "in", "ft", "em", "ex"]
    for unit in units {
        if trimmed.hasSuffix(unit) {
            // Has a unit → not a pure number, don't convert
            return nil
        }
    }
    return Double(trimmed)
}
