// inlineStyles.swift
// Plugin to inline styles from <style> elements into style attributes
// okooo5km(十里)

import Foundation

/// Inline styles from `<style>` elements into matching elements' `style` attributes.
///
/// Parameters:
/// - `onlyMatchedOnce`: Only inline selectors that match exactly one element (default: `"true"`)
/// - `removeMatchedSelectors`: Remove inlined selectors from `<style>` (default: `"true"`)
/// - `useMqs`: JSON array of media queries to process (default: `["","screen"]`)
/// - `usePseudos`: JSON array of pseudo selectors to process (default: `[""]`)
public func makeInlineStylesPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "inlineStyles") { _, params, _ in
        let onlyMatchedOnce = params["onlyMatchedOnce"] != "false"
        let removeMatchedSelectors = params["removeMatchedSelectors"] != "false"

        let useMqs: Set<String>
        if let mqsJSON = params["useMqs"],
           let data = mqsJSON.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            // Normalize whitespace in user-provided MQ strings
            useMqs = Set(arr.map { normalizeMQWhitespace($0) })
        } else {
            useMqs = ["", "screen"]
        }

        let usePseudos: Set<String>
        if let pseudosJSON = params["usePseudos"],
           let data = pseudosJSON.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            usePseudos = Set(arr)
        } else {
            usePseudos = [""]
        }

        // State collected during element enter
        var styleElements: [(element: XastElement, parent: XastParent, cssText: String, items: [CSSItem])] = []
        var allSelectors: [ISelectorInfo] = []

        return Visitor(
            root: VisitorCallbacks<XastRoot>(
                exit: { root, _ in
                    guard !styleElements.isEmpty else { return }
                    inlineStylesProcess(
                        root: root,
                        styleElements: &styleElements,
                        allSelectors: &allSelectors,
                        onlyMatchedOnce: onlyMatchedOnce,
                        removeMatchedSelectors: removeMatchedSelectors
                    )
                }
            ),
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    if node.name == "foreignObject" { return .skip }

                    guard node.name == "style", !node.children.isEmpty else {
                        return .continue
                    }

                    if let type = node.attributes["type"],
                       !type.isEmpty,
                       type != "text/css" {
                        return .continue
                    }

                    let cssText = node.children.compactMap { child -> String? in
                        switch child {
                        case .text(let t): return t.value
                        case .cdata(let c): return c.value
                        default: return nil
                        }
                    }.joined()

                    let items = parseCSSStylesheet(cssText)
                    let styleIndex = styleElements.count
                    styleElements.append((element: node, parent: parentNode, cssText: cssText, items: items))

                    // Collect selectors from rules
                    for (itemIdx, item) in items.enumerated() {
                        switch item {
                        case .rule(let rule):
                            collectISelectors(
                                rule: rule, mediaQuery: "",
                                useMqs: useMqs, usePseudos: usePseudos,
                                styleIndex: styleIndex, itemIndex: itemIdx,
                                selectorListText: rule.selectorText,
                                infos: &allSelectors
                            )
                        case .atRule(let atRule):
                            guard !atRule.rules.isEmpty else { continue }
                            // Normalize whitespace in media query for useMqs matching
                            let rawMq = "\(atRule.name) \(atRule.prelude)"
                            let mq = normalizeMQWhitespace(rawMq)
                            for (ruleIdx, innerRule) in atRule.rules.enumerated() {
                                collectISelectors(
                                    rule: innerRule, mediaQuery: mq,
                                    useMqs: useMqs, usePseudos: usePseudos,
                                    styleIndex: styleIndex, itemIndex: itemIdx,
                                    selectorListText: innerRule.selectorText,
                                    infos: &allSelectors,
                                    innerRuleIndex: ruleIdx
                                )
                            }
                        }
                    }

                    return .continue
                }
            )
        )
    }
}

// MARK: - Internal Types

private struct ISelectorInfo {
    let selectorText: String            // The single selector text (no commas)
    let parsedSelector: ComplexSelector
    let declarations: [CSSDeclaration]
    let specificity: Specificity
    let styleIndex: Int                 // Which <style> element
    let itemIndex: Int                  // Which CSSItem in that style
    let originalSelectorListText: String // Full comma-separated selector text
    let innerRuleIndex: Int?            // For rules inside @atRule
    var matchedElements: [XastElement]?
    var wasInlined: Bool
}

// MARK: - Selector Collection

private func collectISelectors(
    rule: CSSRule,
    mediaQuery: String,
    useMqs: Set<String>,
    usePseudos: Set<String>,
    styleIndex: Int,
    itemIndex: Int,
    selectorListText: String,
    infos: inout [ISelectorInfo],
    innerRuleIndex: Int? = nil
) {
    if !useMqs.contains(mediaQuery) { return }

    guard let selectorList = try? parseSelector(rule.selectorText) else { return }

    for selector in selectorList.selectors {
        // Extract non-preserved pseudo selectors
        var pseudoParts: [String] = []
        for segment in selector.segments {
            for component in segment.compound.components {
                if case .pseudoClass(let name, _) = component {
                    if !PseudoClassCategories.preserved.contains(name) {
                        pseudoParts.append(":\(name)")
                    }
                }
            }
        }

        let pseudoSelector = pseudoParts.joined()
        if !usePseudos.contains(pseudoSelector) { return }

        let spec = computeSpecificity(selector)
        // Generate selector text without dynamic pseudo-classes
        let selectorText = generateISelectorText(selector)

        infos.append(ISelectorInfo(
            selectorText: selectorText,
            parsedSelector: selector,
            declarations: rule.declarations,
            specificity: spec,
            styleIndex: styleIndex,
            itemIndex: itemIndex,
            originalSelectorListText: selectorListText,
            innerRuleIndex: innerRuleIndex,
            matchedElements: nil,
            wasInlined: false
        ))
    }
}

// MARK: - Main Processing

private func inlineStylesProcess(
    root: XastRoot,
    styleElements: inout [(element: XastElement, parent: XastParent, cssText: String, items: [CSSItem])],
    allSelectors: inout [ISelectorInfo],
    onlyMatchedOnce: Bool,
    removeMatchedSelectors: Bool
) {
    let parentMap = buildParentMap(root)

    // Sort by specificity descending; tiebreak by source order descending
    // (later source = processed first, so its declarations get overridden by earlier ones)
    let sortedIndices = allSelectors.indices.sorted { a, b in
        let cmp = compareSpecificity(allSelectors[a].specificity, allSelectors[b].specificity)
        if cmp != 0 { return cmp > 0 }
        return a > b
    }

    for idx in sortedIndices {
        let info = allSelectors[idx]

        let matchedElements: [XastElement]
        do {
            matchedElements = try querySelectorAll(
                root, selectorText: info.selectorText, parentMap: parentMap
            )
        } catch {
            continue
        }

        allSelectors[idx].matchedElements = matchedElements

        if matchedElements.isEmpty { continue }

        if onlyMatchedOnce && matchedElements.count > 1 {
            continue
        }

        // Apply declarations to matched elements
        for element in matchedElements {
            let existingStyle = element.attributes["style"] ?? ""
            var existingDecls = parseCSSDeclarations(existingStyle)

            var existingMap: [String: (index: Int, important: Bool)] = [:]
            for (i, decl) in existingDecls.enumerated() {
                existingMap[decl.name] = (index: i, important: decl.important)
            }

            var insertPos = 0
            for ruleDecl in info.declarations {
                let property = ruleDecl.name

                // Check if this property is used as an attribute selector in any other rule
                let isUsedInSelector = allSelectors.contains { other in
                    selectorIncludesAttrRef(other.parsedSelector, attrName: property)
                }

                // Remove matching presentation attribute ONLY if not used in selectors
                if presentationAttrs.contains(property) && !isUsedInSelector {
                    element.attributes.removeValue(forKey: property)
                }

                if let existing = existingMap[property] {
                    // Rule only overrides if it's !important and inline is not
                    if !existing.important && ruleDecl.important {
                        existingDecls[existing.index] = ruleDecl
                        existingMap[property] = (index: existing.index, important: ruleDecl.important)
                    }
                } else {
                    // Insert rule declarations before inline, preserving source order
                    existingDecls.insert(ruleDecl, at: insertPos)
                    insertPos += 1
                    existingMap.removeAll()
                    for (i, d) in existingDecls.enumerated() {
                        existingMap[d.name] = (index: i, important: d.important)
                    }
                }
            }

            let newStyle = serializeCSSDeclarations(existingDecls)
            if newStyle.isEmpty {
                element.attributes.removeValue(forKey: "style")
            } else {
                element.attributes["style"] = newStyle
            }
        }

        allSelectors[idx].wasInlined = true
    }

    guard removeMatchedSelectors else { return }

    // Clean up class/ID attributes on matched elements
    for idx in sortedIndices {
        let info = allSelectors[idx]
        guard info.wasInlined, let matchedElements = info.matchedElements else { continue }

        guard let compound = info.parsedSelector.segments.last?.compound else { continue }

        for element in matchedElements {
            for component in compound.components {
                switch component {
                case .className(let name):
                    // Only remove class if no other non-inlined selector references it
                    let classStillNeeded = allSelectors.contains { other in
                        if other.wasInlined { return false }
                        return selectorReferencesClassAnywhere(other.parsedSelector, className: name)
                    }
                    if !classStillNeeded {
                        iRemoveClassFromElement(element, className: name)
                    }

                case .id(let idName):
                    if element.attributes["id"] == idName {
                        let idStillNeeded = allSelectors.contains { other in
                            if other.wasInlined { return false }
                            return selectorReferencesIdAnywhere(other.parsedSelector, id: idName)
                        }
                        if !idStillNeeded {
                            element.attributes.removeValue(forKey: "id")
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    // Rebuild style elements, removing inlined selectors
    for (styleIdx, style) in styleElements.enumerated() {
        var newParts: [String] = []

        for (itemIdx, item) in style.items.enumerated() {
            switch item {
            case .rule(let rule):
                // Check which individual selectors were inlined
                let remainingSelectors = getRemainingSelectors(
                    rule: rule, styleIndex: styleIdx, itemIndex: itemIdx,
                    allSelectors: allSelectors, innerRuleIndex: nil
                )
                if let remaining = remainingSelectors {
                    newParts.append(remaining)
                }

            case .atRule(let atRule):
                if atRule.rules.isEmpty {
                    // Non-rule @-rules (charset, import, font-face, keyframes, etc.)
                    // Preserve as-is (already minified by serializeAtRuleRaw)
                    newParts.append(serializeAtRuleRaw(atRule))
                } else {
                    var innerParts: [String] = []
                    for (ruleIdx, innerRule) in atRule.rules.enumerated() {
                        let remaining = getRemainingSelectors(
                            rule: innerRule, styleIndex: styleIdx, itemIndex: itemIdx,
                            allSelectors: allSelectors, innerRuleIndex: ruleIdx
                        )
                        if let remaining = remaining {
                            innerParts.append(remaining)
                        }
                    }
                    // Keep @-rule even if inner rules are empty (produces empty block)
                    let prelude = removeUrlQuotes(minifySelectorCSS(atRule.prelude))
                    newParts.append("@\(atRule.name) \(prelude){\(innerParts.joined())}")
                }
            }
        }

        let newCSS = newParts.joined()
        if newCSS.isEmpty {
            detachNodeFromParent(.element(style.element), from: style.parent)
        } else {
            if let firstChild = style.element.children.first {
                switch firstChild {
                case .text(let t): t.value = newCSS
                case .cdata(let c): c.value = newCSS
                default:
                    style.element.children = [.text(XastText(value: newCSS))]
                }
            }
        }
    }
}

/// Determine remaining (non-inlined) selectors for a rule and return serialized rule,
/// or nil if all selectors were inlined.
private func getRemainingSelectors(
    rule: CSSRule,
    styleIndex: Int,
    itemIndex: Int,
    allSelectors: [ISelectorInfo],
    innerRuleIndex: Int?
) -> String? {
    // Find all selector infos for this rule
    let ruleSelectors = allSelectors.filter {
        $0.styleIndex == styleIndex &&
        $0.itemIndex == itemIndex &&
        $0.innerRuleIndex == innerRuleIndex
    }

    // If no selectors were collected for this rule (e.g., unsupported at-rule), keep as-is
    if ruleSelectors.isEmpty {
        return serializeIRule(rule)
    }

    // Check which individual selectors were NOT inlined
    let remainingTexts = ruleSelectors.filter { !$0.wasInlined }.map { $0.selectorText }

    if remainingTexts.isEmpty {
        return nil  // All selectors inlined, remove entire rule
    }

    if remainingTexts.count == ruleSelectors.count {
        // Nothing was inlined, keep original
        return serializeIRule(rule)
    }

    // Some selectors remain: rebuild with remaining selectors
    let newSelector = remainingTexts.joined(separator: ",")
    let newRule = CSSRule(selectorText: newSelector, declarations: rule.declarations)
    return serializeIRule(newRule)
}

// MARK: - Helpers

private func generateISelectorText(_ selector: ComplexSelector) -> String {
    var parts: [String] = []

    for (i, segment) in selector.segments.enumerated() {
        var compoundStr = ""
        for component in segment.compound.components {
            if case .pseudoClass(let name, _) = component {
                if !PseudoClassCategories.preserved.contains(name) {
                    continue
                }
            }
            compoundStr += iComponentToStr(component)
        }
        parts.append(compoundStr)

        if i < selector.segments.count - 1, let combinator = segment.combinator {
            switch combinator {
            case .descendant: parts.append(" ")
            case .child: parts.append(" > ")
            case .adjacentSibling: parts.append(" + ")
            case .generalSibling: parts.append(" ~ ")
            }
        }
    }

    return parts.joined()
}

private func iComponentToStr(_ component: SimpleSelectorComponent) -> String {
    switch component {
    case .type(let name): return name
    case .universal: return "*"
    case .id(let id): return "#\(id)"
    case .className(let cls): return ".\(cls)"
    case .attribute(let name, let op, let value):
        if let op = op, let value = value {
            return "[\(name)\(op.rawValue)'\(value)']"
        }
        return "[\(name)]"
    case .pseudoClass(let name, let arg):
        if let arg = arg { return ":\(name)(\(arg))" }
        return ":\(name)"
    case .pseudoElement(let name): return "::\(name)"
    }
}

private func serializeIRule(_ rule: CSSRule) -> String {
    let decls = rule.declarations.map { decl in
        let imp = decl.important ? "!important" : ""
        return "\(decl.name):\(decl.value)\(imp)"
    }.joined(separator: ";")
    let selector = minifySelectorCSS(rule.selectorText)
    return "\(selector){\(decls)}"
}

/// Serialize a non-rule @-rule (charset, import, font-face, keyframes, etc.) to minified CSS
private func serializeAtRuleRaw(_ atRule: CSSAtRule) -> String {
    if let rawBody = atRule.rawBody {
        let minBody: String
        if rawBody.contains("{") {
            // Nested blocks (e.g. @keyframes) — use full CSS minifier
            var compressed = minifyCSS(rawBody)
            while compressed.hasSuffix(";") { compressed.removeLast() }
            minBody = compressed
        } else {
            // Declarations only (e.g. @font-face, @viewport, @page) — parse and serialize
            // to preserve value content (e.g. spaces after commas in function args)
            let decls = parseCSSDeclarations(rawBody)
            minBody = serializeCSSDeclarations(decls)
        }
        let prelude = atRule.prelude.isEmpty ? "" : " \(minifySelectorCSS(atRule.prelude))"
        return "@\(atRule.name)\(prelude){\(minBody)}"
    } else if atRule.semicolonTerminated {
        // Normalize single quotes to double quotes, remove quotes from url() (matches CSSO)
        var normalizedPrelude = atRule.prelude.replacingOccurrences(of: "'", with: "\"")
        normalizedPrelude = removeUrlQuotes(normalizedPrelude)
        let prelude = normalizedPrelude.isEmpty ? "" : " \(normalizedPrelude)"
        return "@\(atRule.name)\(prelude);"
    } else {
        var prelude = minifySelectorCSS(atRule.prelude)
        prelude = removeUrlQuotes(prelude)
        return "@\(atRule.name) \(prelude){}"
    }
}

/// Remove unnecessary quotes from url() expressions.
/// e.g. url("http://example.com") → url(http://example.com)
/// Only removes when the URL content doesn't contain characters requiring quotes.
private func removeUrlQuotes(_ text: String) -> String {
    let pattern = try! NSRegularExpression(pattern: #"url\(["']([^"'()\s]*)["']\)"#)
    let nsStr = text as NSString
    let range = NSRange(location: 0, length: nsStr.length)
    return pattern.stringByReplacingMatches(in: text, range: range, withTemplate: "url($1)")
}

/// Remove unnecessary whitespace from CSS selector/prelude text.
/// Removes spaces around structural characters while preserving
/// spaces that serve as descendant combinators.
private func minifySelectorCSS(_ text: String) -> String {
    let spaceRemovable: Set<Character> = [
        "{", "}", ";", ":", ",", "[", "]", ">", "+", "~", "/",
    ]
    var result = ""
    let chars = Array(text)
    var i = 0
    var lastWasSpace = false

    while i < chars.count {
        let ch = chars[i]

        // Preserve quoted strings
        if ch == "'" || ch == "\"" {
            lastWasSpace = false
            result.append(ch)
            i += 1
            while i < chars.count && chars[i] != ch {
                if chars[i] == "\\" && i + 1 < chars.count {
                    result.append(chars[i])
                    i += 1
                }
                result.append(chars[i])
                i += 1
            }
            if i < chars.count { result.append(chars[i]); i += 1 }
            continue
        }

        if ch.isWhitespace || ch.isNewline {
            lastWasSpace = true
            i += 1
            continue
        }

        if lastWasSpace && !result.isEmpty {
            let shouldRemove =
                spaceRemovable.contains(ch) ||
                (result.last.map { spaceRemovable.contains($0) } ?? true)
            if !shouldRemove {
                result.append(" ")
            }
            lastWasSpace = false
        }

        result.append(ch)
        i += 1
    }
    return result
}

/// Normalize media query whitespace: collapse runs of whitespace to single space,
/// and remove spaces around ':' (to match minified MQ format)
private func normalizeMQWhitespace(_ text: String) -> String {
    let collapsed = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        .joined(separator: " ")
    // Remove spaces around ':'
    var result = ""
    let chars = Array(collapsed)
    var i = 0
    while i < chars.count {
        if chars[i] == " " && i + 1 < chars.count && chars[i + 1] == ":" {
            i += 1 // skip space before ':'
        } else if chars[i] == ":" && i + 1 < chars.count && chars[i + 1] == " " {
            result.append(":")
            i += 2 // skip ':' and space after
        } else {
            result.append(chars[i])
            i += 1
        }
    }
    return result
}

/// Check if a selector references an attribute by name (for [attr] selectors, + sibling etc.)
private func selectorIncludesAttrRef(_ selector: ComplexSelector, attrName: String) -> Bool {
    for segment in selector.segments {
        for component in segment.compound.components {
            if case .attribute(let name, _, _) = component, name == attrName {
                return true
            }
        }
    }
    return false
}

/// Check if any part of a complex selector references a class name
private func selectorReferencesClassAnywhere(_ selector: ComplexSelector, className: String) -> Bool {
    for segment in selector.segments {
        for component in segment.compound.components {
            if case .className(let name) = component, name == className {
                return true
            }
            if case .attribute(let name, _, let value) = component,
               name == "class", value == className {
                return true
            }
        }
    }
    return false
}

/// Check if any part of a complex selector references an ID
private func selectorReferencesIdAnywhere(_ selector: ComplexSelector, id: String) -> Bool {
    for segment in selector.segments {
        for component in segment.compound.components {
            if case .id(let name) = component, name == id {
                return true
            }
            if case .attribute(let name, _, let value) = component,
               name == "id", value == id {
                return true
            }
        }
    }
    return false
}

private func iRemoveClassFromElement(_ element: XastElement, className: String) {
    guard let classAttr = element.attributes["class"] else { return }
    var classes = classAttr.split(separator: " ").map(String.init)
    classes.removeAll { $0 == className }
    if classes.isEmpty {
        element.attributes.removeValue(forKey: "class")
    } else {
        element.attributes["class"] = classes.joined(separator: " ")
    }
}
