// removeUselessStrokeAndFill.swift
// Plugin to remove useless stroke and fill attributes
// okooo5km(十里)

import Foundation

/// Remove useless `stroke` and `fill` attributes.
///
/// Removes stroke-related attributes when stroke is `none`, stroke-opacity is `0`,
/// or stroke-width is `0`. Removes fill-related attributes when fill is `none`
/// or fill-opacity is `0`. Optionally detaches elements where both are effectively invisible.
///
/// Parameters:
/// - `stroke`: Enable stroke removal. Default: `"true"`.
/// - `fill`: Enable fill removal. Default: `"true"`.
/// - `removeNone`: Detach element if both stroke and fill are `none`. Default: `"false"`.
public func makeRemoveUselessStrokeAndFillPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeUselessStrokeAndFill") { root, params, _ in
        let removeStroke = params["stroke"] != "false"
        let removeFill = params["fill"] != "false"
        let removeNone = params["removeNone"] == "true"

        let shapeElems = elemsGroups["shape"] ?? []

        // Pre-scan: bail if style or script elements are present
        var hasStyleOrScript = false
        visit(root, visitor: Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if node.name == "style" || hasScripts(node) {
                        hasStyleOrScript = true
                    }
                    return .continue
                }
            )
        ))
        if hasStyleOrScript {
            return nil
        }

        let stylesheet = collectStylesheet(root)

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // Skip elements with id (may be referenced)
                    if node.attributes["id"] != nil {
                        return .skip
                    }

                    // Only process shape elements
                    guard shapeElems.contains(node.name) else {
                        return .continue
                    }

                    let computed = computeStyle(stylesheet: stylesheet, node: node)

                    let stroke = computed["stroke"]
                    let strokeOpacity = computed["stroke-opacity"]
                    let strokeWidth = computed["stroke-width"]
                    let markerEnd = computed["marker-end"]
                    let fill = computed["fill"]
                    let fillOpacity = computed["fill-opacity"]

                    // Compute parent stroke (for deciding whether to add stroke="none")
                    let parentStroke: ComputedStyleValue?
                    if case .element(let parentEl) = parent {
                        let parentComputed = computeStyle(stylesheet: stylesheet, node: parentEl)
                        parentStroke = parentComputed["stroke"]
                    } else {
                        parentStroke = nil
                    }

                    // Check and remove useless stroke
                    if removeStroke {
                        let strokeIsNullOrNone = stroke == nil || staticValue(stroke) == "none"
                        let strokeOpacityIs0 = staticValue(strokeOpacity) == "0"
                        let strokeWidthIs0 = staticValue(strokeWidth) == "0"

                        if strokeIsNullOrNone || strokeOpacityIs0 || strokeWidthIs0 {
                            // Inner condition: only proceed if strokeWidth==0 or no marker-end
                            if strokeWidthIs0 || markerEnd == nil {
                                // Remove all stroke-* attributes
                                let keysToRemove = node.attributes.keys.filter { $0.hasPrefix("stroke") }
                                for key in keysToRemove {
                                    node.attributes.removeValue(forKey: key)
                                }
                                // If parent has non-none static stroke, add stroke="none" to override
                                if let ps = parentStroke, case .static(let psVal, _) = ps, psVal != "none" {
                                    node.attributes["stroke"] = "none"
                                }
                            }
                        }
                    }

                    // Check and remove useless fill
                    if removeFill {
                        let fillIsNone = staticValue(fill) == "none"
                        let fillOpacityIs0 = staticValue(fillOpacity) == "0"

                        if fillIsNone || fillOpacityIs0 {
                            // Only remove attrs starting with "fill-" (not "fill" itself)
                            let keysToRemove = node.attributes.keys.filter { $0.hasPrefix("fill-") }
                            for key in keysToRemove {
                                node.attributes.removeValue(forKey: key)
                            }
                            // Set fill="none" if fill was not already computed as "none"
                            if fill == nil || staticValue(fill) != "none" {
                                node.attributes["fill"] = "none"
                            }
                        }
                    }

                    // removeNone: detach element if both stroke and fill are effectively none
                    if removeNone {
                        let strokeIsNoneForRemoval = stroke == nil || node.attributes["stroke"] == "none"
                        let fillIsNoneForRemoval = (staticValue(fill) == "none") || node.attributes["fill"] == "none"
                        if strokeIsNoneForRemoval && fillIsNoneForRemoval {
                            detachNodeFromParent(.element(node), from: parent)
                        }
                    }

                    return .continue
                }
            )
        )
    }
}

/// Extract the static string value from a ComputedStyleValue, or nil if dynamic/absent.
private func staticValue(_ val: ComputedStyleValue?) -> String? {
    guard let val = val else { return nil }
    switch val {
    case .static(let value, _):
        return value
    case .dynamic:
        return nil
    }
}

