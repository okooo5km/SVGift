// svgo_swiftTests.swift
// Core tests for svgo-swift
// okooo5km(十里)

@testable import SVGift
import Testing

// MARK: - Parse-Stringify Roundtrip

// Note: FoundationXML.XMLParser does not preserve attribute order from the
// original XML. Attributes come back in an unordered [String: String] dict.
// Our OrderedAttributes sorts them alphabetically for deterministic output.
// Roundtrip tests therefore verify structural equivalence rather than byte
// identity of attribute ordering.

@Test("Parse and stringify preserves elements and attribute values")
func parseStringifyRoundtrip() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><rect x=\"10\" y=\"10\" width=\"80\" height=\"80\"/></svg>"
    let ast = try parseSvg(input)
    let output = stringifySvg(ast)

    // Verify all attributes present with correct values (order may differ)
    let reparsed = try parseSvg(output)
    guard case .element(let svg) = reparsed.children.first else {
        Issue.record("Expected svg element")
        return
    }
    #expect(svg.attributes["xmlns"] == "http://www.w3.org/2000/svg")
    #expect(svg.attributes["viewBox"] == "0 0 100 100")

    guard case .element(let rect) = svg.children.first else {
        Issue.record("Expected rect element")
        return
    }
    #expect(rect.attributes["x"] == "10")
    #expect(rect.attributes["width"] == "80")
}

@Test("Parse and stringify SVG with text content")
func parseStringifyWithText() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><text x=\"10\" y=\"20\">Hello World</text></svg>"
    let ast = try parseSvg(input)
    let output = stringifySvg(ast)
    // Text content and structure should be preserved exactly
    #expect(output.contains(">Hello World</text>"))
    #expect(output.contains("<text"))
}

@Test("Parse and stringify SVG with comment")
func parseStringifyWithComment() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><!--A comment--><rect/></svg>"
    let ast = try parseSvg(input)
    let output = stringifySvg(ast)
    #expect(output.contains("<!--A comment-->"))
}

@Test("Parse and stringify SVG with CDATA")
func parseStringifyWithCDATA() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><style><![CDATA[.cls{fill:red}]]></style></svg>"
    let ast = try parseSvg(input)
    let output = stringifySvg(ast)
    #expect(output.contains("<![CDATA[.cls{fill:red}]]>"))
}

@Test("Roundtrip is idempotent (parse-stringify-parse-stringify gives same result)")
func parseStringifyIdempotent() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><rect x=\"10\" y=\"10\" width=\"80\" height=\"80\"/></svg>"
    let ast1 = try parseSvg(input)
    let output1 = stringifySvg(ast1)
    let ast2 = try parseSvg(output1)
    let output2 = stringifySvg(ast2)
    // Second roundtrip should be byte-identical (deterministic attribute order)
    #expect(output1 == output2)
}

// MARK: - Optimize API

@Test("Optimize with no plugins is idempotent")
func optimizeNoPlugins() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect x=\"10\" y=\"10\" width=\"80\" height=\"80\"/></svg>"
    let result = try optimize(input)
    // Verify structural preservation
    let ast = try parseSvg(result.data)
    guard case .element(let svg) = ast.children.first else {
        Issue.record("Expected svg element")
        return
    }
    #expect(svg.name == "svg")
    guard case .element(let rect) = svg.children.first else {
        Issue.record("Expected rect element")
        return
    }
    #expect(rect.attributes["x"] == "10")
    #expect(rect.attributes["width"] == "80")
}

// MARK: - AST Structure

@Test("Parsed AST has correct structure")
func parsedASTStructure() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect/><circle/></svg>"
    let ast = try parseSvg(input)

    #expect(ast.children.count == 1)
    guard case .element(let svg) = ast.children.first else {
        Issue.record("Expected element node")
        return
    }
    #expect(svg.name == "svg")
    #expect(svg.children.count == 2)
}

// MARK: - Visitor

@Test("Visitor can remove nodes safely")
func visitorRemoveNode() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><!--remove me--><rect/></svg>"
    let ast = try parseSvg(input)

    let visitor = Visitor(
        comment: VisitorCallbacks<XastComment>(
            enter: { comment, parent in
                detachNodeFromParent(.comment(comment), from: parent)
                return .continue
            }
        )
    )
    visit(ast, visitor: visitor)

    let output = stringifySvg(ast)
    // After removing comment, only svg and rect should remain
    #expect(!output.contains("<!--"))
    #expect(output.contains("<rect/>"))
}

// MARK: - Stringify Options

@Test("Stringify with pretty printing")
func stringifyPretty() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"><rect/></svg>"
    let ast = try parseSvg(input)
    let output = stringifySvg(ast, options: StringifyOptions(indent: 2, pretty: true))
    #expect(output.contains("\n"))
}

@Test("Stringify with final newline")
func stringifyFinalNewline() throws {
    let input = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"
    let ast = try parseSvg(input)
    let output = stringifySvg(ast, options: StringifyOptions(finalNewline: true))
    #expect(output.hasSuffix("\n"))
}
