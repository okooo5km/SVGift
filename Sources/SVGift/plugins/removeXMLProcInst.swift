// removeXMLProcInst.swift
// Plugin to remove XML processing instructions from SVG
// okooo5km(十里)

/// Remove XML Processing Instruction (`<?xml ...?>`).
///
/// Only removes instructions with name "xml"; other processing
/// instructions (e.g. `<?xml-stylesheet ...?>`) are preserved.
///
/// - Example input:
///   `<?xml version="1.0" encoding="utf-8"?>`
public func makeRemoveXMLProcInstPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeXMLProcInst") { _, _, _ in
        return Visitor(
            instruction: VisitorCallbacks<XastInstruction>(
                enter: { node, parent in
                    if node.name == "xml" {
                        detachNodeFromParent(.instruction(node), from: parent)
                    }
                    return .continue
                }
            )
        )
    }
}
