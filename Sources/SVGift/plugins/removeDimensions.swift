// removeDimensions.swift
// Plugin to remove width/height in presence of viewBox
// okooo5km(十里)

/// Remove width/height attributes and add the viewBox attribute if it's missing.
///
/// If viewBox is already present, width and height are simply removed.
/// If viewBox is absent but width and height are numeric, a viewBox is
/// created from them before removing the dimension attributes.
public func makeRemoveDimensionsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeDimensions") { _, _, _ in
        Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard node.name == "svg" else { return .continue }

                    if node.attributes["viewBox"] != nil {
                        // viewBox exists — just remove width/height
                        node.attributes.removeValue(forKey: "width")
                        node.attributes.removeValue(forKey: "height")
                    } else if let widthStr = node.attributes["width"],
                              let heightStr = node.attributes["height"],
                              let width = Double(widthStr),
                              let height = Double(heightStr) {
                        // Create viewBox from numeric width/height
                        let w = widthStr.contains(".") ? widthStr : String(Int(width))
                        let h = heightStr.contains(".") ? heightStr : String(Int(height))
                        node.attributes["viewBox"] = "0 0 \(w) \(h)"
                        node.attributes.removeValue(forKey: "width")
                        node.attributes.removeValue(forKey: "height")
                    }

                    return .continue
                }
            )
        )
    }
}
