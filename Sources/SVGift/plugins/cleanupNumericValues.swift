// cleanupNumericValues.swift
// Plugin to round numeric values and convert units
// okooo5km(十里)

import Foundation

/// Round numeric attribute values to fixed precision, remove default "px" units,
/// and optionally convert absolute units to px.
///
/// Parameters:
/// - `floatPrecision`: Number of decimal places (default: 3)
/// - `leadingZero`: Remove leading zero from small decimals (default: `"true"`)
/// - `defaultPx`: Remove `"px"` unit suffix (default: `"true"`)
/// - `convertToPx`: Convert absolute units (cm, mm, in, pt, pc) to px (default: `"true"`)
public func makeCleanupNumericValuesPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "cleanupNumericValues") { _, params, _ in
        let floatPrecision = Int(params["floatPrecision"] ?? "") ?? 3
        let leadingZero = params["leadingZero"] != "false"
        let defaultPx = params["defaultPx"] != "false"
        let convertToPx = params["convertToPx"] != "false"

        let regNumericValues = try! NSRegularExpression(
            pattern: "^([-+]?\\d*\\.?\\d+([eE][-+]?\\d+)?)(px|pt|pc|mm|cm|m|in|ft|em|ex|%)?$"
        )

        let absoluteLengths: [String: Double] = [
            "cm": 96.0 / 2.54,
            "mm": 96.0 / 25.4,
            "in": 96.0,
            "pt": 4.0 / 3.0,
            "pc": 16.0,
            "px": 1.0,
        ]

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    // viewBox special handling
                    if let viewBox = node.attributes["viewBox"] {
                        let numbers = viewBox.trimmingCharacters(in: .whitespaces)
                            .split(omittingEmptySubsequences: true) { c in
                                c == "," || c.isWhitespace
                            }
                        let processed = numbers.map { token -> String in
                            let s = token.trimmingCharacters(in: .whitespaces)
                            if let num = Double(s) {
                                let rounded = toFixed(num, floatPrecision)
                                return formatCleanNumber(rounded)
                            }
                            return s
                        }
                        node.attributes["viewBox"] = processed.joined(separator: " ")
                    }

                    for (name, value) in node.attributes {
                        if name == "version" || name == "viewBox" { continue }

                        let range = NSRange(value.startIndex..<value.endIndex, in: value)
                        guard let match = regNumericValues.firstMatch(in: value, range: range) else {
                            continue
                        }

                        let numStr = String(value[Range(match.range(at: 1), in: value)!])
                        let matchedUnit: String
                        if match.range(at: 3).location != NSNotFound {
                            matchedUnit = String(value[Range(match.range(at: 3), in: value)!])
                        } else {
                            matchedUnit = ""
                        }

                        var num = toFixed(Double(numStr) ?? 0, floatPrecision)
                        var units = matchedUnit

                        // Convert absolute units to px
                        if convertToPx && !units.isEmpty, let factor = absoluteLengths[units] {
                            let pxNum = toFixed(factor * (Double(numStr) ?? 0), floatPrecision)
                            let pxStr = formatCleanNumber(pxNum)
                            if pxStr.count < value.count {
                                num = pxNum
                                units = "px"
                            }
                        }

                        // Format number
                        let str: String
                        if leadingZero {
                            str = removeLeadingZero(num)
                        } else {
                            str = formatCleanNumber(num)
                        }

                        // Remove default px
                        if defaultPx && units == "px" {
                            units = ""
                        }

                        node.attributes[name] = str + units
                    }

                    return .continue
                }
            )
        )
    }
}

/// Format a Double, removing trailing ".0" for integers.
private func formatCleanNumber(_ num: Double) -> String {
    var v = num
    if v == 0 { v = 0 }
    if v == v.rounded() && !v.isInfinite && abs(v) < 1e15 {
        return String(Int(v))
    }
    return String(v)
}
