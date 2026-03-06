// CSSMinifier.swift
// CSS minification (CSSO-lite: whitespace removal + dead code elimination)
// okooo5km(十里)

import Foundation

// MARK: - Public API

/// Minify a CSS stylesheet string
/// - Parameters:
///   - css: The CSS string to minify
///   - usage: Optional usage data for dead code elimination
///   - restructure: Whether to enable restructuring optimizations (currently no-op)
/// - Returns: Minified CSS string
public func minifyCSS(
    _ css: String,
    usage: CSSUsageData? = nil,
    restructure: Bool = true
) -> String {
    // Tier 1: Basic compression
    var result = removeComments(css)
    result = compressWhitespace(result)

    // Tier 2: Restructure rules (shorthand merging + optional dead code elimination)
    result = restructureRules(result, usage: usage)

    return result
}

/// Minify inline style declarations (style attribute value)
public func minifyCSSBlock(_ css: String) -> String {
    let decls = parseCSSDeclarations(css)
    if decls.isEmpty { return css }

    let merged = mergeShorthands(decls)
    return merged.map { decl in
        let imp = decl.important ? "!important" : ""
        return "\(decl.name):\(decl.value)\(imp)"
    }.joined(separator: ";")
}

/// Usage data for dead code elimination
public struct CSSUsageData {
    public var tags: Set<String>?
    public var ids: Set<String>?
    public var classes: Set<String>?

    public init(tags: Set<String>? = nil, ids: Set<String>? = nil, classes: Set<String>? = nil) {
        self.tags = tags
        self.ids = ids
        self.classes = classes
    }
}

// MARK: - Tier 1: Basic Compression

/// Remove CSS comments
private func removeComments(_ css: String) -> String {
    var result = ""
    let chars = Array(css)
    var i = 0

    while i < chars.count {
        if chars[i] == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
            // Skip comment
            i += 2
            while i + 1 < chars.count {
                if chars[i] == "*" && chars[i + 1] == "/" {
                    i += 2
                    break
                }
                i += 1
            }
            if i >= chars.count { break }
        } else if chars[i] == "'" || chars[i] == "\"" {
            // Preserve strings
            let quote = chars[i]
            result.append(quote)
            i += 1
            while i < chars.count {
                if chars[i] == "\\" && i + 1 < chars.count {
                    result.append(chars[i])
                    result.append(chars[i + 1])
                    i += 2
                } else if chars[i] == quote {
                    result.append(chars[i])
                    i += 1
                    break
                } else {
                    result.append(chars[i])
                    i += 1
                }
            }
        } else {
            result.append(chars[i])
            i += 1
        }
    }

    return result
}

/// Characters around which spaces can be removed in CSS.
/// Note: ( and ) are excluded to preserve spaces in media queries like `and (min-width: ...)`.
private let cssSpaceRemovableChars: Set<Character> = [
    "{", "}", ";", ":", ",",       // structural
    "[", "]",                       // attribute selectors
    ">", "+", "~",                  // combinators
    "/",                            // for /deep/ etc.
]

/// Compress whitespace in CSS
/// Removes spaces around structural/combinator characters while preserving
/// spaces that serve as descendant combinators in selectors.
private func compressWhitespace(_ css: String) -> String {
    var result = ""
    let chars = Array(css)
    var i = 0
    var lastWasSpace = false

    while i < chars.count {
        let ch = chars[i]

        if ch == "'" || ch == "\"" {
            // Preserve strings exactly
            lastWasSpace = false
            let quote = ch
            result.append(quote)
            i += 1
            while i < chars.count {
                if chars[i] == "\\" && i + 1 < chars.count {
                    result.append(chars[i])
                    result.append(chars[i + 1])
                    i += 2
                } else if chars[i] == quote {
                    result.append(chars[i])
                    i += 1
                    break
                } else {
                    result.append(chars[i])
                    i += 1
                }
            }
            continue
        }

        if ch.isWhitespace || ch.isNewline {
            lastWasSpace = true
            i += 1
            continue
        }

        // Before appending the character, decide if we need a space
        if lastWasSpace {
            // Remove space if either adjacent character is a removable char
            let shouldRemoveSpace =
                cssSpaceRemovableChars.contains(ch) ||
                (result.last.map { cssSpaceRemovableChars.contains($0) } ?? true)

            if !shouldRemoveSpace && !result.isEmpty {
                result.append(" ")
            }
            lastWasSpace = false
        }

        // Remove trailing ';' before '}'
        if ch == "}" && result.last == ";" {
            result.removeLast()
        }

        result.append(ch)
        i += 1
    }

    return result.trimmingCharacters(in: .whitespaces)
}

// MARK: - Tier 2: Dead Code Elimination

/// Restructure CSS rules: apply shorthand merging and optionally eliminate dead rules.
private func restructureRules(_ css: String, usage: CSSUsageData?) -> String {
    let items = parseCSSStylesheet(css)
    // If no restructuring needed, return as-is
    if items.isEmpty { return css }

    var outputParts: [String] = []

    for item in items {
        switch item {
        case .rule(let rule):
            if let usage, !isRuleUsed(rule, usage: usage) { continue }
            outputParts.append(serializeRule(rule))
        case .atRule(let atRule):
            if atRule.semicolonTerminated {
                let prelude = atRule.prelude.isEmpty ? "" : " \(atRule.prelude)"
                outputParts.append("@\(atRule.name)\(prelude);")
            } else if let rawBody = atRule.rawBody {
                let minBody = minifyCSS(rawBody)
                let prelude = atRule.prelude.isEmpty ? "" : " \(atRule.prelude)"
                outputParts.append("@\(atRule.name)\(prelude){\(minBody)}")
            } else {
                let filteredRules: [CSSRule]
                if let usage {
                    filteredRules = atRule.rules.filter { isRuleUsed($0, usage: usage) }
                } else {
                    filteredRules = atRule.rules
                }
                if !filteredRules.isEmpty {
                    let inner = filteredRules.map { serializeRule($0) }.joined()
                    outputParts.append("@\(atRule.name) \(atRule.prelude){\(inner)}")
                }
            }
        }
    }

    return outputParts.joined()
}

/// Check if a CSS rule references elements that exist in the SVG
private func isRuleUsed(_ rule: CSSRule, usage: CSSUsageData) -> Bool {
    // Parse selector and check each part
    let selectorText = rule.selectorText

    // Split comma-separated selectors
    let selectors = splitSelectorList(selectorText)

    // If ANY selector matches used elements, keep the rule
    for sel in selectors {
        if isSelectorUsed(sel.trimmingCharacters(in: .whitespaces), usage: usage) {
            return true
        }
    }
    return false
}

/// Split a selector list on commas (respecting parentheses)
private func splitSelectorList(_ text: String) -> [String] {
    var parts: [String] = []
    var current = ""
    var depth = 0

    for ch in text {
        if ch == "(" { depth += 1 }
        else if ch == ")" { depth -= 1 }

        if ch == "," && depth == 0 {
            parts.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }
    if !current.isEmpty {
        parts.append(current)
    }
    return parts
}

/// Check if a single selector references used elements
private func isSelectorUsed(_ selector: String, usage: CSSUsageData) -> Bool {
    // Check IDs
    if let ids = usage.ids {
        let idPattern = try! NSRegularExpression(pattern: #"#([a-zA-Z][a-zA-Z0-9_-]*)"#)
        let nsStr = selector as NSString
        let idMatches = idPattern.matches(in: selector, range: NSRange(location: 0, length: nsStr.length))
        for match in idMatches {
            if let range = Range(match.range(at: 1), in: selector) {
                let id = String(selector[range])
                if !ids.contains(id) { return false }
            }
        }
    }

    // Check classes
    if let classes = usage.classes {
        let classPattern = try! NSRegularExpression(pattern: #"\.([a-zA-Z_][a-zA-Z0-9_-]*)"#)
        let nsStr = selector as NSString
        let classMatches = classPattern.matches(in: selector, range: NSRange(location: 0, length: nsStr.length))
        for match in classMatches {
            if let range = Range(match.range(at: 1), in: selector) {
                let cls = String(selector[range])
                if !classes.contains(cls) { return false }
            }
        }
    }

    // Check tag names
    if let tags = usage.tags {
        // Extract tag selectors (letters at start of selector or after combinator)
        let tagPattern = try! NSRegularExpression(pattern: #"(?:^|[\s>+~])([a-zA-Z][a-zA-Z0-9]*)"#)
        let nsStr = selector as NSString
        let tagMatches = tagPattern.matches(in: selector, range: NSRange(location: 0, length: nsStr.length))
        for match in tagMatches {
            if let range = Range(match.range(at: 1), in: selector) {
                let tag = String(selector[range])
                if !tags.contains(tag) { return false }
            }
        }
    }

    return true
}

/// Serialize a CSS rule back to string (minified)
private func serializeRule(_ rule: CSSRule) -> String {
    let merged = mergeShorthands(rule.declarations)
    let decls = merged.map { decl in
        let imp = decl.important ? "!important" : ""
        return "\(decl.name):\(decl.value)\(imp)"
    }.joined(separator: ";")
    return "\(rule.selectorText){\(decls)}"
}

// MARK: - Shorthand Merging

/// Shorthand property groups: maps shorthand name to its longhand sides (top, right, bottom, left)
private let shorthandGroups: [(shorthand: String, longhands: [String])] = [
    ("padding", ["padding-top", "padding-right", "padding-bottom", "padding-left"]),
    ("margin", ["margin-top", "margin-right", "margin-bottom", "margin-left"]),
]

/// Merge longhand properties into shorthand when all sides have the same value and importance.
/// e.g. padding-top:1em;padding-right:1em;padding-bottom:1em;padding-left:1em → padding:1em
private func mergeShorthands(_ declarations: [CSSDeclaration]) -> [CSSDeclaration] {
    var result = declarations

    for group in shorthandGroups {
        // Find all four longhands
        let found = group.longhands.compactMap { name in
            result.first { $0.name == name }
        }
        guard found.count == group.longhands.count else { continue }

        // All must have same value and same importance
        let firstValue = found[0].value
        let firstImportant = found[0].important
        guard found.allSatisfy({ $0.value == firstValue && $0.important == firstImportant }) else {
            continue
        }

        // Replace: insert shorthand at the position of the first longhand, remove all longhands
        let firstIndex = result.firstIndex { $0.name == group.longhands[0] }!
        let shorthandDecl = CSSDeclaration(
            name: group.shorthand,
            value: firstValue,
            important: firstImportant
        )

        // Remove all longhands
        result.removeAll { group.longhands.contains($0.name) }
        // Insert shorthand at the original position (clamped)
        let insertAt = min(firstIndex, result.endIndex)
        result.insert(shorthandDecl, at: insertAt)
    }

    return result
}
