// Stringifier.swift
// Converts an XastRoot AST back to an SVG string
// okooo5km(十里)

// MARK: - Text Element Set

/// Element names that establish a text context where pretty-printing
/// should not insert extra whitespace.
private let textElements: Set<String> = [
    "text", "tspan", "textPath", "a", "pre",
    "title", "desc", "altGlyph", "glyphRef", "tref",
]

// MARK: - Entity Encoding

/// Encode entities in text content: & ' " < >
private func encodeTextEntities(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "'", with: "&apos;")
    result = result.replacingOccurrences(of: "\"", with: "&quot;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    return result
}

/// Encode entities in attribute values: & " < > (NOT single quotes)
private func encodeAttributeValue(_ value: String) -> String {
    var result = value
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "\"", with: "&quot;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    return result
}

// MARK: - Attribute Serialization

/// Serialize element attributes to a string like ` name="value" name2="value2"`.
/// Returns an empty string if there are no attributes.
/// Preserves insertion order from the OrderedAttributes.
private func stringifyAttributes(_ attributes: OrderedAttributes) -> String {
    guard !attributes.isEmpty else { return "" }

    var result = ""
    for (key, value) in attributes {
        if value == noValueAttrSentinel {
            // No-value / boolean attribute (e.g., `data-icon`)
            result += " \(key)"
        } else {
            let encodedValue = encodeAttributeValue(value)
            result += " \(key)=\"\(encodedValue)\""
        }
    }
    return result
}

// MARK: - Public API

/// Convert an XastRoot AST back to an SVG string.
///
/// - Parameters:
///   - root: The root node of the AST.
///   - options: Stringification options controlling formatting and output style.
/// - Returns: The serialized SVG string.
public func stringifySvg(_ root: XastRoot, options: StringifyOptions = .init()) -> String {
    let eol = options.eol.string
    let indentStr: String
    if options.indent < 0 {
        indentStr = "\t"
    } else {
        indentStr = String(repeating: " ", count: options.indent)
    }

    var result = ""
    // textContext tracks whether we are inside a text element,
    // in which case pretty-printing whitespace should be suppressed.
    var textContext: XastElement? = nil

    func createIndent(_ depth: Int) -> String {
        guard options.pretty, depth > 0 else { return "" }
        return String(repeating: indentStr, count: depth)
    }

    func stringifyNode(_ child: XastChild, depth: Int) {
        switch child {
        case .doctype(let node):
            result += "<!DOCTYPE"
            if !node.name.isEmpty {
                result += " \(node.name)"
            }
            if !node.doctype.isEmpty {
                result += " \(node.doctype)"
            }
            result += ">"
            if options.pretty && textContext == nil {
                result += eol
            }

        case .instruction(let node):
            result += "<?\(node.name)"
            if !node.value.isEmpty {
                result += " \(node.value)"
            }
            result += "?>"
            if options.pretty && textContext == nil {
                result += eol
            }

        case .comment(let node):
            result += "<!--\(node.value)-->"
            if options.pretty && textContext == nil {
                result += eol
            }

        case .cdata(let node):
            if options.pretty && textContext == nil {
                result += createIndent(depth)
            }
            result += "<![CDATA[\(node.value)]]>"
            if options.pretty && textContext == nil {
                result += eol
            }

        case .text(let node):
            if options.pretty && textContext == nil {
                result += createIndent(depth)
            }
            result += encodeTextEntities(node.value)
            if options.pretty && textContext == nil {
                result += eol
            }

        case .element(let node):
            let isTextEl = textElements.contains(node.name)

            // Add indentation before setting text context, so the text
            // element's opening tag itself gets properly indented.
            if options.pretty && textContext == nil {
                result += createIndent(depth)
            }

            // If we enter a text element, set the text context
            if isTextEl && textContext == nil {
                textContext = node
            }

            let attrs = stringifyAttributes(node.attributes)

            if node.children.isEmpty {
                if options.useShortTags {
                    result += "<\(node.name)\(attrs)/>"
                } else {
                    result += "<\(node.name)\(attrs)></\(node.name)>"
                }
            } else {
                result += "<\(node.name)\(attrs)>"

                if options.pretty && textContext == nil {
                    result += eol
                }

                for childNode in node.children {
                    stringifyNode(childNode, depth: depth + 1)
                }

                if options.pretty && textContext == nil {
                    result += createIndent(depth)
                }

                result += "</\(node.name)>"
            }

            // If this element established the text context, clear it
            if textContext === node {
                textContext = nil
            }

            if options.pretty && textContext == nil {
                result += eol
            }
        }
    }

    for child in root.children {
        stringifyNode(child, depth: 0)
    }

    // In pretty mode, each node appends a trailing newline;
    // remove the extra trailing eol unless finalNewline is requested.
    if options.pretty && !options.finalNewline && result.hasSuffix(eol) {
        result.removeLast(eol.count)
    }

    if options.finalNewline && !result.hasSuffix(eol) {
        result += eol
    }

    return result
}
