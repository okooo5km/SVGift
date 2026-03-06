// removeOffCanvasPaths.swift
// Plugin to remove elements drawn outside of the viewBox
// okooo5km(十里)

import Foundation

/// Remove elements that are drawn outside of the viewBox.
public func makeRemoveOffCanvasPathsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeOffCanvasPaths") { _, _, _ in
        var viewBoxData: (left: Double, top: Double, right: Double, bottom: Double, width: Double, height: Double)? = nil

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parentNode in
                    if node.name == "svg" {
                        if case .root = parentNode {
                            var viewBox = ""
                            if let vb = node.attributes["viewBox"] {
                                viewBox = vb
                            } else if let w = node.attributes["width"],
                                      let h = node.attributes["height"] {
                                viewBox = "0 0 \(w) \(h)"
                            }

                            // Normalize
                            viewBox = viewBox
                                .replacingOccurrences(of: "[,+]|px", with: " ", options: .regularExpression)
                                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                                .trimmingCharacters(in: .whitespaces)

                            let regex = try! NSRegularExpression(
                                pattern: #"^(-?\d*\.?\d+) (-?\d*\.?\d+) (\d*\.?\d+) (\d*\.?\d+)$"#
                            )
                            let range = NSRange(viewBox.startIndex..<viewBox.endIndex, in: viewBox)
                            guard let m = regex.firstMatch(in: viewBox, range: range) else {
                                return .continue
                            }

                            let left = Double(String(viewBox[Range(m.range(at: 1), in: viewBox)!]))!
                            let top = Double(String(viewBox[Range(m.range(at: 2), in: viewBox)!]))!
                            let width = Double(String(viewBox[Range(m.range(at: 3), in: viewBox)!]))!
                            let height = Double(String(viewBox[Range(m.range(at: 4), in: viewBox)!]))!

                            viewBoxData = (
                                left: left, top: top,
                                right: left + width, bottom: top + height,
                                width: width, height: height
                            )
                        }
                    }

                    // Skip elements with transform
                    if node.attributes["transform"] != nil {
                        return .skip
                    }

                    guard node.name == "path",
                          let d = node.attributes["d"],
                          let vb = viewBoxData else { return .continue }

                    var pathData = parsePathData(d)

                    // Check if any M command is within the viewBox
                    var visible = false
                    for item in pathData {
                        if item.command == "M" && item.args.count >= 2 {
                            let x = item.args[0], y = item.args[1]
                            if x >= vb.left && x <= vb.right && y >= vb.top && y <= vb.bottom {
                                visible = true; break
                            }
                        }
                    }
                    if visible { return .continue }

                    // Close path if too short for intersects
                    if pathData.count == 2 {
                        pathData.append(PathDataItem(command: "z", args: []))
                    }

                    let viewBoxPathData: [PathDataItem] = [
                        PathDataItem(command: "M", args: [vb.left, vb.top]),
                        PathDataItem(command: "h", args: [vb.width]),
                        PathDataItem(command: "v", args: [vb.height]),
                        PathDataItem(command: "H", args: [vb.left]),
                        PathDataItem(command: "z", args: []),
                    ]

                    if !pathsIntersect(viewBoxPathData, pathData) {
                        detachNodeFromParent(.element(node), from: parentNode)
                    }

                    return .continue
                }
            )
        )
    }
}
