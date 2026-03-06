// removeAttrs.swift
// Plugin to remove attributes matching patterns from SVG elements
// okooo5km(十里)

import Foundation

/// Remove attributes from SVG elements based on pattern matching.
///
/// Parameters:
/// - `attrs`: A pattern string or JSON array of patterns. Each pattern uses
///   `elemSeparator` (default `:`) to split into `[elemPattern:]attrPattern[:valuePattern]`.
///   - 1 part: matches any element, pattern matches attribute name, any value
///   - 2 parts: element pattern, attribute pattern, any value
///   - 3 parts: element pattern, attribute pattern, value pattern
///   Patterns are treated as regex (wrapped in `^...$`).
///   Default: `"*"` (matches all attributes — effectively a no-op unless explicitly set).
/// - `elemSeparator`: Separator for pattern parts. Default: `":"`.
/// - `preserveCurrentColor`: If `"true"`, attributes with value `currentColor`
///   (case-insensitive) are preserved. Default: `"false"`.
public func makeRemoveAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeAttrs") { _, params, _ in
        let elemSeparator = params["elemSeparator"] ?? ":"
        let preserveCurrentColor = params["preserveCurrentColor"]?.lowercased() == "true"

        // Parse attrs param — can be a single string or a JSON array of strings
        var rawPatterns: [String] = []
        if let attrsParam = params["attrs"] {
            // Try to parse as JSON array first
            if attrsParam.hasPrefix("["),
               let data = attrsParam.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                rawPatterns = arr
            } else {
                rawPatterns = [attrsParam]
            }
        }

        // If no attrs specified (or empty), return no-op visitor
        guard !rawPatterns.isEmpty else {
            return Visitor()
        }

        // Parse each pattern into (elemRegex, attrRegex, valueRegex)
        struct AttrPattern {
            let elemRegex: NSRegularExpression
            let attrRegex: NSRegularExpression
            let valueRegex: NSRegularExpression
        }

        var patterns: [AttrPattern] = []
        for raw in rawPatterns {
            let parts = raw.components(separatedBy: elemSeparator)
            let elemStr: String
            let attrStr: String
            let valueStr: String

            switch parts.count {
            case 1:
                elemStr = ".*"
                attrStr = parts[0]
                valueStr = ".*"
            case 2:
                elemStr = parts[0]
                attrStr = parts[1]
                valueStr = ".*"
            default:
                // 3 or more parts — rejoin excess into value pattern
                elemStr = parts[0]
                attrStr = parts[1]
                valueStr = parts[2...].joined(separator: elemSeparator)
            }

            guard let eRx = try? NSRegularExpression(pattern: "^\(elemStr)$"),
                  let aRx = try? NSRegularExpression(pattern: "^\(attrStr)$"),
                  let vRx = try? NSRegularExpression(pattern: "^\(valueStr)$")
            else { continue }

            patterns.append(AttrPattern(elemRegex: eRx, attrRegex: aRx, valueRegex: vRx))
        }

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    let elemName = node.name

                    for pattern in patterns {
                        let elemRange = NSRange(elemName.startIndex..., in: elemName)
                        guard pattern.elemRegex.firstMatch(in: elemName, range: elemRange) != nil else {
                            continue
                        }

                        // Collect keys to remove (iterate over snapshot to allow mutation)
                        let attrKeys = node.attributes.keys
                        for key in attrKeys {
                            let keyRange = NSRange(key.startIndex..., in: key)
                            guard pattern.attrRegex.firstMatch(in: key, range: keyRange) != nil else {
                                continue
                            }

                            if let value = node.attributes[key] {
                                // Check preserveCurrentColor
                                if preserveCurrentColor &&
                                    value.lowercased() == "currentcolor" {
                                    continue
                                }

                                let valRange = NSRange(value.startIndex..., in: value)
                                if pattern.valueRegex.firstMatch(in: value, range: valRange) != nil {
                                    node.attributes[key] = nil
                                }
                            }
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
