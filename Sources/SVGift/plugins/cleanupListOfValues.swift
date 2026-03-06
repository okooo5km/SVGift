// cleanupListOfValues.swift
// Plugin to round list-of-values attributes to fixed precision
// okooo5km(十里)

import Foundation

/// Round numeric values in list-type attributes (points, viewBox, stroke-dasharray,
/// enable-background, dx, dy, x, y) to fixed precision.
///
/// Parameters: same as cleanupNumericValues.
public func makeCleanupListOfValuesPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "cleanupListOfValues") { _, params, _ in
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

        let listAttrs: Set<String> = [
            "points", "enable-background", "viewBox",
            "stroke-dasharray", "dx", "dy", "x", "y",
        ]

        func roundValues(_ input: String) -> String {
            let tokens = input.split(omittingEmptySubsequences: true) { c in
                c == "," || c.isWhitespace
            }.map { String($0) }

            var roundedList: [String] = []

            for elem in tokens {
                let range = NSRange(elem.startIndex..<elem.endIndex, in: elem)
                if let match = regNumericValues.firstMatch(in: elem, range: range) {
                    let numStr = String(elem[Range(match.range(at: 1), in: elem)!])
                    let matchedUnit: String
                    if match.range(at: 3).location != NSNotFound {
                        matchedUnit = String(elem[Range(match.range(at: 3), in: elem)!])
                    } else {
                        matchedUnit = ""
                    }

                    var num = toFixed(Double(numStr) ?? 0, floatPrecision)
                    var units = matchedUnit

                    // Convert absolute units to px
                    if convertToPx && !units.isEmpty, let factor = absoluteLengths[units] {
                        let pxNum = toFixed(factor * (Double(numStr) ?? 0), floatPrecision)
                        let pxStr = formatListNumber(pxNum)
                        if pxStr.count < elem.count {
                            num = pxNum
                            units = "px"
                        }
                    }

                    let str: String
                    if leadingZero {
                        str = removeLeadingZero(num)
                    } else {
                        str = formatListNumber(num)
                    }

                    if defaultPx && units == "px" {
                        units = ""
                    }

                    roundedList.append(str + units)
                } else if elem == "new" || elem == "none" {
                    roundedList.append(elem)
                } else if !elem.isEmpty {
                    roundedList.append(elem)
                }
            }

            return roundedList.joined(separator: " ")
        }

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    for attr in listAttrs {
                        if let value = node.attributes[attr] {
                            node.attributes[attr] = roundValues(value)
                        }
                    }
                    return .continue
                }
            )
        )
    }
}

/// Format a Double, removing trailing ".0" for integers.
private func formatListNumber(_ num: Double) -> String {
    var v = num
    if v == 0 { v = 0 }
    if v == v.rounded() && !v.isInfinite && abs(v) < 1e15 {
        return String(Int(v))
    }
    return String(v)
}
