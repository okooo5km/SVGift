// cleanupIds.swift
// Plugin to remove unused IDs and minify used IDs
// okooo5km(十里)

import Foundation

// MARK: - ID Generation

/// Characters used for generating minified IDs (a-z, A-Z = 52 chars).
private let generateIdChars: [Character] = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
    "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]
private let maxIdIndex = generateIdChars.count - 1

/// Generate the next unique minimal ID.
///
/// - Parameter currentId: The current ID as an array of character indices, or nil for the first ID.
/// - Returns: The next ID as an array of character indices.
private func generateId(_ currentId: inout [Int]?) -> [Int] {
    guard var id = currentId else {
        let result = [0]
        currentId = result
        return result
    }
    id[id.count - 1] += 1
    var i = id.count - 1
    while i > 0 {
        if id[i] > maxIdIndex {
            id[i] = 0
            id[i - 1] += 1
        }
        i -= 1
    }
    if id[0] > maxIdIndex {
        id[0] = 0
        id.insert(0, at: 0)
    }
    currentId = id
    return id
}

/// Convert an ID array of character indices to a string.
private func getIdString(_ arr: [Int]) -> String {
    return String(arr.map { generateIdChars[$0] })
}

/// Parse a string list parameter that may be a JSON array string (e.g. `["a","b"]`)
/// or a plain comma-separated string (e.g. `"a,b"`).
private func parseStringListParam(_ value: String) -> [String] {
    // Try parsing as JSON array first
    if value.hasPrefix("["),
       let data = value.data(using: .utf8),
       let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
        return arr
    }
    // Fall back to comma-separated
    return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
}

// MARK: - Plugin

/// Remove unused IDs and minify used IDs.
///
/// If `<style>` elements with content or `<script>` elements are present,
/// the plugin is deoptimized and does nothing (unless `force` is `"true"`).
///
/// Parameters:
/// - `remove`: Remove unreferenced IDs. Default `"true"`.
/// - `minify`: Minify referenced IDs to short generated names. Default `"true"`.
/// - `preserve`: Comma-separated list of IDs to preserve (never remove or rename).
/// - `preservePrefixes`: Comma-separated list of prefixes; IDs starting with any of these are preserved.
/// - `force`: If `"true"`, skip deoptimization checks (styles/scripts). Default `"false"`.
public func makeCleanupIdsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "cleanupIds") { _, params, _ in
        let remove = params["remove"] != "false"
        let minify = params["minify"] != "false"
        let force = params["force"] == "true"

        // Parse preserve list (may be a JSON array string or comma-separated)
        let preserveIds: Set<String>
        if let preserveParam = params["preserve"], !preserveParam.isEmpty {
            preserveIds = Set(parseStringListParam(preserveParam))
        } else {
            preserveIds = []
        }

        // Parse preserve prefixes (may be a JSON array string or comma-separated)
        let preserveIdPrefixes: [String]
        if let prefixParam = params["preservePrefixes"], !prefixParam.isEmpty {
            preserveIdPrefixes = parseStringListParam(prefixParam)
        } else {
            preserveIdPrefixes = []
        }

        // State
        var nodeById: [String: XastElement] = [:]
        var referencesById: [String: [(element: XastElement, name: String)]] = [:]
        var orderedRefIds: [String] = []  // Maintain insertion order for deterministic ID generation
        var deoptimized = false

        /// Check if an ID should be preserved.
        func isIdPreserved(_ id: String) -> Bool {
            if preserveIds.contains(id) { return true }
            for prefix in preserveIdPrefixes {
                if id.hasPrefix(prefix) { return true }
            }
            return false
        }

        return Visitor(
            root: VisitorCallbacks<XastRoot>(
                exit: { root, _ in
                    if deoptimized {
                        return
                    }

                    var currentId: [Int]? = nil

                    // Process referenced IDs — iterate in insertion order
                    for id in orderedRefIds {
                        guard let refs = referencesById[id] else { continue }
                        guard let node = nodeById[id] else { continue }

                        // Replace referenced IDs with minified ones
                        if minify && !isIdPreserved(id) {
                            var currentIdString: String
                            repeat {
                                let idArr = generateId(&currentId)
                                currentIdString = getIdString(idArr)
                            } while isIdPreserved(currentIdString)
                                || (referencesById[currentIdString] != nil
                                    && nodeById[currentIdString] == nil)

                            node.attributes["id"] = currentIdString

                            // Encode the old ID for URL matching
                            let encodedId = id.addingPercentEncoding(
                                withAllowedCharacters: .urlPathAllowed
                            ) ?? id

                            for ref in refs {
                                guard let value = ref.element.attributes[ref.name] else {
                                    continue
                                }
                                if value.contains("#") {
                                    // Replace id in href and url() references
                                    // Chain both replacements (encoded then raw), matching JS behavior
                                    let newValue = value
                                        .replacingOccurrences(
                                            of: "#\(encodedId)",
                                            with: "#\(currentIdString)"
                                        )
                                        .replacingOccurrences(
                                            of: "#\(id)",
                                            with: "#\(currentIdString)"
                                        )
                                    ref.element.attributes[ref.name] = newValue
                                } else {
                                    // Replace id in begin attribute (e.g. "id.event")
                                    ref.element.attributes[ref.name] = value
                                        .replacingOccurrences(
                                            of: "\(id).",
                                            with: "\(currentIdString)."
                                        )
                                }
                            }
                        }

                        // Mark as referenced (remove from unreferenced set)
                        nodeById.removeValue(forKey: id)
                    }

                    // Remove non-referenced ID attributes from remaining elements
                    if remove {
                        for (id, node) in nodeById {
                            if !isIdPreserved(id) {
                                node.attributes["id"] = nil
                            }
                        }
                    }
                }
            ),
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if !force {
                        // Deoptimize if style or scripts are present
                        if (node.name == "style" && !node.children.isEmpty)
                            || hasScripts(node) {
                            deoptimized = true
                            return .continue
                        }

                        // Avoid removing IDs if the whole SVG consists only of defs
                        if node.name == "svg" {
                            var hasDefsOnly = true
                            for child in node.children {
                                if case .element(let childElem) = child {
                                    if childElem.name != "defs" {
                                        hasDefsOnly = false
                                        break
                                    }
                                } else {
                                    hasDefsOnly = false
                                    break
                                }
                            }
                            if hasDefsOnly {
                                return .skip
                            }
                        }
                    }

                    for (name, value) in node.attributes {
                        if name == "id" {
                            // Collect all IDs
                            let id = value
                            if nodeById[id] != nil {
                                // Remove duplicate IDs
                                node.attributes["id"] = nil
                            } else {
                                nodeById[id] = node
                            }
                        } else {
                            // Find references in attribute values
                            let ids = findReferences(attribute: name, value: value)
                            for id in ids {
                                if referencesById[id] == nil {
                                    orderedRefIds.append(id)
                                    referencesById[id] = []
                                }
                                referencesById[id]!.append(
                                    (element: node, name: name)
                                )
                            }
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
