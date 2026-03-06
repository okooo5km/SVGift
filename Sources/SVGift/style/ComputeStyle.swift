// ComputeStyle.swift
// Compute effective CSS styles for an SVG element
// okooo5km(十里)

import Foundation

// MARK: - computeStyle

/// Compute the effective style for an element, considering:
/// 1. Presentation attributes
/// 2. Stylesheet rules (by specificity)
/// 3. Inline style attribute
/// 4. Inherited styles from ancestors
///
/// Returns a dictionary of property name -> ComputedStyleValue.
public func computeStyle(stylesheet: Stylesheet, node: XastElement) -> ComputedStyles {
    var computedStyles = computeOwnStyle(stylesheet: stylesheet, node: node)

    // Walk up the tree to collect inherited styles
    var parent = stylesheet.parentMap[ObjectIdentifier(node)]
    while parent != nil {
        if case .element(let parentElement) = parent! {
            let inheritedStyles = computeOwnStyle(stylesheet: stylesheet, node: parentElement)
            for (name, computed) in inheritedStyles {
                if computedStyles[name] == nil
                    && inheritableAttrs.contains(name)
                    && !presentationNonInheritableGroupAttrs.contains(name) {
                    switch computed {
                    case .static(let value, _):
                        computedStyles[name] = .static(value: value, inherited: true)
                    case .dynamic:
                        computedStyles[name] = .dynamic(inherited: true)
                    }
                }
            }
            parent = stylesheet.parentMap[ObjectIdentifier(parentElement)]
        } else {
            break
        }
    }

    return computedStyles
}

// MARK: - computeOwnStyle

/// Compute the element's own style (no inheritance).
private func computeOwnStyle(
    stylesheet: Stylesheet,
    node: XastElement
) -> ComputedStyles {
    var computedStyle = ComputedStyles()
    var importantStyles: [String: Bool] = [:]

    let presentationAttrsSet = attrsGroups["presentation"] ?? []

    // 1. Collect presentation attributes
    for (name, value) in node.attributes {
        if presentationAttrsSet.contains(name) {
            computedStyle[name] = .static(value: value, inherited: false)
            importantStyles[name] = false
        }
    }

    // 2. Collect matching stylesheet rules
    for rule in stylesheet.rules {
        if selectorMatches(node, selectorText: rule.selectorText, parentMap: stylesheet.parentMap) {
            for decl in rule.declarations {
                if let computed = computedStyle[decl.name], case .dynamic = computed { continue }
                if rule.dynamic {
                    computedStyle[decl.name] = .dynamic(inherited: false)
                    continue
                }
                if computedStyle[decl.name] == nil
                    || decl.important
                    || importantStyles[decl.name] == false {
                    computedStyle[decl.name] = .static(value: decl.value, inherited: false)
                    importantStyles[decl.name] = decl.important
                }
            }
        }
    }

    // 3. Collect inline style declarations
    if let styleValue = node.attributes["style"] {
        let declarations = parseCSSDeclarations(styleValue)
        for decl in declarations {
            if let computed = computedStyle[decl.name], case .dynamic = computed { continue }
            if computedStyle[decl.name] == nil
                || decl.important
                || importantStyles[decl.name] == false {
                computedStyle[decl.name] = .static(value: decl.value, inherited: false)
                importantStyles[decl.name] = decl.important
            }
        }
    }

    return computedStyle
}
