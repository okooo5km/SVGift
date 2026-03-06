// Plugin.swift
// Plugin protocol for SVGO optimization plugins
// okooo5km(十里)

/// Information passed to plugins about the current optimization context
public struct PluginInfo: Sendable {
    /// File path of the SVG being optimized
    public var path: String?
    /// Current multipass iteration count
    public var multipassCount: Int

    public init(path: String? = nil, multipassCount: Int = 0) {
        self.path = path
        self.multipassCount = multipassCount
    }
}

/// Protocol that all SVGO optimization plugins must conform to
public protocol SVGOPlugin {
    /// Unique name identifying this plugin
    var name: String { get }

    /// Create a visitor for traversing the AST.
    /// Returns nil if the plugin has nothing to do for this document.
    func makeVisitor(root: XastRoot, info: PluginInfo) -> Visitor?
}
