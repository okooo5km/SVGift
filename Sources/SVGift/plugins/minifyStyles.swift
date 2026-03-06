// minifyStyles.swift
// Plugin to minify styles using CSSO-lite approach
// okooo5km(十里)

import Foundation

/// Minify `<style>` element content and inline `style` attributes.
///
/// Performs whitespace compression, comment removal, and optionally dead code
/// elimination based on usage analysis of tags, classes, and IDs in the SVG.
///
/// Parameters:
/// - `usage`: `"false"` to disable dead code elimination (default: enabled)
public func makeMinifyStylesPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "minifyStyles") { _, params, _ in
        var styleElements: [(element: XastElement, parent: XastParent)] = []
        var elementsWithStyleAttrs: [XastElement] = []

        var tagsUsage = Set<String>()
        var idsUsage = Set<String>()
        var classesUsage = Set<String>()

        var enableUsage = true
        var deoptimized = false
        var forceUsageDeoptimized = false

        // Parse usage parameter
        var enableTagsUsage = true
        var enableIdsUsage = true
        var enableClassesUsage = true

        if let usageParam = params["usage"] {
            if usageParam == "false" {
                enableUsage = false
            } else if let data = usageParam.data(using: .utf8),
                      let usageObj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let force = usageObj["force"] as? Bool {
                    forceUsageDeoptimized = force
                }
                if let tags = usageObj["tags"] as? Bool {
                    enableTagsUsage = tags
                }
                if let ids = usageObj["ids"] as? Bool {
                    enableIdsUsage = ids
                }
                if let classes = usageObj["classes"] as? Bool {
                    enableClassesUsage = classes
                }
            }
        }

        return Visitor(
            root: VisitorCallbacks<XastRoot>(
                exit: { _, _ in
                    // Build usage data
                    let usageData: CSSUsageData?
                    if enableUsage && (!deoptimized || forceUsageDeoptimized) {
                        usageData = CSSUsageData(
                            tags: enableTagsUsage ? tagsUsage : nil,
                            ids: enableIdsUsage ? idsUsage : nil,
                            classes: enableClassesUsage ? classesUsage : nil
                        )
                    } else {
                        usageData = nil
                    }

                    // Minify style elements
                    for (styleNode, styleNodeParent) in styleElements {
                        guard let firstChild = styleNode.children.first else { continue }

                        let cssText: String
                        switch firstChild {
                        case .text(let t):
                            cssText = t.value
                        case .cdata(let c):
                            cssText = c.value
                        default:
                            continue
                        }

                        let minified = minifyCSS(cssText, usage: usageData)

                        if minified.isEmpty {
                            detachNodeFromParent(.element(styleNode), from: styleNodeParent)
                            continue
                        }

                        // Check minified content (not original) for characters requiring CDATA
                        let needsCdata = minified.contains("<") || minified.contains(">") || minified.contains("&")
                        if needsCdata {
                            styleNode.children = [.cdata(XastCdata(value: minified))]
                        } else {
                            styleNode.children = [.text(XastText(value: minified))]
                        }
                    }

                    // Minify style attributes
                    for node in elementsWithStyleAttrs {
                        if let style = node.attributes["style"] {
                            node.attributes["style"] = minifyCSSBlock(style)
                        }
                    }
                }
            ),
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    // Detect scripts (deoptimize)
                    if hasScripts(node) {
                        deoptimized = true
                    }

                    // Collect usage data
                    tagsUsage.insert(node.name)
                    if let id = node.attributes["id"] {
                        idsUsage.insert(id)
                    }
                    if let cls = node.attributes["class"] {
                        for className in cls.split(whereSeparator: { $0.isWhitespace }) {
                            classesUsage.insert(String(className))
                        }
                    }

                    // Collect style elements and elements with style attributes
                    if node.name == "style" && !node.children.isEmpty {
                        styleElements.append((element: node, parent: parentNode))
                    } else if node.attributes["style"] != nil {
                        elementsWithStyleAttrs.append(node)
                    }

                    return .continue
                }
            )
        )
    }
}
