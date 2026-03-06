// removeStyleElement.swift
// Plugin to remove <style> elements from SVG
// okooo5km(十里)

import Foundation

/// Remove all `<style>` elements from the SVG.
///
/// Parameters: none
///
/// Note: This only removes the `<style>` element itself. Inline `style`
/// attributes on individual elements are not affected.
public func makeRemoveStyleElementPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeStyleElement") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    if node.name == "style" {
                        detachNodeFromParent(.element(node), from: parent)
                    }
                    return .continue
                }
            )
        )
    }
}
