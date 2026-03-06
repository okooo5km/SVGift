// convertEllipseToCircle.swift
// Plugin to convert non-eccentric <ellipse>s to <circle>s
// okooo5km(十里)

/// Convert `<ellipse>` elements to `<circle>` when rx equals ry,
/// or when either rx or ry is `"auto"`.
public func makeConvertEllipseToCirclePlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertEllipseToCircle") { _, _, _ in
        Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard node.name == "ellipse" else { return .continue }

                    let rx = node.attributes["rx"] ?? "0"
                    let ry = node.attributes["ry"] ?? "0"

                    if rx == ry || rx == "auto" || ry == "auto" {
                        node.name = "circle"
                        let radius = (rx == "auto") ? ry : rx
                        node.attributes.removeValue(forKey: "rx")
                        node.attributes.removeValue(forKey: "ry")
                        node.attributes["r"] = radius
                    }

                    return .continue
                }
            )
        )
    }
}
