// CSSParser.swift
// CSS declaration and stylesheet parsing (inline tokenizer, no external dependencies)
// okooo5km(十里)

import Foundation

// MARK: - Data Types

/// A single CSS declaration (property: value)
public struct CSSDeclaration: Equatable {
    public let name: String      // property name, lowercased and trimmed
    public let value: String     // raw value string, trimmed
    public let important: Bool

    public init(name: String, value: String, important: Bool = false) {
        self.name = name
        self.value = value
        self.important = important
    }
}

/// A CSS rule (selector + declarations)
public struct CSSRule: Equatable {
    public let selectorText: String
    public var declarations: [CSSDeclaration]

    public init(selectorText: String, declarations: [CSSDeclaration]) {
        self.selectorText = selectorText
        self.declarations = declarations
    }
}

/// A CSS at-rule (@media, etc.)
public struct CSSAtRule: Equatable {
    public let name: String       // e.g. "media"
    public let prelude: String    // e.g. "screen and (max-width: 200px)"
    public var rules: [CSSRule]   // For @media, @supports, @document (nested rules)
    public var rawBody: String?   // For @font-face, @keyframes, @page, @viewport (raw block content)
    public var semicolonTerminated: Bool  // For @charset, @import, @namespace

    public init(name: String, prelude: String, rules: [CSSRule],
                rawBody: String? = nil, semicolonTerminated: Bool = false) {
        self.name = name
        self.prelude = prelude
        self.rules = rules
        self.rawBody = rawBody
        self.semicolonTerminated = semicolonTerminated
    }
}

/// A top-level CSS item in a stylesheet
public enum CSSItem: Equatable {
    case rule(CSSRule)
    case atRule(CSSAtRule)
}

// MARK: - Public API

/// Parse CSS declarations from an inline style attribute value.
/// e.g. "fill: red; stroke: blue" -> [CSSDeclaration]
public func parseCSSDeclarations(_ css: String) -> [CSSDeclaration] {
    var declarations: [CSSDeclaration] = []
    let scanner = CSSScanner(css)

    while !scanner.isAtEnd {
        scanner.skipWhitespaceAndComments()
        if scanner.isAtEnd { break }

        // Read property name (up to ':')
        let propStart = scanner.position
        while !scanner.isAtEnd && scanner.peek() != ":" && scanner.peek() != ";" {
            if scanner.peek() == "/" && scanner.peekNext() == "*" {
                scanner.skipComment()
            } else {
                scanner.advance()
            }
        }

        let propName = scanner.substring(from: propStart).trimmingCharacters(in: .whitespaces)

        if scanner.isAtEnd || scanner.peek() == ";" {
            // No colon found — skip this token
            if !scanner.isAtEnd { scanner.advance() } // skip ';'
            continue
        }

        scanner.advance() // skip ':'

        // Read value (up to ';' or end, respecting strings/parens/comments)
        scanner.skipWhitespace()
        let valueStart = scanner.position
        var parenDepth = 0

        while !scanner.isAtEnd {
            let ch = scanner.peek()
            if ch == "(" {
                parenDepth += 1
                scanner.advance()
            } else if ch == ")" {
                parenDepth = max(0, parenDepth - 1)
                scanner.advance()
            } else if ch == "'" || ch == "\"" {
                scanner.skipString(ch)
            } else if ch == "/" && scanner.peekNext() == "*" {
                scanner.skipComment()
            } else if ch == "\\" {
                scanner.advance() // skip backslash
                if !scanner.isAtEnd { scanner.advance() } // skip escaped char
            } else if ch == ";" && parenDepth == 0 {
                break
            } else {
                scanner.advance()
            }
        }

        var rawValue = scanner.substring(from: valueStart).trimmingCharacters(in: .whitespaces)
        if !scanner.isAtEnd && scanner.peek() == ";" {
            scanner.advance()
        }

        if propName.isEmpty { continue }

        // Check for !important
        var isImportant = false
        let importantPattern = try! NSRegularExpression(pattern: #"\s*!important\s*$"#, options: .caseInsensitive)
        let nsValue = rawValue as NSString
        if let match = importantPattern.firstMatch(in: rawValue, range: NSRange(location: 0, length: nsValue.length)) {
            isImportant = true
            rawValue = nsValue.substring(to: match.range.location).trimmingCharacters(in: .whitespaces)
        }

        declarations.append(CSSDeclaration(
            name: propName.lowercased(),
            value: rawValue,
            important: isImportant
        ))
    }

    return declarations
}

/// Parse a CSS stylesheet string into rules and at-rules.
/// e.g. ".cls { fill: red } @media screen { .cls { stroke: blue } }"
public func parseCSSStylesheet(_ css: String) -> [CSSItem] {
    var items: [CSSItem] = []
    let scanner = CSSScanner(css)

    while !scanner.isAtEnd {
        scanner.skipWhitespaceAndComments()
        if scanner.isAtEnd { break }

        if scanner.peek() == "@" {
            if let atRule = parseAtRule(scanner) {
                items.append(.atRule(atRule))
            }
        } else {
            if let rule = parseRule(scanner) {
                items.append(.rule(rule))
            }
        }
    }

    return items
}

/// Serialize CSS declarations back to a string.
/// e.g. [CSSDeclaration(name: "fill", value: "red")] -> "fill:red"
public func serializeCSSDeclarations(_ decls: [CSSDeclaration]) -> String {
    return decls.map { decl in
        let imp = decl.important ? "!important" : ""
        return "\(decl.name):\(decl.value)\(imp)"
    }.joined(separator: ";")
}

// MARK: - Internal Parsing

private func parseRule(_ scanner: CSSScanner) -> CSSRule? {
    scanner.skipWhitespaceAndComments()
    let selectorStart = scanner.position

    // Read selector (up to '{')
    var braceDepth = 0
    while !scanner.isAtEnd {
        let ch = scanner.peek()
        if ch == "{" && braceDepth == 0 {
            break
        } else if ch == "{" {
            braceDepth += 1
            scanner.advance()
        } else if ch == "}" {
            braceDepth -= 1
            scanner.advance()
        } else if ch == "'" || ch == "\"" {
            scanner.skipString(ch)
        } else if ch == "/" && scanner.peekNext() == "*" {
            scanner.skipComment()
        } else {
            scanner.advance()
        }
    }

    let selector = scanner.substring(from: selectorStart).trimmingCharacters(in: .whitespaces)

    if scanner.isAtEnd { return nil }
    scanner.advance() // skip '{'

    // Read block content (up to matching '}')
    let blockContent = readBlock(scanner)
    let declarations = parseCSSDeclarations(blockContent)

    if selector.isEmpty { return nil }

    return CSSRule(selectorText: selector, declarations: declarations)
}

private func parseAtRule(_ scanner: CSSScanner) -> CSSAtRule? {
    scanner.advance() // skip '@'

    // Read at-rule name
    let nameStart = scanner.position
    while !scanner.isAtEnd && !scanner.peek().isWhitespace && scanner.peek() != "{" && scanner.peek() != ";" {
        scanner.advance()
    }
    let name = scanner.substring(from: nameStart)

    // Read prelude (up to '{' or ';')
    scanner.skipWhitespace()
    let preludeStart = scanner.position
    while !scanner.isAtEnd && scanner.peek() != "{" && scanner.peek() != ";" {
        if scanner.peek() == "'" || scanner.peek() == "\"" {
            scanner.skipString(scanner.peek())
        } else if scanner.peek() == "(" {
            // Read balanced parens (for url(), etc.)
            scanner.advance()
            var depth = 1
            while !scanner.isAtEnd && depth > 0 {
                if scanner.peek() == "(" { depth += 1 }
                else if scanner.peek() == ")" { depth -= 1; if depth == 0 { scanner.advance(); break } }
                else if scanner.peek() == "'" || scanner.peek() == "\"" { scanner.skipString(scanner.peek()); continue }
                scanner.advance()
            }
        } else {
            scanner.advance()
        }
    }
    let prelude = scanner.substring(from: preludeStart).trimmingCharacters(in: .whitespaces)

    // Semicolon-terminated @-rules: @charset, @import, @namespace
    let semicolonRules: Set<String> = ["charset", "import", "namespace"]
    if semicolonRules.contains(name) || (scanner.peek() == ";" && !scanner.isAtEnd) {
        if !scanner.isAtEnd && scanner.peek() == ";" {
            scanner.advance() // skip ';'
        }
        return CSSAtRule(name: name, prelude: prelude, rules: [], semicolonTerminated: true)
    }

    if scanner.isAtEnd { return nil }
    scanner.advance() // skip '{'

    // Determine if this @-rule has nested CSS rules or raw content
    let rawBodyRules: Set<String> = [
        "font-face", "viewport", "page",
        "keyframes", "-webkit-keyframes", "-o-keyframes", "-moz-keyframes",
    ]

    if rawBodyRules.contains(name) {
        // Store raw block content (declarations or keyframe blocks)
        let rawBody = readBlock(scanner)
        return CSSAtRule(name: name, prelude: prelude, rules: [], rawBody: rawBody)
    }

    // Rules-based @-rules: @media, @supports, @document, etc.
    let blockStartPos = scanner.position

    var depth = 1
    while !scanner.isAtEnd && depth > 0 {
        let ch = scanner.peek()
        if ch == "{" {
            depth += 1
            scanner.advance()
        } else if ch == "}" {
            depth -= 1
            if depth == 0 { break }
            scanner.advance()
        } else if ch == "'" || ch == "\"" {
            scanner.skipString(ch)
        } else if ch == "/" && scanner.peekNext() == "*" {
            scanner.skipComment()
        } else {
            scanner.advance()
        }
    }

    // Parse the inner block as mini-stylesheet of rules
    let innerCSS = scanner.substring(from: blockStartPos)
    var rules: [CSSRule] = []
    let innerScanner = CSSScanner(innerCSS)
    while !innerScanner.isAtEnd {
        innerScanner.skipWhitespaceAndComments()
        if innerScanner.isAtEnd { break }
        if let rule = parseRule(innerScanner) {
            rules.append(rule)
        }
    }

    if !scanner.isAtEnd {
        scanner.advance() // skip closing '}'
    }

    return CSSAtRule(name: name, prelude: prelude, rules: rules)
}

/// Read content inside balanced braces, returning the inner content.
/// Assumes the opening '{' has already been consumed.
private func readBlock(_ scanner: CSSScanner) -> String {
    let start = scanner.position
    var depth = 1

    while !scanner.isAtEnd && depth > 0 {
        let ch = scanner.peek()
        if ch == "{" {
            depth += 1
            scanner.advance()
        } else if ch == "}" {
            depth -= 1
            if depth == 0 {
                let content = scanner.substring(from: start)
                scanner.advance() // skip closing '}'
                return content
            }
            scanner.advance()
        } else if ch == "'" || ch == "\"" {
            scanner.skipString(ch)
        } else if ch == "/" && scanner.peekNext() == "*" {
            scanner.skipComment()
        } else if ch == "\\" {
            scanner.advance()
            if !scanner.isAtEnd { scanner.advance() }
        } else {
            scanner.advance()
        }
    }

    return scanner.substring(from: start)
}

// MARK: - CSS Scanner (character-level)

/// Simple character scanner for CSS parsing
class CSSScanner {
    let source: [Character]
    var position: Int

    var isAtEnd: Bool { position >= source.count }

    init(_ string: String) {
        self.source = Array(string)
        self.position = 0
    }

    func peek() -> Character {
        guard position < source.count else { return "\0" }
        return source[position]
    }

    func peekNext() -> Character {
        guard position + 1 < source.count else { return "\0" }
        return source[position + 1]
    }

    @discardableResult
    func advance() -> Character {
        let ch = source[position]
        position += 1
        return ch
    }

    func substring(from start: Int) -> String {
        let end = min(position, source.count)
        guard start < end else { return "" }
        return String(source[start..<end])
    }

    func skipWhitespace() {
        while !isAtEnd && peek().isWhitespace {
            advance()
        }
    }

    func skipWhitespaceAndComments() {
        while !isAtEnd {
            if peek().isWhitespace {
                advance()
            } else if peek() == "/" && peekNext() == "*" {
                skipComment()
            } else {
                break
            }
        }
    }

    func skipComment() {
        guard peek() == "/" && peekNext() == "*" else { return }
        advance() // /
        advance() // *
        while !isAtEnd {
            if peek() == "*" && peekNext() == "/" {
                advance() // *
                advance() // /
                return
            }
            advance()
        }
    }

    func skipString(_ quote: Character) {
        advance() // skip opening quote
        while !isAtEnd {
            let ch = peek()
            if ch == "\\" {
                advance()
                if !isAtEnd { advance() }
            } else if ch == quote {
                advance()
                return
            } else if ch == "\n" || ch == "\r" {
                // Unterminated string
                return
            } else {
                advance()
            }
        }
    }
}
