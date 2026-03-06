// removeElementsByAttr.swift
// Plugin to remove elements matching specific id or class values
// okooo5km(十里)

import Foundation

/// Remove elements that match specified `id` or `class` attribute values.
///
/// Parameters:
/// - `id`: A single id string or JSON array of id strings. Elements with a
///   matching `id` attribute are removed.
/// - `class`: A single class string or JSON array of class strings. Elements
///   containing any of the specified classes are removed.
///
/// Both `id` and `class` can be used together — an element is removed if it
/// matches either condition.
public func makeRemoveElementsByAttrPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeElementsByAttr") { _, params, _ in
        // Parse id list
        var idSet: Set<String> = []
        if let idParam = params["id"] {
            if idParam.hasPrefix("["),
               let data = idParam.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                idSet = Set(arr)
            } else {
                idSet = [idParam]
            }
        }

        // Parse class list
        var classSet: Set<String> = []
        if let classParam = params["class"] {
            if classParam.hasPrefix("["),
               let data = classParam.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                classSet = Set(arr)
            } else {
                classSet = [classParam]
            }
        }

        // If neither id nor class specified, no-op
        guard !idSet.isEmpty || !classSet.isEmpty else {
            return Visitor()
        }

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // Check id match
                    if let nodeId = node.attributes["id"], idSet.contains(nodeId) {
                        detachNodeFromParent(.element(node), from: parent)
                        return .continue
                    }

                    // Check class match
                    if let nodeClass = node.attributes["class"], !classSet.isEmpty {
                        let nodeClasses = Set(
                            nodeClass.split(separator: " ").map(String.init)
                        )
                        if !nodeClasses.isDisjoint(with: classSet) {
                            detachNodeFromParent(.element(node), from: parent)
                            return .continue
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
