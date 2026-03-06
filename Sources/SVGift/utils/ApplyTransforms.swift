// ApplyTransforms.swift
// Apply transform attribute to path data (utility function, not a standalone plugin)
// okooo5km(十里)

import Foundation

private let regNumericValues = try! NSRegularExpression(
    pattern: #"[-+]?(\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#
)

/// Default stroke-width when none specified.
private let defaultStrokeWidth = "1"

/// Apply transforms to a path element's `d` attribute.
/// Returns true if transform was successfully applied (and removed from attributes).
public func applyTransforms(
    node: XastElement,
    stylesheet: Stylesheet,
    transformPrecision: Int = 5,
    applyTransformsStroked: Bool = true
) -> Bool {
    guard node.attributes["d"] != nil else { return false }

    // stroke and stroke-width can be redefined with <use>
    guard node.attributes["id"] == nil else { return false }

    guard let transformStr = node.attributes["transform"],
          !transformStr.isEmpty else { return false }

    // styles are not considered when applying transform
    guard node.attributes["style"] == nil else { return false }

    // skip if references to other objects (gradients, clip-path, etc.)
    for (name, value) in node.attributes {
        if referencesProps.contains(name) && includesUrlReference(value) {
            return false
        }
    }

    let computed = computeStyle(stylesheet: stylesheet, node: node)

    // Transform overridden in <style> tag
    if let transformStyle = computed["transform"] {
        if case .static(let value, _) = transformStyle {
            if value != transformStr { return false }
        }
    }

    let transforms = parseTransform(transformStr)
    if transforms.isEmpty { return false }
    let matrix = transformsMultiply(transforms)

    // Check stroke state
    let stroke: String?
    if let s = computed["stroke"] {
        if case .static(let value, _) = s { stroke = value }
        else { return false } // dynamic
    } else {
        stroke = nil
    }

    let strokeWidth: String?
    if let sw = computed["stroke-width"] {
        if case .static(let value, _) = sw { strokeWidth = value }
        else { return false } // dynamic
    } else {
        strokeWidth = nil
    }

    let scale = Double(String(format: "%.\(transformPrecision)f", hypot(matrix.data[0], matrix.data[1])))!

    if let stroke = stroke, stroke != "none" {
        if !applyTransformsStroked { return false }

        // stroke cannot be transformed with different vertical and horizontal scale or skew
        let d = matrix.data
        if !((d[0] == d[3] && d[1] == -d[2]) || (d[0] == -d[3] && d[1] == d[2])) {
            return false
        }

        // apply transform to stroke-width, stroke-dashoffset and stroke-dasharray
        if scale != 1 {
            if node.attributes["vector-effect"] != "non-scaling-stroke" {
                let sw = (strokeWidth ?? defaultStrokeWidth).trimmingCharacters(in: .whitespaces)
                node.attributes["stroke-width"] = scaleNumericValues(sw, scale: scale)

                if let dashOffset = node.attributes["stroke-dashoffset"] {
                    node.attributes["stroke-dashoffset"] = scaleNumericValues(
                        dashOffset.trimmingCharacters(in: .whitespaces), scale: scale)
                }
                if let dashArray = node.attributes["stroke-dasharray"] {
                    node.attributes["stroke-dasharray"] = scaleNumericValues(
                        dashArray.trimmingCharacters(in: .whitespaces), scale: scale)
                }
            }
        }
    }

    // Parse and transform the path data
    var pathData = parsePathData(node.attributes["d"] ?? "")
    // First moveto is actually absolute
    if !pathData.isEmpty && pathData[0].command == "m" {
        pathData[0] = PathDataItem(command: "M", args: pathData[0].args)
    }

    applyMatrixToPathData(&pathData, matrix: matrix.data)

    // Cache transformed path data (don't serialize to d — matches JS behavior).
    // convertPathData will read from pathJS cache to avoid precision loss.
    node.pathJS = pathData
    node.attributes.removeValue(forKey: "transform")

    return true
}

/// Scale all numeric values in a string by the given factor.
private func scaleNumericValues(_ str: String, scale: Double) -> String {
    let range = NSRange(str.startIndex..<str.endIndex, in: str)
    var result = str
    let matches = regNumericValues.matches(in: str, range: range).reversed()
    for match in matches {
        guard let r = Range(match.range, in: result) else { continue }
        guard let num = Double(String(result[r])) else { continue }
        let scaled = removeLeadingZero(num * scale)
        result.replaceSubrange(r, with: scaled)
    }
    return result
}

/// Transform absolute point by matrix.
private func transformAbsolutePoint(_ matrix: [Double], _ x: Double, _ y: Double) -> (Double, Double) {
    (matrix[0] * x + matrix[2] * y + matrix[4],
     matrix[1] * x + matrix[3] * y + matrix[5])
}

/// Transform relative point by matrix (no translation).
private func transformRelativePoint(_ matrix: [Double], _ x: Double, _ y: Double) -> (Double, Double) {
    (matrix[0] * x + matrix[2] * y,
     matrix[1] * x + matrix[3] * y)
}

/// Apply a matrix transform to all path data items in-place.
public func applyMatrixToPathData(_ pathData: inout [PathDataItem], matrix: [Double]) {
    var start: [Double] = [0, 0]
    var cursor: [Double] = [0, 0]

    for i in 0..<pathData.count {
        var command = pathData[i].command
        var args = pathData[i].args

        // moveto
        if command == "M" {
            cursor[0] = args[0]; cursor[1] = args[1]
            start = cursor
            let (x, y) = transformAbsolutePoint(matrix, args[0], args[1])
            args[0] = x; args[1] = y
        }
        if command == "m" {
            cursor[0] += args[0]; cursor[1] += args[1]
            start = cursor
            let (x, y) = transformRelativePoint(matrix, args[0], args[1])
            args[0] = x; args[1] = y
        }

        // H -> L
        if command == "H" {
            command = "L"; args = [args[0], cursor[1]]
        }
        if command == "h" {
            command = "l"; args = [args[0], 0]
        }
        // V -> L
        if command == "V" {
            command = "L"; args = [cursor[0], args[0]]
        }
        if command == "v" {
            command = "l"; args = [0, args[0]]
        }

        // lineto
        if command == "L" {
            cursor[0] = args[0]; cursor[1] = args[1]
            let (x, y) = transformAbsolutePoint(matrix, args[0], args[1])
            args[0] = x; args[1] = y
        }
        if command == "l" {
            cursor[0] += args[0]; cursor[1] += args[1]
            let (x, y) = transformRelativePoint(matrix, args[0], args[1])
            args[0] = x; args[1] = y
        }

        // curveto (x1 y1 x2 y2 x y)
        if command == "C" {
            cursor[0] = args[4]; cursor[1] = args[5]
            let (x1, y1) = transformAbsolutePoint(matrix, args[0], args[1])
            let (x2, y2) = transformAbsolutePoint(matrix, args[2], args[3])
            let (x, y) = transformAbsolutePoint(matrix, args[4], args[5])
            args = [x1, y1, x2, y2, x, y]
        }
        if command == "c" {
            cursor[0] += args[4]; cursor[1] += args[5]
            let (x1, y1) = transformRelativePoint(matrix, args[0], args[1])
            let (x2, y2) = transformRelativePoint(matrix, args[2], args[3])
            let (x, y) = transformRelativePoint(matrix, args[4], args[5])
            args = [x1, y1, x2, y2, x, y]
        }

        // smooth curveto (x2 y2 x y)
        if command == "S" {
            cursor[0] = args[2]; cursor[1] = args[3]
            let (x2, y2) = transformAbsolutePoint(matrix, args[0], args[1])
            let (x, y) = transformAbsolutePoint(matrix, args[2], args[3])
            args = [x2, y2, x, y]
        }
        if command == "s" {
            cursor[0] += args[2]; cursor[1] += args[3]
            let (x2, y2) = transformRelativePoint(matrix, args[0], args[1])
            let (x, y) = transformRelativePoint(matrix, args[2], args[3])
            args = [x2, y2, x, y]
        }

        // quadratic (x1 y1 x y)
        if command == "Q" {
            cursor[0] = args[2]; cursor[1] = args[3]
            let (x1, y1) = transformAbsolutePoint(matrix, args[0], args[1])
            let (x, y) = transformAbsolutePoint(matrix, args[2], args[3])
            args = [x1, y1, x, y]
        }
        if command == "q" {
            cursor[0] += args[2]; cursor[1] += args[3]
            let (x1, y1) = transformRelativePoint(matrix, args[0], args[1])
            let (x, y) = transformRelativePoint(matrix, args[2], args[3])
            args = [x1, y1, x, y]
        }

        // smooth quadratic (x y)
        if command == "T" {
            cursor[0] = args[0]; cursor[1] = args[1]
            let (x, y) = transformAbsolutePoint(matrix, args[0], args[1])
            args = [x, y]
        }
        if command == "t" {
            cursor[0] += args[0]; cursor[1] += args[1]
            let (x, y) = transformRelativePoint(matrix, args[0], args[1])
            args = [x, y]
        }

        // arc (rx ry x-axis-rotation large-arc-flag sweep-flag x y)
        if command == "A" {
            transformArc(cursor: (cursor[0], cursor[1]), arc: &args, transform: matrix)
            cursor[0] = args[5]; cursor[1] = args[6]
            // reduce number of digits in rotation angle
            if abs(args[2]) > 80 {
                let a = args[0]
                let rotation = args[2]
                args[0] = args[1]
                args[1] = a
                args[2] = rotation + (rotation > 0 ? -90 : 90)
            }
            let (x, y) = transformAbsolutePoint(matrix, args[5], args[6])
            args[5] = x; args[6] = y
        }
        if command == "a" {
            transformArc(cursor: (0, 0), arc: &args, transform: matrix)
            cursor[0] += args[5]; cursor[1] += args[6]
            if abs(args[2]) > 80 {
                let a = args[0]
                let rotation = args[2]
                args[0] = args[1]
                args[1] = a
                args[2] = rotation + (rotation > 0 ? -90 : 90)
            }
            let (x, y) = transformRelativePoint(matrix, args[5], args[6])
            args[5] = x; args[6] = y
        }

        // closepath
        if command == "z" || command == "Z" {
            cursor = start
        }

        pathData[i] = PathDataItem(command: command, args: args)
    }
}
