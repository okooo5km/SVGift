// removeRasterImages.swift
// Plugin to remove raster image references from SVG
// okooo5km(十里)

import Foundation

/// Regex matching raster image file extensions or MIME types.
/// Matches `.jpg`, `.jpeg`, `.png`, `.gif` or `image/jpg`, `image/jpeg`,
/// `image/png`, `image/gif` in href values.
private let rasterImagePattern = try! NSRegularExpression(
    pattern: #"(\.|image\/)(jpe?g|png|gif)"#,
    options: .caseInsensitive
)

/// Remove `<image>` elements that reference raster images (JPEG, PNG, GIF).
///
/// Parameters: none
///
/// SVG images (`*.svg`, `image/svg+xml`) are preserved.
public func makeRemoveRasterImagesPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeRasterImages") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    guard node.name == "image" else {
                        return .continue
                    }

                    // Check href or xlink:href
                    let href = node.attributes["href"] ?? node.attributes["xlink:href"]
                    guard let href = href else {
                        return .continue
                    }

                    let range = NSRange(href.startIndex..., in: href)
                    if rasterImagePattern.firstMatch(in: href, range: range) != nil {
                        detachNodeFromParent(.element(node), from: parent)
                    }

                    return .continue
                }
            )
        )
    }
}
