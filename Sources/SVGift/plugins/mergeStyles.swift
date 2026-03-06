// mergeStyles.swift
// Plugin to merge multiple <style> elements into one
// okooo5km(十里)

import Foundation

/// Merge multiple `<style>` elements into one.
///
/// Collects CSS text from all valid `<style>` elements, wraps media-attributed
/// styles in `@media` blocks, and combines everything into the first `<style>`.
/// Empty `<style>` elements are removed. Skips `<foreignObject>` content.
public func makeMergeStylesPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "mergeStyles") { _, _, _ in
        var firstStyleElement: XastElement?
        var collectedStyles = ""
        var styleContentType: String = "text" // "text" or "cdata"

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    // skip <foreignObject> content
                    if node.name == "foreignObject" {
                        return .skip
                    }

                    guard node.name == "style" else { return .continue }

                    // skip <style> with invalid type attribute
                    if let type = node.attributes["type"],
                       !type.isEmpty,
                       type != "text/css" {
                        return .continue
                    }

                    // extract style element content
                    var css = ""
                    for child in node.children {
                        switch child {
                        case .text(let text):
                            css += text.value
                        case .cdata(let cdata):
                            styleContentType = "cdata"
                            css += cdata.value
                        default:
                            break
                        }
                    }

                    // remove empty style elements
                    if css.trimmingCharacters(in: .whitespaces).isEmpty {
                        detachNodeFromParent(.element(node), from: parent)
                        return .continue
                    }

                    // collect css, wrap with @media if media attribute present
                    if let media = node.attributes["media"] {
                        collectedStyles += "@media \(media){\(css)}"
                        node.attributes.removeValue(forKey: "media")
                    } else {
                        collectedStyles += css
                    }

                    // combine into first style element
                    if firstStyleElement == nil {
                        firstStyleElement = node
                    } else {
                        detachNodeFromParent(.element(node), from: parent)
                        // update first style element content
                        let child: XastChild
                        if styleContentType == "cdata" {
                            child = .cdata(XastCdata(value: collectedStyles))
                        } else {
                            child = .text(XastText(value: collectedStyles))
                        }
                        firstStyleElement!.children = [child]
                    }

                    return .continue
                }
            )
        )
    }
}
