// removeNonInheritableGroupAttrs.swift
// Plugin to remove non-inheritable group presentation attributes
// okooo5km(十里)

import Foundation

/// Remove non-inheritable group's presentation attributes.
///
/// On `<g>` elements, presentation attributes that are neither inheritable
/// nor in the special `presentationNonInheritableGroupAttrs` set have no
/// effect on children and can be safely removed.
public func makeRemoveNonInheritableGroupAttrsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeNonInheritableGroupAttrs") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard node.name == "g" else { return .continue }

                    for name in node.attributes.keys {
                        if presentationAttrs.contains(name)
                            && !inheritableAttrs.contains(name)
                            && !presentationNonInheritableGroupAttrs.contains(name)
                        {
                            node.attributes[name] = nil
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
