// addAttributesToSVGElement.swift
// Plugin to add attributes to the root <svg> element
// okooo5km(十里)

import Foundation

/// Add custom attributes to the outermost `<svg>` element.
///
/// Parameters:
/// - `attributes`: A JSON array of attributes to add. Each item can be:
///   - A string (e.g. `"data-icon"`) — adds a no-value attribute
///   - An object (e.g. `{"focusable":"false"}`) — adds key-value attribute(s)
/// - `attribute`: A single string attribute to add (no-value).
///
/// Only the root `<svg>` element is affected; nested `<svg>` elements are skipped.
/// Existing attributes are not overwritten.
public func makeAddAttributesToSVGElementPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "addAttributesToSVGElement") { _, params, _ in
        // Parse attributes to add: list of (key, value?) pairs
        // value == nil means a no-value attribute (boolean-style)
        var attrsToAdd: [(key: String, value: String?)] = []

        if let attributesParam = params["attributes"] {
            if let data = attributesParam.data(using: .utf8),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                for item in arr {
                    if let str = item as? String {
                        // String item: always treated as a no-value attribute
                        attrsToAdd.append((key: str, value: nil))
                    } else if let dict = item as? [String: String] {
                        for (key, value) in dict {
                            attrsToAdd.append((key: key, value: value))
                        }
                    }
                }
            }
        }

        if let attributeParam = params["attribute"] {
            // Single attribute (no value)
            if let eqIdx = attributeParam.firstIndex(of: "=") {
                let key = String(attributeParam[attributeParam.startIndex..<eqIdx])
                let value = String(attributeParam[attributeParam.index(after: eqIdx)...])
                attrsToAdd.append((key: key, value: value))
            } else {
                attrsToAdd.append((key: attributeParam, value: nil))
            }
        }

        guard !attrsToAdd.isEmpty else {
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

                    for attr in attrsToAdd {
                        // Don't overwrite existing attributes
                        if node.attributes[attr.key] == nil {
                            // For no-value attributes, use sentinel so stringifier omits ="..."
                            node.attributes[attr.key] = attr.value ?? noValueAttrSentinel
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
