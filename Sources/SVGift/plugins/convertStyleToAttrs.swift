// convertStyleToAttrs.swift
// Plugin to convert style attributes to presentation attributes
// okooo5km(十里)

import Foundation

// MARK: - Regex Patterns (matching SVGO's convertStyleToAttrs.js)

private let rEscape = #"\\(?:[0-9a-f]{1,6}\s?|\r\n|.)"#

private func g(_ args: String...) -> String {
    "(?:" + args.joined(separator: "|") + ")"
}

private let rAttr = "\\s*(" + g("[^:;\\\\]", rEscape) + "*?)\\s*"
private let rSingleQuotes = "'(?:[^'\\n\\r\\\\]|" + rEscape + ")*?(?:'|$)"
private let rQuotes = "\"(?:[^\"\\n\\r\\\\]|" + rEscape + ")*?(?:\"|$)"
private let rQuotedStringPattern = "^" + g(rSingleQuotes, rQuotes) + "$"
private let rParenthesis = "\\(" + g("[^'\"()\\\\]+", rEscape, rSingleQuotes, rQuotes) + "*?" + "\\)"
private let rValue = "\\s*(" + g("[^!'\"();\\\\]+?", rEscape, rSingleQuotes, rQuotes, rParenthesis, "[^;]*?") + "*?)"
private let rDeclEnd = "\\s*(?:;\\s*|$)"
private let rImportant = "(\\s*!important(?![-(\\w]))?"

private let regDeclarationBlock = try! NSRegularExpression(
    pattern: rAttr + ":" + rValue + rImportant + rDeclEnd,
    options: .caseInsensitive
)

private let regQuotedString = try! NSRegularExpression(pattern: rQuotedStringPattern)

/// Convert style attribute declarations to presentation attributes.
///
/// Parameters:
/// - `keepImportant`: If `"true"`, declarations with `!important` are kept
///   in the style attribute instead of being converted. Default: `"false"`.
public func makeConvertStyleToAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertStyleToAttrs") { _, params, _ in
        let keepImportant = params["keepImportant"] == "true"

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard let styleValue = node.attributes["style"] else {
                        return .continue
                    }

                    // Strip CSS comments
                    let cleanedStyle = stripCSSComments(styleValue)

                    // Parse declarations using regex
                    var styles: [(prop: String, value: String)] = []

                    let nsClean = cleanedStyle as NSString
                    let matches = regDeclarationBlock.matches(
                        in: cleanedStyle,
                        range: NSRange(location: 0, length: nsClean.length)
                    )

                    for match in matches {
                        guard match.numberOfRanges >= 3,
                              let propRange = Range(match.range(at: 1), in: cleanedStyle),
                              let valueRange = Range(match.range(at: 2), in: cleanedStyle)
                        else { continue }

                        let prop = String(cleanedStyle[propRange])
                        let value = String(cleanedStyle[valueRange])

                        // Check !important
                        let hasImportant: Bool
                        if match.numberOfRanges >= 4 {
                            let impRange = match.range(at: 3)
                            hasImportant = impRange.location != NSNotFound && impRange.length > 0
                        } else {
                            hasImportant = false
                        }

                        if !keepImportant || !hasImportant {
                            styles.append((prop: prop, value: value))
                        }
                    }

                    guard !styles.isEmpty else { return .continue }

                    // Filter: move presentation attrs to XML attributes
                    var remaining: [(prop: String, value: String)] = []

                    for style in styles {
                        let propLower = style.prop.lowercased()
                        var val = style.value

                        // Remove surrounding quotes if the value is a quoted string
                        let nsVal = val as NSString
                        if regQuotedString.firstMatch(
                            in: val,
                            range: NSRange(location: 0, length: nsVal.length)
                        ) != nil {
                            val = String(val.dropFirst().dropLast())
                        }

                        if presentationAttrs.contains(propLower) {
                            node.attributes[propLower] = val
                        } else {
                            remaining.append(style)
                        }
                    }

                    if remaining.isEmpty {
                        node.attributes.removeValue(forKey: "style")
                    } else {
                        node.attributes["style"] = remaining
                            .map { "\($0.prop):\($0.value)" }
                            .joined(separator: ";")
                    }

                    return .continue
                }
            )
        )
    }
}

/// Strip CSS comments while preserving escape sequences and strings
private func stripCSSComments(_ css: String) -> String {
    var result = ""
    let chars = Array(css)
    var i = 0

    while i < chars.count {
        if chars[i] == "\\" && i + 1 < chars.count {
            let next = chars[i + 1]
            if next.isLetter && "ghijklmnopqrstuvwxyz".contains(next.lowercased()) {
                result.append(next)
            } else {
                result.append(chars[i])
                result.append(next)
            }
            i += 2
            continue
        }

        if chars[i] == "'" || chars[i] == "\"" {
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
            continue
        }

        if chars[i] == "/" && i + 1 < chars.count && chars[i + 1] == "*" {
            i += 2
            while i + 1 < chars.count {
                if chars[i] == "*" && chars[i + 1] == "/" {
                    i += 2
                    break
                }
                i += 1
            }
            if i >= chars.count { break }
            continue
        }

        result.append(chars[i])
        i += 1
    }

    return result
}
