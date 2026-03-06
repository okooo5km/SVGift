// removeEditorsNSData.swift
// Plugin to remove editors' namespace data from SVG
// okooo5km(十里)

import Foundation

/// Remove editors' namespace data from SVG elements.
///
/// Removes namespace declarations and elements/attributes belonging to
/// known SVG editor namespaces (Inkscape, Sodipodi, Adobe Illustrator, etc.).
///
/// Parameters:
/// - `additionalNamespaces`: Comma-separated list of additional namespace URIs to remove.
public func makeRemoveEditorsNSDataPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeEditorsNSData") { _, params, _ in
        // Build the set of namespace URIs to remove
        var namespaces = Set(editorNamespaces)
        if let additional = params["additionalNamespaces"] {
            for ns in additional.split(separator: ",") {
                namespaces.insert(ns.trimmingCharacters(in: .whitespaces))
            }
        }

        // Prefixes collected from xmlns declarations on the svg element
        var prefixes: Set<String> = []

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // On the root <svg> element, collect and remove matching xmlns:* declarations
                    if node.name == "svg" {
                        if case .root = parent {
                            for key in node.attributes.keys {
                                guard key.hasPrefix("xmlns:") else { continue }
                                let prefix = String(key.dropFirst("xmlns:".count))
                                if let uri = node.attributes[key], namespaces.contains(uri) {
                                    prefixes.insert(prefix)
                                    node.attributes.removeValue(forKey: key)
                                }
                            }
                        }
                    }

                    guard !prefixes.isEmpty else { return .continue }

                    // If the element itself belongs to a collected prefix, detach it
                    if node.name.contains(":") {
                        let elPrefix = String(node.name.split(separator: ":").first ?? "")
                        if prefixes.contains(elPrefix) {
                            detachNodeFromParent(.element(node), from: parent)
                            return .continue
                        }
                    }

                    // Remove attributes whose prefix is in the collected set
                    for key in node.attributes.keys {
                        guard key.contains(":") else { continue }
                        let attrPrefix = String(key.split(separator: ":").first ?? "")
                        if prefixes.contains(attrPrefix) {
                            node.attributes.removeValue(forKey: key)
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
