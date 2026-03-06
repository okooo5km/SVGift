// Visit.swift
// Tree traversal engine that applies plugin visitors to the AST
// okooo5km(十里)

// MARK: - Resolved Plugin

/// A plugin resolved with its parameters, ready to be invoked
public struct ResolvedPlugin {
    public let name: String
    public let fn: (XastRoot, [String: String], PluginInfo) -> Visitor?
    public var params: [String: String]

    public init(
        name: String,
        fn: @escaping (XastRoot, [String: String], PluginInfo) -> Visitor?,
        params: [String: String] = [:]
    ) {
        self.name = name
        self.fn = fn
        self.params = params
    }
}

// MARK: - Tree Traversal

/// Check if a child node is still attached to the parent's children array (by identity)
private func isAttached(_ child: XastChild, in children: [XastChild]) -> Bool {
    return children.contains { $0.isIdentical(to: child) }
}

/// Visit all nodes in the AST with the given visitor (depth-first traversal)
public func visit(_ root: XastRoot, visitor: Visitor) {
    let rootParent = XastParent.root(root)

    // Enter root
    let rootAction = visitor.root?.enter?(root, rootParent) ?? .continue
    if rootAction != .skip {
        // Traverse root's children using a snapshot for safe mutation
        let childrenSnapshot = root.children
        for child in childrenSnapshot {
            // Verify the child is still attached before visiting
            guard isAttached(child, in: root.children) else { continue }
            visitChild(child, parent: rootParent, visitor: visitor)
        }
    }

    // Exit root
    visitor.root?.exit?(root, rootParent)
}

/// Recursively visit a child node
private func visitChild(_ child: XastChild, parent: XastParent, visitor: Visitor) {
    switch child {
    case .element(let element):
        visitElement(element, parent: parent, visitor: visitor)
    case .text(let text):
        _ = visitor.text?.enter?(text, parent)
        visitor.text?.exit?(text, parent)
    case .comment(let comment):
        _ = visitor.comment?.enter?(comment, parent)
        visitor.comment?.exit?(comment, parent)
    case .cdata(let cdata):
        _ = visitor.cdata?.enter?(cdata, parent)
        visitor.cdata?.exit?(cdata, parent)
    case .doctype(let doctype):
        _ = visitor.doctype?.enter?(doctype, parent)
        visitor.doctype?.exit?(doctype, parent)
    case .instruction(let instruction):
        _ = visitor.instruction?.enter?(instruction, parent)
        visitor.instruction?.exit?(instruction, parent)
    }
}

/// Visit an element node and its children
private func visitElement(_ element: XastElement, parent: XastParent, visitor: Visitor) {
    // Enter element
    let action = visitor.element?.enter?(element, parent) ?? .continue

    if action != .skip {
        // Check the element is still attached to the parent after enter callback
        let stillAttached = isAttached(.element(element), in: parent.children)
        if stillAttached {
            // Traverse element's children using a snapshot for safe mutation
            let elementParent = XastParent.element(element)
            let childrenSnapshot = element.children
            for child in childrenSnapshot {
                guard isAttached(child, in: element.children) else { continue }
                visitChild(child, parent: elementParent, visitor: visitor)
            }
        }
    }

    // Exit element
    visitor.element?.exit?(element, parent)
}

// MARK: - Plugin Invocation

/// Run all plugins on the AST
public func invokePlugins(
    _ ast: XastRoot,
    info: PluginInfo,
    plugins: [ResolvedPlugin]
) {
    for plugin in plugins {
        if let visitor = plugin.fn(ast, plugin.params, info) {
            visit(ast, visitor: visitor)
        }
    }
}
