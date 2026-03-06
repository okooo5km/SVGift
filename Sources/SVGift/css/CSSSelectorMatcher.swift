// CSSSelectorMatcher.swift
// CSS selector matching engine for XAST elements
// okooo5km(十里)

import Foundation

// MARK: - Parent Map

/// Map from element identity to its parent
public typealias ParentMap = [ObjectIdentifier: XastParent]

/// Build a parent map by traversing the AST
public func buildParentMap(_ root: XastRoot) -> ParentMap {
    var map = ParentMap()
    buildParentMapRecursive(children: root.children, parent: .root(root), map: &map)
    return map
}

private func buildParentMapRecursive(children: [XastChild], parent: XastParent, map: inout ParentMap) {
    for child in children {
        if case .element(let element) = child {
            map[ObjectIdentifier(element)] = parent
            buildParentMapRecursive(children: element.children, parent: .element(element), map: &map)
        }
    }
}

// MARK: - Query API

/// Find all elements in the AST matching a CSS selector string
public func querySelectorAll(
    _ root: XastRoot,
    selectorText: String,
    parentMap: ParentMap? = nil
) throws -> [XastElement] {
    let selectorList = try parseSelector(selectorText)
    let pmap = parentMap ?? buildParentMap(root)
    var results: [XastElement] = []
    collectMatchingElements(children: root.children, selectors: selectorList, parentMap: pmap, results: &results)
    return results
}

private func collectMatchingElements(
    children: [XastChild],
    selectors: SelectorList,
    parentMap: ParentMap,
    results: inout [XastElement]
) {
    for child in children {
        if case .element(let element) = child {
            if selectorListMatches(element, selectorList: selectors, parentMap: parentMap) {
                results.append(element)
            }
            collectMatchingElements(children: element.children, selectors: selectors, parentMap: parentMap, results: &results)
        }
    }
}

/// Check if an element matches a CSS selector string
public func selectorMatches(
    _ element: XastElement,
    selectorText: String,
    parentMap: ParentMap
) -> Bool {
    guard let selectorList = try? parseSelector(selectorText) else { return false }
    return selectorListMatches(element, selectorList: selectorList, parentMap: parentMap)
}

/// Check if an element matches any selector in a SelectorList
public func selectorListMatches(
    _ element: XastElement,
    selectorList: SelectorList,
    parentMap: ParentMap
) -> Bool {
    for selector in selectorList.selectors {
        if complexSelectorMatches(element, selector: selector, parentMap: parentMap) {
            return true
        }
    }
    return false
}

// MARK: - Complex Selector Matching (right-to-left)

/// Match a complex selector against an element.
/// We start from the rightmost compound selector and work backwards using combinators.
func complexSelectorMatches(
    _ element: XastElement,
    selector: ComplexSelector,
    parentMap: ParentMap
) -> Bool {
    let segments = selector.segments
    guard !segments.isEmpty else { return false }

    // Start with the last segment (the target)
    let lastIndex = segments.count - 1

    guard compoundSelectorMatches(element, compound: segments[lastIndex].compound, parentMap: parentMap) else {
        return false
    }

    // Walk backwards through the segments
    var currentElement = element
    var segmentIndex = lastIndex - 1

    while segmentIndex >= 0 {
        let combinator = segments[segmentIndex].combinator ?? .descendant
        let compound = segments[segmentIndex].compound

        switch combinator {
        case .child:
            // Parent must match
            guard let parent = getParentElement(currentElement, parentMap: parentMap) else {
                return false
            }
            guard compoundSelectorMatches(parent, compound: compound, parentMap: parentMap) else {
                return false
            }
            currentElement = parent

        case .descendant:
            // Any ancestor must match
            var ancestor = getParentElement(currentElement, parentMap: parentMap)
            var found = false
            while let anc = ancestor {
                if compoundSelectorMatches(anc, compound: compound, parentMap: parentMap) {
                    currentElement = anc
                    found = true
                    break
                }
                ancestor = getParentElement(anc, parentMap: parentMap)
            }
            if !found { return false }

        case .adjacentSibling:
            // Previous sibling must match
            guard let prevSibling = getPreviousSiblingElement(currentElement, parentMap: parentMap) else {
                return false
            }
            guard compoundSelectorMatches(prevSibling, compound: compound, parentMap: parentMap) else {
                return false
            }
            currentElement = prevSibling

        case .generalSibling:
            // Any preceding sibling must match
            guard let parent = parentMap[ObjectIdentifier(currentElement)] else {
                return false
            }
            let siblings = parent.children
            var found = false
            for sibling in siblings {
                if case .element(let sibEl) = sibling {
                    if sibEl === currentElement { break }
                    if compoundSelectorMatches(sibEl, compound: compound, parentMap: parentMap) {
                        currentElement = sibEl
                        found = true
                        // Don't break — we want to find any match, but use last one found
                    }
                }
            }
            if !found { return false }
        }

        segmentIndex -= 1
    }

    return true
}

// MARK: - Compound Selector Matching

/// Check if an element matches all components of a compound selector
func compoundSelectorMatches(
    _ element: XastElement,
    compound: CompoundSelector,
    parentMap: ParentMap
) -> Bool {
    for component in compound.components {
        if !simpleSelectorMatches(element, component: component, parentMap: parentMap) {
            return false
        }
    }
    return true
}

// MARK: - Simple Selector Matching

/// Check if an element matches a single simple selector component
func simpleSelectorMatches(
    _ element: XastElement,
    component: SimpleSelectorComponent,
    parentMap: ParentMap
) -> Bool {
    switch component {
    case .type(let name):
        return element.name == name

    case .universal:
        return true

    case .id(let id):
        return element.attributes["id"] == id

    case .className(let cls):
        guard let classAttr = element.attributes["class"] else { return false }
        let classes = classAttr.split(separator: " ").map(String.init)
        return classes.contains(cls)

    case .attribute(let name, let op, let value):
        return matchAttribute(element, name: name, op: op, value: value)

    case .pseudoClass(let name, let argument):
        return matchPseudoClass(element, name: name, argument: argument, parentMap: parentMap)

    case .pseudoElement:
        // Pseudo-elements never match real elements
        return false
    }
}

// MARK: - Attribute Matching

private func matchAttribute(
    _ element: XastElement,
    name: String,
    op: AttrOp?,
    value: String?
) -> Bool {
    guard let attrValue = element.attributes[name] else { return false }

    guard let op = op, let value = value else {
        // Just checking existence
        return true
    }

    switch op {
    case .eq:
        return attrValue == value
    case .includes:
        return attrValue.split(separator: " ").contains(Substring(value))
    case .dashMatch:
        return attrValue == value || attrValue.hasPrefix(value + "-")
    case .prefix:
        return attrValue.hasPrefix(value)
    case .suffix:
        return attrValue.hasSuffix(value)
    case .substring:
        return attrValue.contains(value)
    }
}

// MARK: - Pseudo-Class Matching

private func matchPseudoClass(
    _ element: XastElement,
    name: String,
    argument: String?,
    parentMap: ParentMap
) -> Bool {
    switch name {
    case "root":
        // Element's parent is root
        if let parent = parentMap[ObjectIdentifier(element)] {
            if case .root = parent { return true }
        }
        return false

    case "empty":
        // No children (or only empty text nodes)
        return element.children.allSatisfy { child in
            if case .text(let t) = child { return t.value.isEmpty }
            return false
        } || element.children.isEmpty

    case "first-child":
        return isNthChild(element, parentMap: parentMap, fromEnd: false, index: 0)

    case "last-child":
        return isNthChild(element, parentMap: parentMap, fromEnd: true, index: 0)

    case "only-child":
        return isNthChild(element, parentMap: parentMap, fromEnd: false, index: 0) &&
               isNthChild(element, parentMap: parentMap, fromEnd: true, index: 0)

    case "first-of-type":
        return isNthOfType(element, parentMap: parentMap, fromEnd: false, index: 0)

    case "last-of-type":
        return isNthOfType(element, parentMap: parentMap, fromEnd: true, index: 0)

    case "only-of-type":
        return isNthOfType(element, parentMap: parentMap, fromEnd: false, index: 0) &&
               isNthOfType(element, parentMap: parentMap, fromEnd: true, index: 0)

    case "nth-child":
        guard let arg = argument else { return false }
        return matchNthChild(element, argument: arg, parentMap: parentMap, fromEnd: false, ofType: false)

    case "nth-last-child":
        guard let arg = argument else { return false }
        return matchNthChild(element, argument: arg, parentMap: parentMap, fromEnd: true, ofType: false)

    case "nth-of-type":
        guard let arg = argument else { return false }
        return matchNthChild(element, argument: arg, parentMap: parentMap, fromEnd: false, ofType: true)

    case "nth-last-of-type":
        guard let arg = argument else { return false }
        return matchNthChild(element, argument: arg, parentMap: parentMap, fromEnd: true, ofType: true)

    case "not":
        guard let arg = argument, let innerList = try? parseSelector(arg) else { return false }
        return !selectorListMatches(element, selectorList: innerList, parentMap: parentMap)

    case "is", "matches", "any":
        guard let arg = argument, let innerList = try? parseSelector(arg) else { return false }
        return selectorListMatches(element, selectorList: innerList, parentMap: parentMap)

    case "where":
        guard let arg = argument, let innerList = try? parseSelector(arg) else { return false }
        return selectorListMatches(element, selectorList: innerList, parentMap: parentMap)

    case "has":
        // :has() checks if the element has descendants matching the selector
        guard let arg = argument, let innerList = try? parseSelector(arg) else { return false }
        return hasMatchingDescendant(element, selectorList: innerList, parentMap: parentMap)

    default:
        // Dynamic pseudo-classes (hover, focus, visited, etc.) — don't match statically
        return false
    }
}

// MARK: - Nth-child helpers

private func getSiblingElements(_ element: XastElement, parentMap: ParentMap) -> [XastElement] {
    guard let parent = parentMap[ObjectIdentifier(element)] else { return [element] }
    return parent.children.compactMap { child in
        if case .element(let el) = child { return el }
        return nil
    }
}

private func isNthChild(_ element: XastElement, parentMap: ParentMap, fromEnd: Bool, index: Int) -> Bool {
    let siblings = getSiblingElements(element, parentMap: parentMap)
    if fromEnd {
        guard let idx = siblings.lastIndex(where: { $0 === element }) else { return false }
        return idx == siblings.count - 1 - index
    } else {
        guard let idx = siblings.firstIndex(where: { $0 === element }) else { return false }
        return idx == index
    }
}

private func isNthOfType(_ element: XastElement, parentMap: ParentMap, fromEnd: Bool, index: Int) -> Bool {
    let siblings = getSiblingElements(element, parentMap: parentMap)
        .filter { $0.name == element.name }
    if fromEnd {
        guard let idx = siblings.lastIndex(where: { $0 === element }) else { return false }
        return idx == siblings.count - 1 - index
    } else {
        guard let idx = siblings.firstIndex(where: { $0 === element }) else { return false }
        return idx == index
    }
}

/// Parse an+b expression and check if child position matches
private func matchNthChild(
    _ element: XastElement,
    argument: String,
    parentMap: ParentMap,
    fromEnd: Bool,
    ofType: Bool
) -> Bool {
    let (a, b) = parseAnPlusB(argument)
    let siblings: [XastElement]
    if ofType {
        siblings = getSiblingElements(element, parentMap: parentMap).filter { $0.name == element.name }
    } else {
        siblings = getSiblingElements(element, parentMap: parentMap)
    }

    guard let idx = siblings.firstIndex(where: { $0 === element }) else { return false }

    let position: Int
    if fromEnd {
        position = siblings.count - idx
    } else {
        position = idx + 1
    }

    return matchesAnPlusB(position: position, a: a, b: b)
}

/// Parse CSS an+b expression
/// Examples: "odd" -> (2, 1), "even" -> (2, 0), "3" -> (0, 3), "2n+1" -> (2, 1)
func parseAnPlusB(_ expr: String) -> (a: Int, b: Int) {
    let trimmed = expr.trimmingCharacters(in: .whitespaces).lowercased()

    if trimmed == "odd" { return (2, 1) }
    if trimmed == "even" { return (2, 0) }

    // Try plain number
    if let n = Int(trimmed) {
        return (0, n)
    }

    // Parse an+b pattern
    var aStr = ""
    var bStr = ""
    var hasN = false
    var afterN = false
    var sign = 1

    for ch in trimmed {
        if ch == "n" {
            hasN = true
            afterN = true
            if aStr.isEmpty || aStr == "+" { aStr = "1" }
            else if aStr == "-" { aStr = "-1" }
        } else if ch == "+" {
            if afterN { sign = 1 }
            else { aStr.append(ch) }
        } else if ch == "-" {
            if afterN { sign = -1 }
            else { aStr.append(ch) }
        } else if ch.isNumber {
            if afterN { bStr.append(ch) }
            else { aStr.append(ch) }
        }
    }

    let a = hasN ? (Int(aStr) ?? 0) : 0
    let b = bStr.isEmpty ? (hasN ? 0 : (Int(aStr) ?? 0)) : sign * (Int(bStr) ?? 0)

    return (a, b)
}

/// Check if a position (1-based) matches an+b formula
private func matchesAnPlusB(position: Int, a: Int, b: Int) -> Bool {
    if a == 0 {
        return position == b
    }
    let diff = position - b
    if diff == 0 { return true }
    if (diff > 0) == (a > 0) {
        return diff % a == 0
    }
    return false
}

// MARK: - Utility

private func getParentElement(_ element: XastElement, parentMap: ParentMap) -> XastElement? {
    guard let parent = parentMap[ObjectIdentifier(element)] else { return nil }
    if case .element(let el) = parent { return el }
    return nil
}

private func getPreviousSiblingElement(_ element: XastElement, parentMap: ParentMap) -> XastElement? {
    guard let parent = parentMap[ObjectIdentifier(element)] else { return nil }
    let siblings = parent.children
    var prevElement: XastElement?
    for child in siblings {
        if case .element(let el) = child {
            if el === element { return prevElement }
            prevElement = el
        }
    }
    return nil
}

private func hasMatchingDescendant(
    _ element: XastElement,
    selectorList: SelectorList,
    parentMap: ParentMap
) -> Bool {
    for child in element.children {
        if case .element(let el) = child {
            if selectorListMatches(el, selectorList: selectorList, parentMap: parentMap) {
                return true
            }
            if hasMatchingDescendant(el, selectorList: selectorList, parentMap: parentMap) {
                return true
            }
        }
    }
    return false
}
