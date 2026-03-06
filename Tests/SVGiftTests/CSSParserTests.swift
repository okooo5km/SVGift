// CSSParserTests.swift
// Unit tests for CSS parser
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - CSS Declaration Parsing

@Test("Parse basic CSS declarations")
func parseBasicDeclarations() {
    let decls = parseCSSDeclarations("fill: red; stroke: blue")
    #expect(decls.count == 2)
    #expect(decls[0].name == "fill")
    #expect(decls[0].value == "red")
    #expect(decls[1].name == "stroke")
    #expect(decls[1].value == "blue")
}

@Test("Parse declaration with !important")
func parseImportantDeclaration() {
    let decls = parseCSSDeclarations("fill: red !important; stroke: blue")
    #expect(decls.count == 2)
    #expect(decls[0].name == "fill")
    #expect(decls[0].value == "red")
    #expect(decls[0].important == true)
    #expect(decls[1].important == false)
}

@Test("Parse declaration with URL value")
func parseURLDeclaration() {
    let decls = parseCSSDeclarations("fill: url(#gradient); opacity: 0.5")
    #expect(decls.count == 2)
    #expect(decls[0].value == "url(#gradient)")
}

@Test("Parse empty declarations")
func parseEmptyDeclarations() {
    let decls = parseCSSDeclarations("")
    #expect(decls.isEmpty)
}

@Test("Serialize declarations roundtrip")
func serializeDeclarationsRoundtrip() {
    let decls = [
        CSSDeclaration(name: "fill", value: "red"),
        CSSDeclaration(name: "stroke", value: "blue", important: true),
    ]
    let result = serializeCSSDeclarations(decls)
    #expect(result == "fill:red;stroke:blue!important")
}

// MARK: - CSS Stylesheet Parsing

@Test("Parse basic stylesheet rule")
func parseBasicStylesheet() {
    let items = parseCSSStylesheet(".cls { fill: red; stroke: blue }")
    #expect(items.count == 1)
    if case .rule(let rule) = items[0] {
        #expect(rule.selectorText == ".cls")
        #expect(rule.declarations.count == 2)
    } else {
        Issue.record("Expected rule")
    }
}

@Test("Parse stylesheet with @media")
func parseStylesheetWithMedia() {
    let css = """
    .cls { fill: red }
    @media screen { .cls2 { stroke: blue } }
    """
    let items = parseCSSStylesheet(css)
    #expect(items.count == 2)

    if case .rule(let rule) = items[0] {
        #expect(rule.selectorText == ".cls")
    }
    if case .atRule(let atRule) = items[1] {
        #expect(atRule.name == "media")
        #expect(atRule.prelude == "screen")
        #expect(atRule.rules.count == 1)
    }
}

@Test("Parse stylesheet with comments")
func parseStylesheetWithComments() {
    let css = "/* comment */ .cls { fill: red }"
    let items = parseCSSStylesheet(css)
    #expect(items.count == 1)
}

// MARK: - CSS Selector Parsing

@Test("Parse type selector")
func parseTypeSelector() throws {
    let list = try parseSelector("rect")
    #expect(list.selectors.count == 1)
    #expect(list.selectors[0].segments.count == 1)
    #expect(list.selectors[0].segments[0].compound.components == [.type("rect")])
}

@Test("Parse class selector")
func parseClassSelector() throws {
    let list = try parseSelector(".cls")
    #expect(list.selectors[0].segments[0].compound.components == [.className("cls")])
}

@Test("Parse ID selector")
func parseIDSelector() throws {
    let list = try parseSelector("#foo")
    #expect(list.selectors[0].segments[0].compound.components == [.id("foo")])
}

@Test("Parse attribute selector")
func parseAttributeSelector() throws {
    let list = try parseSelector("[fill='#00ff00']")
    if case .attribute(let name, let op, let value) = list.selectors[0].segments[0].compound.components[0] {
        #expect(name == "fill")
        #expect(op == .eq)
        #expect(value == "#00ff00")
    } else {
        Issue.record("Expected attribute selector")
    }
}

@Test("Parse compound selector")
func parseCompoundSelector() throws {
    let list = try parseSelector("rect.cls#id")
    let components = list.selectors[0].segments[0].compound.components
    #expect(components.count == 3)
    #expect(components[0] == .type("rect"))
    #expect(components[1] == .className("cls"))
    #expect(components[2] == .id("id"))
}

@Test("Parse descendant combinator")
func parseDescendantCombinator() throws {
    let list = try parseSelector("svg rect")
    #expect(list.selectors[0].segments.count == 2)
    #expect(list.selectors[0].segments[0].combinator == .descendant)
}

@Test("Parse child combinator")
func parseChildCombinator() throws {
    let list = try parseSelector("svg > rect")
    #expect(list.selectors[0].segments.count == 2)
    #expect(list.selectors[0].segments[0].combinator == .child)
}

@Test("Parse selector list")
func parseSelectorList() throws {
    let list = try parseSelector("rect, circle")
    #expect(list.selectors.count == 2)
}

@Test("Parse :not() pseudo-class")
func parseNotPseudo() throws {
    let list = try parseSelector(":not(.hidden)")
    if case .pseudoClass(let name, let arg) = list.selectors[0].segments[0].compound.components[0] {
        #expect(name == "not")
        #expect(arg == ".hidden")
    }
}

// MARK: - Specificity

@Test("Specificity: type selector")
func specificityType() throws {
    let list = try parseSelector("rect")
    let spec = computeSpecificity(list.selectors[0])
    #expect(spec == Specificity(a: 0, b: 0, c: 1))
}

@Test("Specificity: class selector")
func specificityClass() throws {
    let list = try parseSelector(".cls")
    let spec = computeSpecificity(list.selectors[0])
    #expect(spec == Specificity(a: 0, b: 1, c: 0))
}

@Test("Specificity: ID selector")
func specificityID() throws {
    let list = try parseSelector("#foo")
    let spec = computeSpecificity(list.selectors[0])
    #expect(spec == Specificity(a: 1, b: 0, c: 0))
}

@Test("Specificity: compound selector")
func specificityCompound() throws {
    let list = try parseSelector("rect.cls#foo")
    let spec = computeSpecificity(list.selectors[0])
    #expect(spec == Specificity(a: 1, b: 1, c: 1))
}

// MARK: - Selector Matching

@Test("Match type selector")
func matchTypeSelector() {
    let root = XastRoot(children: [
        .element(XastElement(name: "rect")),
    ])
    let parentMap = buildParentMap(root)
    let elements = try! querySelectorAll(root, selectorText: "rect", parentMap: parentMap)
    #expect(elements.count == 1)
    #expect(elements[0].name == "rect")
}

@Test("Match class selector")
func matchClassSelector() {
    let root = XastRoot(children: [
        .element(XastElement(name: "rect", attributes: ["class": "st0"])),
        .element(XastElement(name: "rect", attributes: ["class": "st1"])),
    ])
    let parentMap = buildParentMap(root)
    let elements = try! querySelectorAll(root, selectorText: ".st0", parentMap: parentMap)
    #expect(elements.count == 1)
}

@Test("Match attribute selector")
func matchAttributeSelector() {
    let root = XastRoot(children: [
        .element(XastElement(name: "rect", attributes: ["fill": "#00ff00"])),
        .element(XastElement(name: "rect", attributes: ["fill": "#ff0000"])),
    ])
    let parentMap = buildParentMap(root)
    let elements = try! querySelectorAll(root, selectorText: "[fill='#00ff00']", parentMap: parentMap)
    #expect(elements.count == 1)
}

@Test("Match descendant combinator")
func matchDescendantCombinator() {
    let inner = XastElement(name: "rect")
    let svg = XastElement(name: "svg", children: [.element(inner)])
    let root = XastRoot(children: [.element(svg)])
    let parentMap = buildParentMap(root)
    let elements = try! querySelectorAll(root, selectorText: "svg rect", parentMap: parentMap)
    #expect(elements.count == 1)
}

@Test("Match ID selector")
func matchIDSelector() {
    let root = XastRoot(children: [
        .element(XastElement(name: "rect", attributes: ["id": "remove"])),
        .element(XastElement(name: "rect", attributes: ["id": "keep"])),
    ])
    let parentMap = buildParentMap(root)
    let elements = try! querySelectorAll(root, selectorText: "#remove", parentMap: parentMap)
    #expect(elements.count == 1)
}
