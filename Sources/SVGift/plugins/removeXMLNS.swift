// removeXMLNS.swift
// Plugin to remove xmlns attribute from root <svg> element
// okooo5km(十里)

/// Remove `xmlns` attribute from the root `<svg>` element.
///
/// This is useful when SVG is embedded inline in HTML, where the
/// `xmlns` attribute is unnecessary.
///
/// - Example:
///   `<svg viewBox="0 0 100 50" xmlns="http://www.w3.org/2000/svg">`
///   becomes `<svg viewBox="0 0 100 50">`
public func makeRemoveXMLNSPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeXMLNS") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if node.name == "svg" {
                        node.attributes["xmlns"] = nil
                    }
                    return .continue
                }
            )
        )
    }
}
