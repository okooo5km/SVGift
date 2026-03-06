// References.swift
// Utilities for finding ID references in SVG attribute values
// okooo5km(十里)

import Foundation

/// Regex patterns for extracting references.
private let regReferencesUrl = try! NSRegularExpression(
    pattern: #"\burl\(["']?#(.+?)["']?\)"#
)
private let regReferencesHref = try! NSRegularExpression(
    pattern: #"^#(.+?)$"#
)
private let regReferencesBegin = try! NSRegularExpression(
    pattern: #"(\w+)\.[a-zA-Z]"#
)

/// Extract ID references from an attribute value.
///
/// Looks for:
/// - `url(#id)` in reference properties (fill, stroke, clip-path, etc.)
/// - `#id` in href attributes
/// - `elementId.event` in begin attributes
///
/// - Parameters:
///   - attribute: The attribute name.
///   - value: The attribute value.
/// - Returns: Array of referenced IDs.
public func findReferences(attribute: String, value: String) -> [String] {
    var results: [String] = []
    let range = NSRange(value.startIndex..<value.endIndex, in: value)

    if referencesProps.contains(attribute) {
        let matches = regReferencesUrl.matches(in: value, range: range)
        for match in matches {
            if let r = Range(match.range(at: 1), in: value) {
                results.append(String(value[r]))
            }
        }
    }

    if attribute == "href" || attribute.hasSuffix(":href") {
        if let match = regReferencesHref.firstMatch(in: value, range: range),
           let r = Range(match.range(at: 1), in: value) {
            results.append(String(value[r]))
        }
    }

    if attribute == "begin" {
        if let match = regReferencesBegin.firstMatch(in: value, range: range),
           let r = Range(match.range(at: 1), in: value) {
            results.append(String(value[r]))
        }
    }

    return results.map { $0.removingPercentEncoding ?? $0 }
}
