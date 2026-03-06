// SVGParser.swift
// XML parser that builds the XastNode AST from SVG strings
// okooo5km(十里)

#if canImport(FoundationXML)
    import FoundationXML
#else
    import Foundation
#endif

// MARK: - Text Element Detection

/// Set of element names whose text content whitespace should be preserved
private let textElements: Set<String> = [
    "text", "tspan", "textpath", "a", "pre",
    "title", "desc", "altglyph", "glyphref", "tref",
]

/// Check if an element name is a text-content element (case-insensitive)
private func isTextElement(_ name: String) -> Bool {
    textElements.contains(name.lowercased())
}

// MARK: - SAX Parser Delegate

/// XMLParser delegate that builds the XAST from SAX events
private class SVGParserDelegate: NSObject, XMLParserDelegate {
    /// The root node being built
    let root = XastRoot()

    /// Stack of parent nodes for tracking nesting; the top is the current parent
    private var parentStack: [XastParent] = []

    /// Accumulated text characters (may arrive across multiple callbacks)
    private var textBuffer: String = ""

    /// Whether we are inside a text-content element
    private var textElementDepth: Int = 0

    /// Parse error captured from the delegate callback
    var parseError: Error?

    /// Pre-scanned element attribute order information
    var scannedElements: [ScannedElement] = []

    /// Index into scannedElements, incremented for each opening tag
    private var elementIndex: Int = 0

    override init() {
        super.init()
        parentStack = [.root(root)]
    }

    /// The current parent node (top of the stack)
    private var currentParent: XastParent {
        get { parentStack[parentStack.count - 1] }
        set { parentStack[parentStack.count - 1] = newValue }
    }

    /// Flush any accumulated text in the buffer as a text node
    private func flushTextBuffer() {
        guard !textBuffer.isEmpty else { return }

        let inTextElement = textElementDepth > 0
        let value = inTextElement ? textBuffer : textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if !value.isEmpty {
            let textNode = XastText(value: value)
            appendChildToCurrentParent(.text(textNode))
        }

        textBuffer = ""
    }

    /// Append a child node to the current parent
    private func appendChildToCurrentParent(_ child: XastChild) {
        switch currentParent {
        case .root(let root):
            root.children.append(child)
        case .element(let element):
            element.children.append(child)
        }
    }

    // MARK: - XMLParserDelegate Methods

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Flush any pending text before starting a new element
        flushTextBuffer()

        // Build ordered attributes using pre-scanned order
        let attributes: OrderedAttributes
        if elementIndex < scannedElements.count {
            let scanned = scannedElements[elementIndex]
            elementIndex += 1

            if scanned.tagName == elementName {
                // Build a lookup from rescued attributes for quick access
                var rescuedLookup: [String: String] = [:]
                for rescued in scanned.rescuedAttributes {
                    rescuedLookup[rescued.name] = rescued.value
                }

                var pairs: [(key: String, value: String)] = []
                for name in scanned.attributeNames {
                    if let value = attributeDict[name] {
                        // Prefer raw value from scanner to bypass XMLParser's
                        // attribute value normalization (tab/newline → space)
                        let rawValue = scanned.rawAttributeValues[name] ?? value
                        pairs.append((key: name, value: rawValue))
                    } else if let value = rescuedLookup[name] {
                        // Restore attributes that XMLParser silently discarded
                        pairs.append((key: name, value: value))
                    }
                }
                // Add any attributes from XMLParser not in scan (safety fallback)
                let scannedSet = Set(scanned.attributeNames)
                for key in attributeDict.keys.sorted() where !scannedSet.contains(key) {
                    pairs.append((key: key, value: attributeDict[key]!))
                }
                attributes = OrderedAttributes(pairs)
            } else {
                // Tag name mismatch — fallback to alphabetical sort
                attributes = OrderedAttributes(attributeDict)
            }
        } else {
            // No more scanned elements — fallback
            attributes = OrderedAttributes(attributeDict)
        }

        let element = XastElement(
            name: elementName,
            attributes: attributes
        )

        appendChildToCurrentParent(.element(element))

        // Track text element nesting
        if isTextElement(elementName) {
            textElementDepth += 1
        }

        // Push this element as the new current parent
        parentStack.append(.element(element))
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        // Flush any pending text before closing the element
        flushTextBuffer()

        // Pop the current element from the stack
        parentStack.removeLast()

        // Track text element nesting
        if isTextElement(elementName) {
            textElementDepth -= 1
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Accumulate text (may come in multiple callbacks)
        textBuffer += string
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
        flushTextBuffer()

        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentNode = XastComment(value: trimmed)
        appendChildToCurrentParent(.comment(commentNode))
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        flushTextBuffer()

        let value = String(data: CDATABlock, encoding: .utf8) ?? ""
        let cdataNode = XastCdata(value: value)
        appendChildToCurrentParent(.cdata(cdataNode))
    }

    func parser(
        _ parser: XMLParser,
        foundProcessingInstructionWithTarget target: String,
        data: String?
    ) {
        flushTextBuffer()

        let instruction = XastInstruction(name: target, value: data ?? "")
        appendChildToCurrentParent(.instruction(instruction))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        // Flush any trailing text
        flushTextBuffer()
    }
}

// MARK: - Public API

/// Parse an SVG string into an AST
///
/// - Parameters:
///   - input: The SVG XML string to parse
///   - path: Optional file path for error reporting context
/// - Returns: The root node of the parsed AST
/// - Throws: `SVGOError.parseError` if the XML is malformed
public func parseSvg(_ input: String, path: String? = nil) throws -> XastRoot {
    // Normalize encoding declaration to UTF-8, since we always feed UTF-8 data
    // to XMLParser. A mismatch (e.g. encoding="utf-16") causes a parse error.
    let normalizedInput = input.replacingOccurrences(
        of: #"(<\?xml\b[^?]*?\bencoding\s*=\s*)(["'])[^"']*\2"#,
        with: "$1$2utf-8$2",
        options: .regularExpression
    )

    guard let data = normalizedInput.data(using: .utf8) else {
        throw SVGOError.parseError("Failed to encode input as UTF-8")
    }

    // Pre-scan the XML to extract original attribute order
    let scannedElements = scanAttributeOrder(from: normalizedInput)

    let xmlParser = XMLParser(data: data)
    xmlParser.shouldProcessNamespaces = false
    xmlParser.shouldReportNamespacePrefixes = false
    xmlParser.shouldResolveExternalEntities = false

    let delegate = SVGParserDelegate()
    delegate.scannedElements = scannedElements
    xmlParser.delegate = delegate

    let success = xmlParser.parse()

    if !success || delegate.parseError != nil {
        let error = delegate.parseError as? NSError
        let line = error?.userInfo["NSXMLParserErrorLineNumber"] as? Int
            ?? xmlParser.lineNumber
        let column = error?.userInfo["NSXMLParserErrorColumn"] as? Int
            ?? xmlParser.columnNumber
        let description = error?.localizedDescription ?? "Unknown parse error"

        let pathInfo = path.map { " in \($0)" } ?? ""
        throw SVGOError.parseError(
            "\(description) at line \(line), column \(column)\(pathInfo)"
        )
    }

    // Restore XML declaration (XMLParser doesn't report <?xml ...?> as PI)
    if let xmlDeclRange = input.range(
        of: #"<\?xml\s+[^?]*\?>"#, options: .regularExpression
    ) {
        let declStr = String(input[xmlDeclRange])
        let value = declStr
            .replacingOccurrences(of: "<?xml", with: "")
            .replacingOccurrences(of: "?>", with: "")
            .trimmingCharacters(in: .whitespaces)
        let instruction = XastInstruction(name: "xml", value: value)
        delegate.root.children.insert(.instruction(instruction), at: 0)
    }

    return delegate.root
}
