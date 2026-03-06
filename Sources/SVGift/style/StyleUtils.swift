// StyleUtils.swift
// Style-related utility functions for SVG optimization
// okooo5km(十里)

import Foundation

// MARK: - Stylesheet Types

/// A stylesheet rule with specificity and metadata
public struct StylesheetRule {
    public let specificity: Specificity
    public let dynamic: Bool
    public let selectorText: String
    public let declarations: [CSSDeclaration]

    public init(
        specificity: Specificity,
        dynamic: Bool,
        selectorText: String,
        declarations: [CSSDeclaration]
    ) {
        self.specificity = specificity
        self.dynamic = dynamic
        self.selectorText = selectorText
        self.declarations = declarations
    }
}

/// Collected stylesheet from <style> elements
public struct Stylesheet {
    public let rules: [StylesheetRule]
    public let parentMap: ParentMap

    public init(rules: [StylesheetRule], parentMap: ParentMap) {
        self.rules = rules
        self.parentMap = parentMap
    }
}

// MARK: - Computed Style Types

/// A computed style value
public enum ComputedStyleValue {
    case `static`(value: String, inherited: Bool)
    case dynamic(inherited: Bool)
}

public typealias ComputedStyles = [String: ComputedStyleValue]

// MARK: - Script Detection

/// Dynamic pseudo-classes that cannot be evaluated during optimization
private let dynamicPseudoClasses: Set<String> = [
    "hover", "active", "focus", "visited", "target", "focus-within",
    "focus-visible", "any-link", "link", "future", "past", "playing",
    "paused", "current",
]

/// Check if an element has scripts (event handlers or <script>)
public func hasScripts(_ element: XastElement) -> Bool {
    if element.name == "script" { return true }
    // Check for event handler attributes
    for key in element.attributes.keys {
        if key.hasPrefix("on") { return true }
    }
    return false
}

// MARK: - Stylesheet Collection

/// Collect all stylesheet rules from <style> elements in the AST
public func collectStylesheet(_ root: XastRoot) -> Stylesheet {
    var rules: [StylesheetRule] = []
    let parentMap = buildParentMap(root)

    collectStylesheetRecursive(children: root.children, rules: &rules)

    // Sort by specificity (ascending)
    rules.sort { compareSpecificity($0.specificity, $1.specificity) < 0 }

    return Stylesheet(rules: rules, parentMap: parentMap)
}

private func collectStylesheetRecursive(children: [XastChild], rules: inout [StylesheetRule]) {
    for child in children {
        guard case .element(let element) = child else { continue }

        if element.name == "style" {
            // Validate type attribute
            if let type = element.attributes["type"],
               !type.isEmpty,
               type != "text/css" {
                continue
            }

            let isDynamic = element.attributes["media"] != nil &&
                           element.attributes["media"] != "all"

            // Extract CSS content
            for styleChild in element.children {
                let cssText: String
                switch styleChild {
                case .text(let t): cssText = t.value
                case .cdata(let c): cssText = c.value
                default: continue
                }

                // Parse the CSS and collect rules
                let items = parseCSSStylesheet(cssText)
                for item in items {
                    switch item {
                    case .rule(let cssRule):
                        appendRules(from: cssRule, dynamic: isDynamic, rules: &rules)
                    case .atRule(let atRule):
                        // Rules inside @media etc. are considered dynamic
                        let keyframeNames: Set<String> = [
                            "keyframes", "-webkit-keyframes", "-o-keyframes", "-moz-keyframes",
                        ]
                        if !keyframeNames.contains(atRule.name) {
                            for innerRule in atRule.rules {
                                appendRules(from: innerRule, dynamic: true, rules: &rules)
                            }
                        }
                    }
                }
            }
        }

        collectStylesheetRecursive(children: element.children, rules: &rules)
    }
}

private func appendRules(from cssRule: CSSRule, dynamic: Bool, rules: inout [StylesheetRule]) {
    // Parse selector to compute specificity per selector in the list
    guard let selectorList = try? parseSelector(cssRule.selectorText) else { return }

    for selector in selectorList.selectors {
        let spec = computeSpecificity(selector)
        // Check for pseudo-classes that make this rule dynamic
        var isDynamic = dynamic
        // Regenerate selector text without dynamic pseudo-classes
        // For simplicity, we'll check each compound for dynamic pseudo-classes
        for segment in selector.segments {
            for component in segment.compound.components {
                if case .pseudoClass(let name, _) = component {
                    if !PseudoClassCategories.preserved.contains(name) {
                        isDynamic = true
                    }
                }
            }
        }

        // Use original selector text (we could regenerate, but original is fine)
        let selectorText = generateSelectorText(selector)

        rules.append(StylesheetRule(
            specificity: spec,
            dynamic: isDynamic,
            selectorText: selectorText,
            declarations: cssRule.declarations
        ))
    }
}

/// Generate selector text from a parsed ComplexSelector
private func generateSelectorText(_ selector: ComplexSelector) -> String {
    var parts: [String] = []

    for (i, segment) in selector.segments.enumerated() {
        var compoundParts: [String] = []

        for component in segment.compound.components {
            switch component {
            case .type(let name):
                compoundParts.append(name)
            case .universal:
                compoundParts.append("*")
            case .id(let id):
                compoundParts.append("#\(id)")
            case .className(let cls):
                compoundParts.append(".\(cls)")
            case .attribute(let name, let op, let value):
                if let op = op, let value = value {
                    compoundParts.append("[\(name)\(op.rawValue)\"\(value)\"]")
                } else {
                    compoundParts.append("[\(name)]")
                }
            case .pseudoClass(let name, let arg):
                if let arg = arg {
                    compoundParts.append(":\(name)(\(arg))")
                } else {
                    compoundParts.append(":\(name)")
                }
            case .pseudoElement(let name):
                compoundParts.append("::\(name)")
            }
        }

        parts.append(compoundParts.joined())

        if i < selector.segments.count - 1, let combinator = segment.combinator {
            switch combinator {
            case .descendant: parts.append(" ")
            case .child: parts.append(">")
            case .adjacentSibling: parts.append("+")
            case .generalSibling: parts.append("~")
            }
        }
    }

    return parts.joined()
}
