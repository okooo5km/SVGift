// removeDoctype.swift
// Plugin to remove DOCTYPE declaration from SVG
// okooo5km(十里)

/// Remove DOCTYPE declaration.
///
/// "Unfortunately the SVG DTDs are a source of so many
/// issues that the SVG WG has decided not to write one
/// for the upcoming SVG 1.2 standard."
/// https://jwatt.org/svg/authoring/#doctype-declaration
///
/// - Example input:
///   `<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "...">`
public func makeRemoveDoctypePlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeDoctype") { _, _, _ in
        return Visitor(
            doctype: VisitorCallbacks<XastDoctype>(
                enter: { node, parent in
                    detachNodeFromParent(.doctype(node), from: parent)
                    return .continue
                }
            )
        )
    }
}
