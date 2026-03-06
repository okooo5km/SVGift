// cleanupAttrs.swift
// Plugin to cleanup attribute values from newlines, trailing and repeating spaces
// okooo5km(十里)

import Foundation

/// Cleanup attribute values from newlines, trailing and repeating spaces.
///
/// Parameters:
/// - `newlines`: Replace newlines in attribute values (default: "true")
/// - `trim`: Trim leading/trailing whitespace from attribute values (default: "true")
/// - `spaces`: Collapse multiple spaces to one (default: "true")
public func makeCleanupAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "cleanupAttrs") { _, params, _ in
        let newlines = params["newlines"] != "false"
        let trim = params["trim"] != "false"
        let spaces = params["spaces"] != "false"

        // Regex: newline between two non-whitespace characters (needs space)
        let regNewlinesNeedSpace = try! NSRegularExpression(pattern: #"(\S)\r?\n(\S)"#)
        // Regex: any newline
        let regNewlines = try! NSRegularExpression(pattern: #"\r?\n"#)
        // Regex: two or more whitespace characters
        let regSpaces = try! NSRegularExpression(pattern: #"\s{2,}"#)

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    for (key, value) in node.attributes {
                        var result = value

                        if newlines {
                            // Replace newline between non-whitespace chars with a space
                            let range = NSRange(result.startIndex..., in: result)
                            result = regNewlinesNeedSpace.stringByReplacingMatches(
                                in: result,
                                range: range,
                                withTemplate: "$1 $2"
                            )
                            // Remove remaining newlines
                            let range2 = NSRange(result.startIndex..., in: result)
                            result = regNewlines.stringByReplacingMatches(
                                in: result,
                                range: range2,
                                withTemplate: ""
                            )
                        }

                        if trim {
                            result = result.trimmingCharacters(in: .whitespaces)
                        }

                        if spaces {
                            let range = NSRange(result.startIndex..., in: result)
                            result = regSpaces.stringByReplacingMatches(
                                in: result,
                                range: range,
                                withTemplate: " "
                            )
                        }

                        if result != value {
                            node.attributes[key] = result
                        }
                    }
                    return .continue
                }
            )
        )
    }
}
