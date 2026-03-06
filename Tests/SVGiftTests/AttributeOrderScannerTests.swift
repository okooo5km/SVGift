// AttributeOrderScannerTests.swift
// Unit tests for the XML attribute order pre-scanner
// okooo5km(十里)

@testable import SVGift
import Testing

@Test("Basic element attribute order")
func basicAttributeOrder() {
    let xml = #"<svg width="100" height="100">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].tagName == "svg")
    #expect(result[0].attributeNames == ["width", "height"])
}

@Test("Self-closing element")
func selfClosingElement() {
    let xml = #"<rect x="0" y="0"/>"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].tagName == "rect")
    #expect(result[0].attributeNames == ["x", "y"])
}

@Test("Self-closing element with space before slash")
func selfClosingWithSpace() {
    let xml = #"<rect x="0" y="0" />"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["x", "y"])
}

@Test("Single-quoted attribute values")
func singleQuotedAttributes() {
    let xml = "<rect x='0' y='10'/>"
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["x", "y"])
}

@Test("Namespace attributes preserve order")
func namespaceAttributes() {
    let xml = #"<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="100">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["xmlns", "xmlns:xlink", "width"])
}

@Test("Empty xmlns declaration is rescued")
func emptyXmlnsRescued() {
    let xml = #"<svg xmlns:xlink="">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["xmlns:xlink"])
    #expect(result[0].rescuedAttributes.count == 1)
    #expect(result[0].rescuedAttributes[0].name == "xmlns:xlink")
    #expect(result[0].rescuedAttributes[0].value == "")
}

@Test("Skip comments")
func skipComments() {
    let xml = #"<!-- <fake attr="x"> --><svg width="100">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].tagName == "svg")
    #expect(result[0].attributeNames == ["width"])
}

@Test("Skip CDATA sections")
func skipCDATA() {
    let xml = #"<style><![CDATA[ <fake a="1"> ]]></style>"#
    let result = scanAttributeOrder(from: xml)
    // Only <style> should be scanned, not <fake>
    #expect(result.count == 1)
    #expect(result[0].tagName == "style")
}

@Test("Skip processing instructions")
func skipPI() {
    let xml = #"<?xml version="1.0"?><svg width="100">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].tagName == "svg")
}

@Test("DOCTYPE with internal subset")
func doctypeWithInternalSubset() {
    let xml = """
    <!DOCTYPE svg [
      <!ENTITY foo "bar">
    ]>
    <svg width="100">
    """
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].tagName == "svg")
}

@Test("Multiple elements in order")
func multipleElements() {
    let xml = #"<svg width="100" height="100"><rect x="0" y="0"/><circle r="5" cx="10"/></svg>"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 3)
    #expect(result[0].tagName == "svg")
    #expect(result[0].attributeNames == ["width", "height"])
    #expect(result[1].tagName == "rect")
    #expect(result[1].attributeNames == ["x", "y"])
    #expect(result[2].tagName == "circle")
    #expect(result[2].attributeNames == ["r", "cx"])
}

@Test("Closing tags are not counted")
func closingTagsIgnored() {
    let xml = #"<svg><rect/></svg>"#
    let result = scanAttributeOrder(from: xml)
    // Only opening tags: svg and rect
    #expect(result.count == 2)
    #expect(result[0].tagName == "svg")
    #expect(result[1].tagName == "rect")
}

@Test("Multiline attribute values")
func multilineAttributeValues() {
    let xml = """
    <svg
      width="100"
      height="200"
      viewBox="0 0
      100 200">
    """
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["width", "height", "viewBox"])
}

@Test("Entity decoding in rescued attributes")
func entityDecoding() {
    let xml = #"<svg xmlns:test="&amp;">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    // Not rescued because value is not empty after entity decode
    #expect(result[0].rescuedAttributes.isEmpty)
}

@Test("sortAttrs.03 regression - xmlns:xlink empty value preserved")
func sortAttrs03Regression() {
    let xml = #"<svg xmlns:editor2="link" fill="" b="" xmlns:xlink="" xmlns:editor1="link" xmlns="" d="">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].tagName == "svg")
    #expect(result[0].attributeNames == [
        "xmlns:editor2", "fill", "b", "xmlns:xlink", "xmlns:editor1", "xmlns", "d"
    ])
    // xmlns:xlink="" should be rescued
    let rescued = result[0].rescuedAttributes
    let xlinkRescued = rescued.first { $0.name == "xmlns:xlink" }
    #expect(xlinkRescued != nil, "xmlns:xlink should be rescued")
    #expect(xlinkRescued?.value == "")
}

@Test("Boolean attributes (no value)")
func booleanAttributes() {
    let xml = #"<svg focusable hidden class="test">"#
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["focusable", "hidden", "class"])
}

@Test("Element with no attributes")
func noAttributes() {
    let xml = "<svg></svg>"
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames.isEmpty)
}

@Test("Attributes with special chars in values")
func specialCharsInValues() {
    let xml = #"<svg data-x="a>b" class="foo">"#
    // The '>' inside the quoted value should not close the tag
    let result = scanAttributeOrder(from: xml)
    #expect(result.count == 1)
    #expect(result[0].attributeNames == ["data-x", "class"])
}
