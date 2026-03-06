// mergePaths.swift
// Plugin to merge multiple paths into one if possible
// okooo5km(十里)

import Foundation

/// Merge multiple `<path>` elements into one if they have the same attributes.
public func makeMergePathsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "mergePaths") { root, params, _ in
        let force = params["force"] == "true"
        let floatPrecision: Int? = params["floatPrecision"].flatMap { Int($0) } ?? 3
        let noSpaceAfterFlags = params["noSpaceAfterFlags"] == "true"
        let stylesheet = collectStylesheet(root)

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if node.children.count <= 1 { return .continue }

                    var elementsToRemove: [ObjectIdentifier] = []
                    var prevChildIdx = 0
                    var prevPathData: [PathDataItem]? = nil

                    func updatePreviousPath(_ childEl: XastElement, _ pathData: [PathDataItem]) {
                        // Write back path data, removing duplicate leading movetos
                        var filtered: [PathDataItem] = []
                        for item in pathData {
                            if !filtered.isEmpty
                                && (item.command == "M" || item.command == "m") {
                                let last = filtered.last!
                                if last.command == "M" || last.command == "m" {
                                    filtered.removeLast()
                                }
                            }
                            filtered.append(item)
                        }
                        childEl.attributes["d"] = stringifyPathData(
                            filtered, precision: floatPrecision,
                            disableSpaceAfterFlags: noSpaceAfterFlags
                        )
                        prevPathData = nil
                    }

                    func getPrevChildElement() -> XastElement? {
                        if case .element(let el) = node.children[prevChildIdx] { return el }
                        return nil
                    }

                    for i in 1..<node.children.count {
                        let child = node.children[i]

                        guard let prevEl = getPrevChildElement(),
                              prevEl.name == "path",
                              prevEl.children.isEmpty,
                              prevEl.attributes["d"] != nil
                        else {
                            if let pd = prevPathData, let el = getPrevChildElement() {
                                updatePreviousPath(el, pd)
                            }
                            prevChildIdx = i; continue
                        }

                        guard case .element(let childEl) = child,
                              childEl.name == "path",
                              childEl.children.isEmpty,
                              childEl.attributes["d"] != nil
                        else {
                            if let pd = prevPathData, let el = getPrevChildElement() {
                                updatePreviousPath(el, pd)
                            }
                            prevChildIdx = i; continue
                        }

                        // Check for markers, clip-path, mask, url references
                        let computed = computeStyle(stylesheet: stylesheet, node: childEl)
                        if computed["marker-start"] != nil
                            || computed["marker-mid"] != nil
                            || computed["marker-end"] != nil
                            || computed["clip-path"] != nil
                            || computed["mask"] != nil
                            || computed["mask-image"] != nil
                            || elementHasUrl(computed, "fill")
                            || elementHasUrl(computed, "filter")
                            || elementHasUrl(computed, "stroke") {
                            if let pd = prevPathData { updatePreviousPath(prevEl, pd) }
                            prevChildIdx = i; continue
                        }

                        // Check attribute counts match
                        if childEl.attributes.count != prevEl.attributes.count {
                            if let pd = prevPathData { updatePreviousPath(prevEl, pd) }
                            prevChildIdx = i; continue
                        }

                        // Check all attributes (except d) match
                        var attrsEqual = true
                        for (attr, value) in childEl.attributes {
                            if attr == "d" { continue }
                            if prevEl.attributes[attr] != value {
                                attrsEqual = false; break
                            }
                        }
                        if !attrsEqual {
                            if let pd = prevPathData { updatePreviousPath(prevEl, pd) }
                            prevChildIdx = i; continue
                        }

                        let hasPrevPath = prevPathData != nil
                        var currentPathData = parsePathData(childEl.attributes["d"]!)
                        if !currentPathData.isEmpty && currentPathData[0].command == "m" {
                            currentPathData[0] = PathDataItem(command: "M", args: currentPathData[0].args)
                        }

                        if prevPathData == nil {
                            prevPathData = parsePathData(prevEl.attributes["d"]!)
                            if !prevPathData!.isEmpty && prevPathData![0].command == "m" {
                                prevPathData![0] = PathDataItem(command: "M", args: prevPathData![0].args)
                            }
                        }

                        if force || !pathsIntersect(prevPathData!, currentPathData) {
                            prevPathData!.append(contentsOf: currentPathData)
                            elementsToRemove.append(ObjectIdentifier(childEl))
                            continue
                        }

                        if hasPrevPath {
                            updatePreviousPath(prevEl, prevPathData!)
                        }

                        prevChildIdx = i
                        prevPathData = nil
                    }

                    if let pd = prevPathData, let el = getPrevChildElement() {
                        updatePreviousPath(el, pd)
                    }

                    // Remove merged elements
                    if !elementsToRemove.isEmpty {
                        node.children.removeAll { child in
                            if case .element(let el) = child {
                                return elementsToRemove.contains(ObjectIdentifier(el))
                            }
                            return false
                        }
                    }

                    return .continue
                }
            )
        )
    }
}

/// Check if a computed style value contains a url() reference.
private func elementHasUrl(_ computed: ComputedStyles, _ attName: String) -> Bool {
    if let style = computed[attName], case .static(let value, _) = style {
        return includesUrlReference(value)
    }
    return false
}
