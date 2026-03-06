// AttributeOrderScanner.swift
// Pre-scan XML to extract attribute order before XMLParser processing
// okooo5km(十里)

/// Represents a scanned element's attribute information
struct ScannedElement {
    /// The tag name of the element
    let tagName: String
    /// Attribute names in their original source order
    let attributeNames: [String]
    /// Attributes that XMLParser may discard (e.g. empty xmlns declarations)
    let rescuedAttributes: [(name: String, value: String)]
    /// Raw attribute values (entity-decoded but NOT whitespace-normalized).
    /// Used to override XMLParser's attribute value normalization (tab/newline → space).
    let rawAttributeValues: [String: String]
}

/// Scan an XML string to extract attribute order for each element.
///
/// Uses a single-pass O(n) state machine that tracks tag names and attribute
/// names in source order. This allows reconstructing original attribute order
/// after XMLParser (which returns an unordered dictionary) processes the document.
///
/// - Parameter xml: The XML string to scan
/// - Returns: An array of `ScannedElement` in document order
func scanAttributeOrder(from xml: String) -> [ScannedElement] {
    var results: [ScannedElement] = []

    enum State {
        case text
        case tagOpen          // just saw '<'
        case tagName          // reading tag name
        case closingTag       // inside </...>
        case afterTagName     // after tag name, before attributes or '>'
        case attrName         // reading attribute name
        case afterAttrName    // after attr name, looking for '=' or next attr
        case beforeAttrValue  // saw '=', expecting quote
        case attrValueDQ      // inside double-quoted value
        case attrValueSQ      // inside single-quoted value
        case commentOrSpecial // saw '<!'
        case comment1         // saw '<!-'
        case comment          // inside <!-- ... -->
        case commentEnd1      // saw '-' inside comment
        case commentEnd2      // saw '--' inside comment
        case cdata1           // saw '<![' ...
        case cdata            // inside <![CDATA[ ... ]]>
        case cdataEnd1        // saw ']' in CDATA
        case cdataEnd2        // saw ']]' in CDATA
        case pi               // inside <?...?>
        case piEnd            // saw '?' in PI
        case doctype          // inside <!DOCTYPE ...>
    }

    var state = State.text
    var tagNameBuf = ""
    var attrNameBuf = ""
    var attrValueBuf = ""
    var currentAttrNames: [String] = []
    var currentRescued: [(name: String, value: String)] = []
    var currentRawValues: [String: String] = [:]
    var isClosingTag = false
    var cdataPrefix = ""    // tracks chars after '<![' to detect 'CDATA['
    var doctypeBracketDepth = 0

    let chars = Array(xml.unicodeScalars)
    let count = chars.count
    var i = 0

    func isNameStartChar(_ c: Unicode.Scalar) -> Bool {
        // XML name start characters (simplified): letters, '_', ':'
        c == "_" || c == ":" ||
        (c >= "A" && c <= "Z") ||
        (c >= "a" && c <= "z") ||
        c.value > 0x7F  // non-ASCII
    }

    func isNameChar(_ c: Unicode.Scalar) -> Bool {
        isNameStartChar(c) || c == "-" || c == "." ||
        (c >= "0" && c <= "9")
    }

    func decodeXMLEntities(_ s: String) -> String {
        s.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    func finishElement() {
        guard !isClosingTag else { return }
        // Determine rescued attributes: xmlns:* with empty value
        var rescued: [(name: String, value: String)] = []
        rescued.append(contentsOf: currentRescued)
        results.append(ScannedElement(
            tagName: tagNameBuf,
            attributeNames: currentAttrNames,
            rescuedAttributes: rescued,
            rawAttributeValues: currentRawValues
        ))
    }

    func finishAttribute() {
        if !attrNameBuf.isEmpty {
            currentAttrNames.append(attrNameBuf)
            let decodedValue = decodeXMLEntities(attrValueBuf)
            // Store raw value (entity-decoded but whitespace-preserved)
            currentRawValues[attrNameBuf] = decodedValue
            // Check if this is an attribute XMLParser might discard
            if attrNameBuf.hasPrefix("xmlns:") && decodedValue.isEmpty {
                currentRescued.append((name: attrNameBuf, value: decodedValue))
            }
        }
        attrNameBuf = ""
        attrValueBuf = ""
    }

    while i < count {
        let c = chars[i]

        switch state {
        case .text:
            if c == "<" {
                state = .tagOpen
            }

        case .tagOpen:
            if c == "/" {
                isClosingTag = true
                state = .closingTag
            } else if c == "!" {
                state = .commentOrSpecial
            } else if c == "?" {
                state = .pi
            } else if isNameStartChar(c) {
                isClosingTag = false
                tagNameBuf = String(c)
                currentAttrNames = []
                currentRescued = []
                currentRawValues = [:]
                state = .tagName
            } else {
                state = .text
            }

        case .tagName:
            if isNameChar(c) {
                tagNameBuf.append(Character(c))
            } else if c == ">" {
                finishElement()
                state = .text
            } else if c == "/" {
                // self-closing: check next char
                if i + 1 < count && chars[i + 1] == ">" {
                    finishElement()
                    i += 1
                    state = .text
                } else {
                    state = .afterTagName
                }
            } else {
                // whitespace -> move to after tag name
                state = .afterTagName
            }

        case .closingTag:
            if c == ">" {
                state = .text
            }

        case .afterTagName:
            if c == ">" {
                finishElement()
                state = .text
            } else if c == "/" {
                if i + 1 < count && chars[i + 1] == ">" {
                    finishElement()
                    i += 1
                    state = .text
                }
            } else if isNameStartChar(c) {
                attrNameBuf = String(c)
                attrValueBuf = ""
                state = .attrName
            }
            // else: whitespace, skip

        case .attrName:
            if isNameChar(c) {
                attrNameBuf.append(Character(c))
            } else if c == "=" {
                state = .beforeAttrValue
            } else if c == ">" {
                // boolean attribute (no value)
                finishAttribute()
                finishElement()
                state = .text
            } else if c == "/" {
                finishAttribute()
                if i + 1 < count && chars[i + 1] == ">" {
                    finishElement()
                    i += 1
                    state = .text
                } else {
                    state = .afterTagName
                }
            } else {
                // whitespace after attr name without '=' -> boolean attribute
                state = .afterAttrName
            }

        case .afterAttrName:
            if c == "=" {
                state = .beforeAttrValue
            } else if c == ">" {
                finishAttribute()
                finishElement()
                state = .text
            } else if c == "/" {
                finishAttribute()
                if i + 1 < count && chars[i + 1] == ">" {
                    finishElement()
                    i += 1
                    state = .text
                } else {
                    state = .afterTagName
                }
            } else if isNameStartChar(c) {
                // Next attribute starts, the previous was a boolean attr
                finishAttribute()
                attrNameBuf = String(c)
                attrValueBuf = ""
                state = .attrName
            }
            // else: whitespace, stay in afterAttrName

        case .beforeAttrValue:
            if c == "\"" {
                attrValueBuf = ""
                state = .attrValueDQ
            } else if c == "'" {
                attrValueBuf = ""
                state = .attrValueSQ
            }
            // else: skip whitespace before value

        case .attrValueDQ:
            if c == "\"" {
                finishAttribute()
                state = .afterTagName
            } else {
                attrValueBuf.append(Character(c))
            }

        case .attrValueSQ:
            if c == "'" {
                finishAttribute()
                state = .afterTagName
            } else {
                attrValueBuf.append(Character(c))
            }

        case .commentOrSpecial:
            if c == "-" {
                state = .comment1
            } else if c == "[" {
                cdataPrefix = ""
                state = .cdata1
            } else if c == "D" || c == "d" {
                // DOCTYPE
                doctypeBracketDepth = 0
                state = .doctype
            } else {
                state = .text
            }

        case .comment1:
            if c == "-" {
                state = .comment
            } else {
                state = .text
            }

        case .comment:
            if c == "-" {
                state = .commentEnd1
            }

        case .commentEnd1:
            if c == "-" {
                state = .commentEnd2
            } else {
                state = .comment
            }

        case .commentEnd2:
            if c == ">" {
                state = .text
            } else if c == "-" {
                // stay in commentEnd2 (multiple dashes)
            } else {
                state = .comment
            }

        case .cdata1:
            cdataPrefix.append(Character(c))
            if cdataPrefix == "CDATA[" {
                state = .cdata
            } else if !"CDATA[".hasPrefix(cdataPrefix) {
                // Not CDATA, treat as some other <![...
                state = .text
            }

        case .cdata:
            if c == "]" {
                state = .cdataEnd1
            }

        case .cdataEnd1:
            if c == "]" {
                state = .cdataEnd2
            } else {
                state = .cdata
            }

        case .cdataEnd2:
            if c == ">" {
                state = .text
            } else if c == "]" {
                // stay (extra ']')
            } else {
                state = .cdata
            }

        case .pi:
            if c == "?" {
                state = .piEnd
            }

        case .piEnd:
            if c == ">" {
                state = .text
            } else {
                state = .pi
            }

        case .doctype:
            if c == "[" {
                doctypeBracketDepth += 1
            } else if c == "]" {
                doctypeBracketDepth -= 1
            } else if c == ">" && doctypeBracketDepth <= 0 {
                state = .text
            }
        }

        i += 1
    }

    return results
}
