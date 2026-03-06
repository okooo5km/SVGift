// moveGroupAttrsToElems.swift
// Plugin to move group transform attribute to child elements
// okooo5km(十里)

import Foundation

/// Elements that are valid targets for transform propagation from groups.
private let pathElemsWithGroupsAndText: Set<String> = {
    var s = pathElems
    s.insert("g")
    s.insert("text")
    return s
}()

/// Move group `transform` attribute to child elements.
///
/// When a `<g>` element has a `transform` attribute and all its children
/// are path-like elements, groups, or text elements without IDs, the
/// group's transform is prepended to each child's transform and removed
/// from the group.
///
/// The transform is NOT moved if the group has `clip-path`, `mask`,
/// or `filter` url() references, since those operate in the group's
/// coordinate system.
public func makeMoveGroupAttrsToElemsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "moveGroupAttrsToElems") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard node.name == "g",
                          !node.children.isEmpty,
                          let groupTransform = node.attributes["transform"]
                    else {
                        return .continue
                    }

                    // Check group does not have url() references in reference props
                    for (name, value) in node.attributes {
                        if referencesProps.contains(name) && includesUrlReference(value) {
                            return .continue
                        }
                    }

                    // Check all children are elements of the right type, with no IDs
                    for child in node.children {
                        guard case .element(let childElem) = child else {
                            return .continue
                        }
                        guard pathElemsWithGroupsAndText.contains(childElem.name),
                              childElem.attributes["id"] == nil
                        else {
                            return .continue
                        }
                    }

                    // Move transform to each child
                    for child in node.children {
                        if case .element(let childElem) = child {
                            if let childTransform = childElem.attributes["transform"] {
                                childElem.attributes["transform"] = "\(groupTransform) \(childTransform)"
                            } else {
                                childElem.attributes["transform"] = groupTransform
                            }
                        }
                    }

                    node.attributes["transform"] = nil

                    return .continue
                }
            )
        )
    }
}
