// removeMetadata.swift
// Plugin to remove <metadata> elements from SVG
// okooo5km(十里)

/// Remove `<metadata>` elements.
///
/// https://www.w3.org/TR/SVG11/metadata.html
///
/// - Example input:
///   `<metadata>...</metadata>`
public func makeRemoveMetadataPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeMetadata") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    if node.name == "metadata" {
                        detachNodeFromParent(.element(node), from: parent)
                    }
                    return .continue
                }
            )
        )
    }
}
