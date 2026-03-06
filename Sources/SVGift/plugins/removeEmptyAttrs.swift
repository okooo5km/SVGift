// removeEmptyAttrs.swift
// Plugin to remove attributes with empty values
// okooo5km(十里)

/// Conditional processing attributes that must be preserved even when empty,
/// because an empty value prevents elements from rendering (per SVG spec).
private let conditionalProcessingAttrs: Set<String> = [
    "requiredExtensions",
    "requiredFeatures",
    "systemLanguage",
]

/// Remove attributes with empty values.
///
/// Empty conditional processing attributes (`requiredFeatures`,
/// `requiredExtensions`, `systemLanguage`) are always preserved because
/// removing them would change rendering behavior.
public func makeRemoveEmptyAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeEmptyAttrs") { _, _, _ in
        Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    for (key, value) in node.attributes {
                        if value.isEmpty && !conditionalProcessingAttrs.contains(key) {
                            node.attributes.removeValue(forKey: key)
                        }
                    }
                    return .continue
                }
            )
        )
    }
}
