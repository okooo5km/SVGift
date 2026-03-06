// XastNode.swift
// SVG AST (XAST) data model based on SVGO's xast types
// okooo5km(十里)

// MARK: - Leaf Node Classes

/// Text node containing character data
public final class XastText: @unchecked Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

/// Comment node (<!-- ... -->)
public final class XastComment: @unchecked Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

/// CDATA section node (<![CDATA[ ... ]]>)
public final class XastCdata: @unchecked Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

/// DOCTYPE declaration node (<!DOCTYPE ...>)
public final class XastDoctype: @unchecked Sendable {
    public let name: String
    public let doctype: String

    public init(name: String, doctype: String) {
        self.name = name
        self.doctype = doctype
    }
}

/// Processing instruction node (<?name value?>)
public final class XastInstruction: @unchecked Sendable {
    public let name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - Child Node Enum

/// Union type representing any child node in the AST
public enum XastChild {
    case element(XastElement)
    case text(XastText)
    case comment(XastComment)
    case cdata(XastCdata)
    case doctype(XastDoctype)
    case instruction(XastInstruction)
}

// MARK: - Parent Node Types

/// Represents a parent node that can contain children (root or element)
public enum XastParent {
    case root(XastRoot)
    case element(XastElement)

    /// Access the children array of the parent node
    public var children: [XastChild] {
        get {
            switch self {
            case .root(let root): return root.children
            case .element(let element): return element.children
            }
        }
        set {
            switch self {
            case .root(let root): root.children = newValue
            case .element(let element): element.children = newValue
            }
        }
    }
}

/// Root node of the SVG AST
public final class XastRoot: @unchecked Sendable {
    public var children: [XastChild] = []

    public init(children: [XastChild] = []) {
        self.children = children
    }
}

/// Element node with tag name, attributes, and children
public final class XastElement: @unchecked Sendable {
    public var name: String
    public var attributes: OrderedAttributes
    public var children: [XastChild]
    /// Cached parsed path data (matches JS SVGO's node.pathJS behavior).
    /// Used to pass transformed path data between applyTransforms and convertPathData
    /// without serialize/reparse roundtrip precision loss.
    public var pathJS: [PathDataItem]?

    public init(
        name: String,
        attributes: OrderedAttributes = [:],
        children: [XastChild] = []
    ) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }
}

// MARK: - Identity Comparison

extension XastChild {
    /// Check if two XastChild values refer to the same underlying object
    public func isIdentical(to other: XastChild) -> Bool {
        switch (self, other) {
        case (.element(let a), .element(let b)): return a === b
        case (.text(let a), .text(let b)): return a === b
        case (.comment(let a), .comment(let b)): return a === b
        case (.cdata(let a), .cdata(let b)): return a === b
        case (.doctype(let a), .doctype(let b)): return a === b
        case (.instruction(let a), .instruction(let b)): return a === b
        default: return false
        }
    }
}

// MARK: - Utility Functions

/// Remove a node from its parent's children array by identity
public func detachNodeFromParent(_ node: XastChild, from parent: XastParent) {
    switch parent {
    case .root(let root):
        root.children.removeAll { $0.isIdentical(to: node) }
    case .element(let element):
        element.children.removeAll { $0.isIdentical(to: node) }
    }
}
