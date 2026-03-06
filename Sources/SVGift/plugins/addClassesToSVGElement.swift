// addClassesToSVGElement.swift
// Plugin to add CSS classes to the root <svg> element
// okooo5km(十里)

import Foundation

/// Add CSS class names to the outermost `<svg>` element.
///
/// Parameters:
/// - `classNames`: A JSON array of class name strings to add.
/// - `className`: A single class name string to add.
///
/// Existing classes are preserved. Duplicate class names are not added.
/// Only the root `<svg>` element is affected.
public func makeAddClassesToSVGElementPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "addClassesToSVGElement") { _, params, _ in
        // Collect class names to add
        var classesToAdd: [String] = []

        if let classNamesParam = params["classNames"] {
            if classNamesParam.hasPrefix("["),
               let data = classNamesParam.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                classesToAdd.append(contentsOf: arr)
            } else {
                // Treat as comma-separated
                classesToAdd.append(contentsOf:
                    classNamesParam.split(separator: ",").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                )
            }
        }

        if let classNameParam = params["className"] {
            classesToAdd.append(classNameParam)
        }

        guard !classesToAdd.isEmpty else {
            return Visitor()
        }

        var isRootSVG = true

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard node.name == "svg" else {
                        return .continue
                    }

                    // Only apply to root <svg>
                    if isRootSVG {
                        isRootSVG = false
                    } else {
                        return .continue
                    }

                    // Get existing classes
                    var existingClasses: [String] = []
                    if let classAttr = node.attributes["class"] {
                        existingClasses = classAttr
                            .split(separator: " ")
                            .map(String.init)
                    }

                    let existingSet = Set(existingClasses)

                    // Add new classes (avoid duplicates)
                    for cls in classesToAdd {
                        if !existingSet.contains(cls) {
                            existingClasses.append(cls)
                        }
                    }

                    node.attributes["class"] = existingClasses.joined(separator: " ")

                    return .continue
                }
            )
        )
    }
}
