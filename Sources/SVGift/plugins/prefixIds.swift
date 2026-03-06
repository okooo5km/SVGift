// prefixIds.swift
// Plugin to prefix IDs and class names in SVG elements and stylesheets
// okooo5km(十里)

import Foundation

/// Extract the basename (filename) from a file path.
private func getBasename(_ path: String) -> String {
    let pattern = try! NSRegularExpression(pattern: #"[/\\]?([^/\\]+)$"#)
    let range = NSRange(path.startIndex..<path.endIndex, in: path)
    if let match = pattern.firstMatch(in: path, range: range),
       let r = Range(match.range(at: 1), in: path)
    {
        return String(path[r])
    }
    return ""
}

/// Escape a string for use as an identifier (replace dots and spaces with underscores).
private func escapeIdentifierName(_ str: String) -> String {
    return str.replacingOccurrences(of: ".", with: "_")
        .replacingOccurrences(of: " ", with: "_")
}

/// Prefix the given string, unless it already starts with the generated prefix.
private func prefixId(_ body: String, prefix: String) -> String {
    if body.hasPrefix(prefix) {
        return body
    }
    return prefix + body
}

/// Insert prefix in a reference string (e.g., #id -> #prefix__id).
/// Returns nil if the string doesn't start with "#".
private func prefixReference(_ reference: String, prefix: String) -> String? {
    if reference.hasPrefix("#") {
        return "#" + prefixId(String(reference.dropFirst()), prefix: prefix)
    }
    return nil
}

/// Generate a prefix string based on params and plugin info.
private func generatePrefix(
    prefixParam: String?,
    delim: String,
    info: PluginInfo
) -> String {
    // If an explicit string prefix is provided, use it
    if let prefixParam = prefixParam, !prefixParam.isEmpty,
       prefixParam != "true", prefixParam != "false"
    {
        return prefixParam + delim
    }

    // If prefix is explicitly false, return empty prefix
    if prefixParam == "false" {
        return ""
    }

    // Derive from file path
    if let path = info.path, !path.isEmpty {
        return escapeIdentifierName(getBasename(path)) + delim
    }

    return "prefix" + delim
}

// MARK: - CSS Text Prefixing

/// Regex for matching #id selectors in CSS text.
private let regCSSIdSelector = try! NSRegularExpression(
    pattern: #"#([a-zA-Z][\w-]*|\\[0-9a-fA-F]+ [\w-]*)"#
)

/// Regex for matching .class selectors in CSS text.
private let regCSSClassSelector = try! NSRegularExpression(
    pattern: #"\.([a-zA-Z_][\w-]*)"#
)

/// Regex for matching url(#...) in CSS text.
private let regCSSUrl = try! NSRegularExpression(
    pattern: #"url\(["']?(#[^)'"]+)["']?\)"#
)

/// Prefix IDs, class names, and url() references in CSS text.
private func prefixCSSText(
    _ css: String,
    prefix: String,
    doPrefixIds: Bool,
    doPrefixClassNames: Bool
) -> String {
    var result = css

    // Prefix url() references (do this first to avoid double-prefixing)
    if doPrefixIds {
        let nsResult = result as NSString
        let urlMatches = regCSSUrl.matches(
            in: result,
            range: NSRange(location: 0, length: nsResult.length)
        )
        // Process matches in reverse to preserve ranges
        for match in urlMatches.reversed() {
            guard let fullMatchRange = Range(match.range(at: 0), in: result),
                  let refRange = Range(match.range(at: 1), in: result) else { continue }
            let ref = String(result[refRange])
            if let prefixed = prefixReference(ref, prefix: prefix) {
                // Replace entire url(...) match with unquoted version (matches csstree.generate behavior)
                result = result.replacingCharacters(in: fullMatchRange, with: "url(\(prefixed))")
            }
        }
    }

    // Prefix #id selectors
    if doPrefixIds {
        let nsResult = result as NSString
        let idMatches = regCSSIdSelector.matches(
            in: result,
            range: NSRange(location: 0, length: nsResult.length)
        )
        // Process in reverse to preserve ranges
        for match in idMatches.reversed() {
            // Check this is not inside a url()
            let fullRange = match.range(at: 0)
            let beforeStart = max(0, fullRange.location - 4)
            let beforeLen = fullRange.location - beforeStart
            let beforeRange = NSRange(location: beforeStart, length: beforeLen)
            let beforeText = nsResult.substring(with: beforeRange)
            if beforeText.contains("url(") || beforeText.hasSuffix("#") { continue }
            // Actually just check if preceding chars form url(
            // Simpler: skip if preceded by url( context (already handled above)
            let checkStart = max(0, fullRange.location - 5)
            let checkText = nsResult.substring(
                with: NSRange(location: checkStart, length: fullRange.location - checkStart)
            )
            if checkText.range(of: "url(", options: .caseInsensitive) != nil { continue }

            guard let nameRange = Range(match.range(at: 1), in: result) else { continue }
            let name = String(result[nameRange])
            let prefixed = prefixId(name, prefix: prefix)
            result = result.replacingCharacters(in: nameRange, with: prefixed)
        }
    }

    // Prefix .class selectors
    if doPrefixClassNames {
        let nsResult = result as NSString
        let classMatches = regCSSClassSelector.matches(
            in: result,
            range: NSRange(location: 0, length: nsResult.length)
        )
        for match in classMatches.reversed() {
            // Skip if inside a declaration value (very rough heuristic:
            // check if preceded by ':' which would indicate a property value)
            // Actually class selectors appear in selector context, not values.
            // But need to skip false positives like "0.5" - our regex requires
            // letter/underscore after dot, so this is safe.
            guard let nameRange = Range(match.range(at: 1), in: result) else { continue }
            let name = String(result[nameRange])
            let prefixed = prefixId(name, prefix: prefix)
            result = result.replacingCharacters(in: nameRange, with: prefixed)
        }
    }

    return result
}

/// Regex for matching url() in attribute values.
private let regAttrUrl = try! NSRegularExpression(
    pattern: #"\burl\((["']?)(#.+?)\1\)"#,
    options: .caseInsensitive
)

/// Prefix identifiers in SVG elements.
///
/// Adds a prefix to `id` and `class` attributes, as well as references
/// to them in `href`, `xlink:href`, `url()` references, CSS selectors,
/// and `begin`/`end` animation timing attributes.
///
/// Parameters:
/// - `prefix`: String prefix to use. If omitted, derived from the
///   filename (info.path). Set to `"false"` to disable prefixing.
/// - `delim`: Delimiter between prefix and original value. Default: `"__"`.
/// - `prefixIds`: `"true"` (default) to prefix `id` attributes and
///   ID selectors/references.
/// - `prefixClassNames`: `"true"` (default) to prefix `class` attributes
///   and class selectors.
public func makePrefixIdsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "prefixIds") { _, params, info in
        let delim = params["delim"] ?? "__"
        let doPrefixIds = params["prefixIds"] != "false"
        let doPrefixClassNames = params["prefixClassNames"] != "false"

        let prefix = generatePrefix(
            prefixParam: params["prefix"],
            delim: delim,
            info: info
        )

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    // Handle <style> elements: prefix selectors and url() in CSS
                    if node.name == "style" {
                        guard !node.children.isEmpty else { return .continue }

                        for child in node.children {
                            switch child {
                            case .text(let textNode):
                                let minified = minifyCSS(textNode.value)
                                textNode.value = prefixCSSText(
                                    minified,
                                    prefix: prefix,
                                    doPrefixIds: doPrefixIds,
                                    doPrefixClassNames: doPrefixClassNames
                                )
                            case .cdata(let cdataNode):
                                let minified = minifyCSS(cdataNode.value)
                                cdataNode.value = prefixCSSText(
                                    minified,
                                    prefix: prefix,
                                    doPrefixIds: doPrefixIds,
                                    doPrefixClassNames: doPrefixClassNames
                                )
                            default:
                                break
                            }
                        }
                    }

                    // Prefix id attribute
                    if doPrefixIds,
                       let idVal = node.attributes["id"],
                       !idVal.isEmpty
                    {
                        node.attributes["id"] = prefixId(idVal, prefix: prefix)
                    }

                    // Prefix class attribute
                    if doPrefixClassNames,
                       let classVal = node.attributes["class"],
                       !classVal.isEmpty
                    {
                        let classes = classVal.split(
                            separator: " ",
                            omittingEmptySubsequences: true
                        ).map { prefixId(String($0), prefix: prefix) }
                        node.attributes["class"] = classes.joined(separator: " ")
                    }

                    // Prefix href and xlink:href
                    for attrName in ["href", "xlink:href"] {
                        if let val = node.attributes[attrName], !val.isEmpty {
                            if let prefixed = prefixReference(val, prefix: prefix) {
                                node.attributes[attrName] = prefixed
                            }
                        }
                    }

                    // Prefix url() in reference attributes
                    for attrName in referencesProps {
                        guard let val = node.attributes[attrName], !val.isEmpty else { continue }
                        let nsVal = val as NSString
                        let matches = regAttrUrl.matches(
                            in: val,
                            range: NSRange(location: 0, length: nsVal.length)
                        )
                        guard !matches.isEmpty else { continue }

                        var newVal = val
                        for match in matches.reversed() {
                            guard let urlRange = Range(match.range(at: 2), in: newVal) else { continue }
                            let url = String(newVal[urlRange])
                            if let prefixed = prefixReference(url, prefix: prefix) {
                                newVal = newVal.replacingCharacters(in: urlRange, with: prefixed)
                            }
                        }
                        node.attributes[attrName] = newVal
                    }

                    // Prefix url() in style attribute
                    if doPrefixIds,
                       let styleVal = node.attributes["style"],
                       styleVal.contains("url(")
                    {
                        let nsStyle = styleVal as NSString
                        let matches = regAttrUrl.matches(
                            in: styleVal,
                            range: NSRange(location: 0, length: nsStyle.length)
                        )
                        if !matches.isEmpty {
                            var newStyle = styleVal
                            for match in matches.reversed() {
                                guard let urlRange = Range(match.range(at: 2), in: newStyle) else { continue }
                                let url = String(newStyle[urlRange])
                                if let prefixed = prefixReference(url, prefix: prefix) {
                                    newStyle = newStyle.replacingCharacters(in: urlRange, with: prefixed)
                                }
                            }
                            node.attributes["style"] = newStyle
                        }
                    }

                    // Prefix begin/end animation timing references
                    if doPrefixIds {
                        for attrName in ["begin", "end"] {
                            guard let val = node.attributes[attrName], !val.isEmpty else { continue }
                            let parts = val.split(separator: ";").map { part -> String in
                                let trimmed = part.trimmingCharacters(in: .whitespaces)
                                if trimmed.hasSuffix(".end") || trimmed.hasSuffix(".start") {
                                    let dotIndex = trimmed.lastIndex(of: ".") ?? trimmed.endIndex
                                    let id = String(trimmed[trimmed.startIndex..<dotIndex])
                                    let postfix = String(trimmed[dotIndex...])
                                    return prefixId(id, prefix: prefix) + postfix
                                }
                                return trimmed
                            }
                            node.attributes[attrName] = parts.joined(separator: "; ")
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
