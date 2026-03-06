// removeAttributesBySelector.swift
// Plugin to remove attributes from elements matching a CSS selector
// okooo5km(十里)

import Foundation

/// Remove attributes from elements matching CSS selectors.
///
/// Parameters (as JSON string):
/// - `selector`: CSS selector string
/// - `attributes`: Single attribute name (string) or array of names
/// - `selectors`: Array of {selector, attributes} objects (alternative)
public func makeRemoveAttributesBySelectorPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeAttributesBySelector") { root, params, _ in
        // Parse selector configs from params
        // The params come as [String: String] from fixture JSON, but the actual
        // config is complex. We need to parse it from the raw JSON.
        var selectorConfigs: [(selector: String, attributes: [String])] = []

        // Try parsing "selectors" array
        if let selectorsJSON = params["selectors"],
           let data = selectorsJSON.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for item in arr {
                if let sel = item["selector"] as? String {
                    let attrs = parseAttributesList(item["attributes"])
                    selectorConfigs.append((selector: sel, attributes: attrs))
                }
            }
        }

        // Try parsing single "selector" + "attributes"
        if selectorConfigs.isEmpty, let selector = params["selector"] {
            var attrs: [String] = []
            if let attrsParam = params["attributes"] {
                // Could be a JSON array string or a plain string
                if let data = attrsParam.data(using: .utf8),
                   let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
                    attrs = arr
                } else {
                    attrs = [attrsParam]
                }
            }
            selectorConfigs.append((selector: selector, attributes: attrs))
        }

        guard !selectorConfigs.isEmpty else { return nil }

        // Build parent map for selector matching
        let parentMap = buildParentMap(root)

        // Process each selector config
        for config in selectorConfigs {
            let matched: [XastElement]
            do {
                matched = try querySelectorAll(root, selectorText: config.selector, parentMap: parentMap)
            } catch {
                continue
            }

            for element in matched {
                for attrName in config.attributes {
                    element.attributes.removeValue(forKey: attrName)
                }
            }
        }

        // Return empty visitor since we already processed the tree
        return Visitor()
    }
}

private func parseAttributesList(_ value: Any?) -> [String] {
    guard let value = value else { return [] }
    if let str = value as? String {
        return [str]
    }
    if let arr = value as? [String] {
        return arr
    }
    return []
}
