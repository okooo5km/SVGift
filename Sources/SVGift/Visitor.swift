// Visitor.swift
// Visitor pattern types for AST traversal
// okooo5km(十里)

/// Action returned by visitor enter callbacks to control traversal
public enum VisitAction {
    /// Continue traversal into children
    case `continue`
    /// Skip children traversal (like visitSkip in SVGO)
    case skip
}

/// Enter/exit callbacks for a specific node type
public struct VisitorCallbacks<Node> {
    public var enter: ((_ node: Node, _ parent: XastParent) -> VisitAction)?
    public var exit: ((_ node: Node, _ parent: XastParent) -> Void)?

    public init(
        enter: ((_ node: Node, _ parent: XastParent) -> VisitAction)? = nil,
        exit: ((_ node: Node, _ parent: XastParent) -> Void)? = nil
    ) {
        self.enter = enter
        self.exit = exit
    }
}

/// Visitor containing optional callbacks for each AST node type
public struct Visitor {
    public var root: VisitorCallbacks<XastRoot>?
    public var element: VisitorCallbacks<XastElement>?
    public var text: VisitorCallbacks<XastText>?
    public var comment: VisitorCallbacks<XastComment>?
    public var cdata: VisitorCallbacks<XastCdata>?
    public var doctype: VisitorCallbacks<XastDoctype>?
    public var instruction: VisitorCallbacks<XastInstruction>?

    public init(
        root: VisitorCallbacks<XastRoot>? = nil,
        element: VisitorCallbacks<XastElement>? = nil,
        text: VisitorCallbacks<XastText>? = nil,
        comment: VisitorCallbacks<XastComment>? = nil,
        cdata: VisitorCallbacks<XastCdata>? = nil,
        doctype: VisitorCallbacks<XastDoctype>? = nil,
        instruction: VisitorCallbacks<XastInstruction>? = nil
    ) {
        self.root = root
        self.element = element
        self.text = text
        self.comment = comment
        self.cdata = cdata
        self.doctype = doctype
        self.instruction = instruction
    }
}
