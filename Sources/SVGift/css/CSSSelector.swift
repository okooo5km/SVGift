// CSSSelector.swift
// CSS selector AST, parsing, and specificity calculation
// okooo5km(十里)

import Foundation

// MARK: - Selector AST

/// A component of a compound selector
public enum SimpleSelectorComponent: Equatable {
    case type(String)                                          // element type, e.g. "rect"
    case universal                                             // *
    case id(String)                                            // #foo
    case className(String)                                     // .bar
    case attribute(name: String, op: AttrOp?, value: String?)  // [attr], [attr=val], etc.
    case pseudoClass(name: String, argument: String?)          // :hover, :nth-child(2n+1)
    case pseudoElement(String)                                 // ::before
}

/// Attribute selector operators
public enum AttrOp: String, Equatable {
    case eq = "="          // [attr=val]
    case includes = "~="   // [attr~=val]
    case dashMatch = "|="  // [attr|=val]
    case prefix = "^="     // [attr^=val]
    case suffix = "$="     // [attr$=val]
    case substring = "*="  // [attr*=val]
}

/// Combinators between compound selectors
public enum Combinator: Equatable {
    case descendant        // space
    case child             // >
    case adjacentSibling   // +
    case generalSibling    // ~
}

/// A compound selector: a sequence of simple selectors with no combinator
public struct CompoundSelector: Equatable {
    public var components: [SimpleSelectorComponent]

    public init(components: [SimpleSelectorComponent] = []) {
        self.components = components
    }
}

/// A complex selector: compound selectors linked by combinators
/// A segment in a complex selector: a compound selector followed by an optional combinator
public struct SelectorSegment: Equatable {
    public var compound: CompoundSelector
    public var combinator: Combinator?

    public init(compound: CompoundSelector, combinator: Combinator? = nil) {
        self.compound = compound
        self.combinator = combinator
    }
}

/// Segments are stored left-to-right: [compound, combinator, compound, combinator, ...]
/// The last segment has combinator = nil
public struct ComplexSelector: Equatable {
    public var segments: [SelectorSegment]

    public init(segments: [SelectorSegment]) {
        self.segments = segments
    }
}

/// A selector list (comma-separated selectors)
public struct SelectorList: Equatable {
    public var selectors: [ComplexSelector]

    public init(selectors: [ComplexSelector]) {
        self.selectors = selectors
    }
}

// MARK: - Specificity

/// CSS Specificity (a, b, c)
/// a = ID selectors, b = class/attribute/pseudo-class, c = type/pseudo-element
public struct Specificity: Comparable, Equatable {
    public let a: Int
    public let b: Int
    public let c: Int

    public init(a: Int = 0, b: Int = 0, c: Int = 0) {
        self.a = a
        self.b = b
        self.c = c
    }

    public static func < (lhs: Specificity, rhs: Specificity) -> Bool {
        if lhs.a != rhs.a { return lhs.a < rhs.a }
        if lhs.b != rhs.b { return lhs.b < rhs.b }
        return lhs.c < rhs.c
    }

    public static func + (lhs: Specificity, rhs: Specificity) -> Specificity {
        Specificity(a: lhs.a + rhs.a, b: lhs.b + rhs.b, c: lhs.c + rhs.c)
    }
}

/// Compare two specificities (for sorting). Returns -1, 0, or 1.
public func compareSpecificity(_ a: Specificity, _ b: Specificity) -> Int {
    if a.a != b.a { return a.a < b.a ? -1 : 1 }
    if a.b != b.b { return a.b < b.b ? -1 : 1 }
    if a.c != b.c { return a.c < b.c ? -1 : 1 }
    return 0
}

/// Compute the specificity of a complex selector
public func computeSpecificity(_ selector: ComplexSelector) -> Specificity {
    var spec = Specificity()
    for segment in selector.segments {
        spec = spec + computeCompoundSpecificity(segment.compound)
    }
    return spec
}

/// Compute specificity of a compound selector
private func computeCompoundSpecificity(_ compound: CompoundSelector) -> Specificity {
    var a = 0, b = 0, c = 0
    for component in compound.components {
        switch component {
        case .id:
            a += 1
        case .className, .attribute:
            b += 1
        case .pseudoClass(let name, let arg):
            if name == "not" || name == "is" || name == "has" || name == "where" {
                // :not() and :is() use the specificity of their argument
                if name == "where" {
                    // :where() has zero specificity
                } else if let arg = arg, let innerList = try? parseSelector(arg) {
                    // Use the highest specificity among alternatives
                    var maxSpec = Specificity()
                    for inner in innerList.selectors {
                        let s = computeSpecificity(inner)
                        if s > maxSpec { maxSpec = s }
                    }
                    a += maxSpec.a
                    b += maxSpec.b
                    c += maxSpec.c
                }
            } else {
                b += 1
            }
        case .type(let name):
            if name != "*" {
                c += 1
            }
        case .universal:
            break // universal selector has zero specificity
        case .pseudoElement:
            c += 1
        }
    }
    return Specificity(a: a, b: b, c: c)
}

// MARK: - Selector Parsing

public enum CSSSelectorParseError: Error {
    case unexpectedEnd
    case unexpectedCharacter(Character, Int)
    case invalidSelector(String)
}

/// Parse a CSS selector string into a SelectorList
public func parseSelector(_ text: String) throws -> SelectorList {
    let parser = SelectorParser(text)
    return try parser.parseSelectorList()
}

/// Recursive descent parser for CSS selectors
private class SelectorParser {
    let chars: [Character]
    var pos: Int

    init(_ text: String) {
        self.chars = Array(text)
        self.pos = 0
    }

    var isAtEnd: Bool { pos >= chars.count }

    func peek() -> Character? {
        guard pos < chars.count else { return nil }
        return chars[pos]
    }

    @discardableResult
    func advance() -> Character? {
        guard pos < chars.count else { return nil }
        let ch = chars[pos]
        pos += 1
        return ch
    }

    func skipWhitespace() {
        while pos < chars.count && chars[pos].isWhitespace {
            pos += 1
        }
    }

    func parseSelectorList() throws -> SelectorList {
        var selectors: [ComplexSelector] = []

        skipWhitespace()
        if isAtEnd {
            throw CSSSelectorParseError.invalidSelector("empty selector")
        }

        selectors.append(try parseComplexSelector())

        while !isAtEnd {
            skipWhitespace()
            if isAtEnd { break }
            if peek() == "," {
                advance()
                skipWhitespace()
                selectors.append(try parseComplexSelector())
            } else {
                break
            }
        }

        return SelectorList(selectors: selectors)
    }

    func parseComplexSelector() throws -> ComplexSelector {
        var segments: [SelectorSegment] = []

        skipWhitespace()
        var currentCompound = try parseCompoundSelector()

        while true {
            let hadWhitespace = skipAndCheckWhitespace()
            if isAtEnd || peek() == "," || peek() == ")" {
                segments.append(SelectorSegment(compound: currentCompound, combinator: nil))
                break
            }

            // Determine combinator
            let combinator: Combinator?
            if let ch = peek() {
                switch ch {
                case ">":
                    advance()
                    skipWhitespace()
                    combinator = .child
                case "+":
                    advance()
                    skipWhitespace()
                    combinator = .adjacentSibling
                case "~":
                    advance()
                    skipWhitespace()
                    combinator = .generalSibling
                default:
                    combinator = hadWhitespace ? .descendant : nil
                }
            } else {
                combinator = nil
            }

            guard let combinator = combinator else {
                segments.append(SelectorSegment(compound: currentCompound, combinator: nil))
                break
            }

            segments.append(SelectorSegment(compound: currentCompound, combinator: combinator))
            currentCompound = try parseCompoundSelector()
        }

        if segments.isEmpty {
            segments.append(SelectorSegment(compound: currentCompound, combinator: nil))
        }

        return ComplexSelector(segments: segments)
    }

    private func skipAndCheckWhitespace() -> Bool {
        let oldPos = pos
        skipWhitespace()
        return pos > oldPos
    }

    func parseCompoundSelector() throws -> CompoundSelector {
        var components: [SimpleSelectorComponent] = []

        skipWhitespace()

        // Optional type selector or universal at the start
        if let ch = peek() {
            if ch == "*" {
                advance()
                components.append(.universal)
            } else if ch.isLetter || ch == "-" || ch == "_" {
                let name = readIdentifier()
                if !name.isEmpty {
                    components.append(.type(name))
                }
            }
        }

        // Remaining simple selectors: #, ., [, :
        while !isAtEnd {
            guard let ch = peek() else { break }
            switch ch {
            case "#":
                advance()
                let name = readIdentifier()
                components.append(.id(name))
            case ".":
                advance()
                let name = readIdentifier()
                components.append(.className(name))
            case "[":
                let attr = try parseAttributeSelector()
                components.append(attr)
            case ":":
                advance()
                if peek() == ":" {
                    advance()
                    let name = readIdentifier()
                    components.append(.pseudoElement(name))
                } else {
                    let pseudo = try parsePseudoClass()
                    components.append(pseudo)
                }
            default:
                // End of compound selector
                return CompoundSelector(components: components)
            }
        }

        return CompoundSelector(components: components)
    }

    func readIdentifier() -> String {
        var result = ""
        while pos < chars.count {
            let ch = chars[pos]
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" {
                result.append(ch)
                pos += 1
            } else if ch == "\\" && pos + 1 < chars.count {
                // CSS escape
                pos += 1
                result.append(chars[pos])
                pos += 1
            } else {
                break
            }
        }
        return result
    }

    func parseAttributeSelector() throws -> SimpleSelectorComponent {
        advance() // skip '['
        skipWhitespace()

        let name = readIdentifier()
        skipWhitespace()

        if isAtEnd {
            throw CSSSelectorParseError.unexpectedEnd
        }

        if peek() == "]" {
            advance()
            return .attribute(name: name, op: nil, value: nil)
        }

        // Read operator
        let op: AttrOp
        guard let opChar = peek() else {
            throw CSSSelectorParseError.unexpectedEnd
        }

        switch opChar {
        case "=":
            advance()
            op = .eq
        case "~":
            advance()
            guard peek() == "=" else {
                throw CSSSelectorParseError.unexpectedCharacter(peek() ?? "\0", pos)
            }
            advance()
            op = .includes
        case "|":
            advance()
            guard peek() == "=" else {
                throw CSSSelectorParseError.unexpectedCharacter(peek() ?? "\0", pos)
            }
            advance()
            op = .dashMatch
        case "^":
            advance()
            guard peek() == "=" else {
                throw CSSSelectorParseError.unexpectedCharacter(peek() ?? "\0", pos)
            }
            advance()
            op = .prefix
        case "$":
            advance()
            guard peek() == "=" else {
                throw CSSSelectorParseError.unexpectedCharacter(peek() ?? "\0", pos)
            }
            advance()
            op = .suffix
        case "*":
            advance()
            guard peek() == "=" else {
                throw CSSSelectorParseError.unexpectedCharacter(peek() ?? "\0", pos)
            }
            advance()
            op = .substring
        default:
            throw CSSSelectorParseError.unexpectedCharacter(opChar, pos)
        }

        skipWhitespace()

        // Read value (quoted or unquoted)
        let value: String
        if let q = peek(), q == "'" || q == "\"" {
            value = readQuotedString(q)
        } else {
            value = readIdentifier()
        }

        skipWhitespace()

        // Optional 'i' or 's' flag (case sensitivity)
        if let f = peek(), f == "i" || f == "I" || f == "s" || f == "S" {
            advance()
            skipWhitespace()
        }

        if peek() == "]" {
            advance()
        }

        return .attribute(name: name, op: op, value: value)
    }

    func readQuotedString(_ quote: Character) -> String {
        advance() // skip opening quote
        var result = ""
        while pos < chars.count {
            let ch = chars[pos]
            if ch == "\\" && pos + 1 < chars.count {
                pos += 1
                result.append(chars[pos])
                pos += 1
            } else if ch == quote {
                pos += 1
                return result
            } else {
                result.append(ch)
                pos += 1
            }
        }
        return result
    }

    func parsePseudoClass() throws -> SimpleSelectorComponent {
        let name = readIdentifier()

        // Check for functional pseudo-class
        if peek() == "(" {
            advance() // skip '('
            var depth = 1
            var arg = ""
            while pos < chars.count && depth > 0 {
                let ch = chars[pos]
                if ch == "(" {
                    depth += 1
                    arg.append(ch)
                } else if ch == ")" {
                    depth -= 1
                    if depth > 0 {
                        arg.append(ch)
                    }
                } else {
                    arg.append(ch)
                }
                pos += 1
            }
            return .pseudoClass(name: name, argument: arg.trimmingCharacters(in: .whitespaces))
        }

        return .pseudoClass(name: name, argument: nil)
    }
}
