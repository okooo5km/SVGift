// TransformParser.swift
// SVG transform attribute parsing, matrix operations, decomposition, and serialization
// okooo5km(十里)

import Foundation

// MARK: - Data Types

/// A single transform command with its numeric data.
public struct TransformItem {
    public var name: String
    public var data: [Double]

    public init(name: String, data: [Double]) {
        self.name = name
        self.data = data
    }
}

/// Parameters controlling transform precision and optimization.
public struct TransformParams {
    public var convertToShorts: Bool = true
    public var degPrecision: Int? = nil
    public var floatPrecision: Int = 3
    public var transformPrecision: Int = 5
    public var matrixToTransform: Bool = true
    public var shortTranslate: Bool = true
    public var shortScale: Bool = true
    public var shortRotate: Bool = true
    public var removeUseless: Bool = true
    public var collapseIntoOne: Bool = true
    public var leadingZero: Bool = true
    public var negativeExtraSpace: Bool = false
}

// MARK: - Math Utilities

private func degToRad(_ deg: Double) -> Double { deg * .pi / 180.0 }
private func radToDeg(_ rad: Double) -> Double { rad * 180.0 / .pi }
private func cosDeg(_ deg: Double) -> Double { cos(degToRad(deg)) }
private func sinDeg(_ deg: Double) -> Double { sin(degToRad(deg)) }
private func tanDeg(_ deg: Double) -> Double { tan(degToRad(deg)) }

// MARK: - Parse Transform String

private let transformTypes: Set<String> = [
    "matrix", "rotate", "scale", "skewX", "skewY", "translate",
]

private let regTransformSplit = try! NSRegularExpression(
    pattern: #"\s*(matrix|translate|scale|rotate|skewX|skewY)\s*\(\s*(.+?)\s*\)[\s,]*"#
)
private let regNumericValues = try! NSRegularExpression(
    pattern: #"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"#
)

/// Parse a transform attribute string into an array of TransformItem.
/// Returns empty array if malformed.
public func parseTransform(_ transformString: String) -> [TransformItem] {
    var transforms: [TransformItem] = []
    var currentTransform: TransformItem? = nil

    let range = NSRange(transformString.startIndex..<transformString.endIndex, in: transformString)
    // Split by the regex — we need to extract transform name and data parts
    let parts = regTransformSplit.splitIncludingCaptures(in: transformString, range: range)

    for part in parts {
        if part.isEmpty { continue }
        if transformTypes.contains(part) {
            currentTransform = TransformItem(name: part, data: [])
            transforms.append(currentTransform!)
        } else {
            let numRange = NSRange(part.startIndex..<part.endIndex, in: part)
            let matches = regNumericValues.matches(in: part, range: numRange)
            for match in matches {
                if let r = Range(match.range, in: part), let num = Double(String(part[r])) {
                    if transforms.count > 0 {
                        transforms[transforms.count - 1].data.append(num)
                    }
                }
            }
        }
    }

    if let last = transforms.last, last.data.isEmpty {
        return []
    }

    return transforms
}

// MARK: - NSRegularExpression Helpers

extension NSRegularExpression {
    /// Split string by regex, including capture groups as separate elements.
    func splitIncludingCaptures(in string: String, range: NSRange) -> [String] {
        var results: [String] = []
        var lastEnd = string.startIndex
        let matches = self.matches(in: string, range: range)

        for match in matches {
            guard let matchRange = Range(match.range, in: string) else { continue }
            // Add text before match
            let before = String(string[lastEnd..<matchRange.lowerBound])
            if !before.isEmpty { results.append(before) }
            // Add capture groups
            for i in 1..<match.numberOfRanges {
                if let captureRange = Range(match.range(at: i), in: string) {
                    results.append(String(string[captureRange]))
                }
            }
            lastEnd = matchRange.upperBound
        }
        // Add remaining text
        let remaining = String(string[lastEnd...])
        if !remaining.isEmpty { results.append(remaining) }

        return results
    }
}

// MARK: - Transform to Matrix

/// Convert a single transform to its 6-element matrix representation [a, b, c, d, e, f].
public func transformToMatrix(_ transform: TransformItem) -> [Double] {
    if transform.name == "matrix" { return transform.data }
    switch transform.name {
    case "translate":
        return [1, 0, 0, 1, transform.data[0], transform.data.count > 1 ? transform.data[1] : 0]
    case "scale":
        let sx = transform.data[0]
        let sy = transform.data.count > 1 ? transform.data[1] : sx
        return [sx, 0, 0, sy, 0, 0]
    case "rotate":
        let cosA = cosDeg(transform.data[0])
        let sinA = sinDeg(transform.data[0])
        let cx = transform.data.count > 1 ? transform.data[1] : 0
        let cy = transform.data.count > 2 ? transform.data[2] : 0
        return [
            cosA, sinA, -sinA, cosA,
            (1 - cosA) * cx + sinA * cy,
            (1 - cosA) * cy - sinA * cx,
        ]
    case "skewX":
        return [1, 0, tanDeg(transform.data[0]), 1, 0, 0]
    case "skewY":
        return [1, tanDeg(transform.data[0]), 0, 1, 0, 0]
    default:
        return [1, 0, 0, 1, 0, 0]
    }
}

// MARK: - Matrix Multiplication

/// Multiply two 6-element transform matrices.
public func multiplyTransformMatrices(_ a: [Double], _ b: [Double]) -> [Double] {
    [
        a[0] * b[0] + a[2] * b[1],
        a[1] * b[0] + a[3] * b[1],
        a[0] * b[2] + a[2] * b[3],
        a[1] * b[2] + a[3] * b[3],
        a[0] * b[4] + a[2] * b[5] + a[4],
        a[1] * b[4] + a[3] * b[5] + a[5],
    ]
}

/// Multiply all transforms into a single matrix.
public func transformsMultiply(_ transforms: [TransformItem]) -> TransformItem {
    let matrices = transforms.map { t -> [Double] in
        t.name == "matrix" ? t.data : transformToMatrix(t)
    }
    let combined = matrices.count > 0
        ? matrices.dropFirst().reduce(matrices[0], multiplyTransformMatrices)
        : []
    return TransformItem(name: "matrix", data: combined)
}

// MARK: - Matrix Decomposition

/// Decompose matrix into simple transforms using QRAB method.
private func decomposeQRAB(_ matrix: TransformItem) -> [TransformItem]? {
    let d = matrix.data
    guard d.count >= 6 else { return nil }
    let (a, b, c, dd, e, f) = (d[0], d[1], d[2], d[3], d[4], d[5])
    let delta = a * dd - b * c
    if delta == 0 { return nil }
    let r = hypot(a, b)
    if r == 0 { return nil }

    var decomposition: [TransformItem] = []
    let cosOfRotationAngle = a / r

    if e != 0 || f != 0 {
        decomposition.append(TransformItem(name: "translate", data: [e, f]))
    }

    if cosOfRotationAngle != 1 {
        let rotationAngleRads = acos(cosOfRotationAngle)
        decomposition.append(TransformItem(name: "rotate", data: [
            radToDeg(b < 0 ? -rotationAngleRads : rotationAngleRads), 0, 0,
        ]))
    }

    let sx = r
    let sy = delta / sx
    if sx != 1 || sy != 1 {
        decomposition.append(TransformItem(name: "scale", data: [sx, sy]))
    }

    let acPlusBd = a * c + b * dd
    if acPlusBd != 0 {
        decomposition.append(TransformItem(name: "skewX", data: [
            radToDeg(atan(acPlusBd / (a * a + b * b))),
        ]))
    }

    return decomposition
}

/// Decompose matrix into simple transforms using QRCD method.
private func decomposeQRCD(_ matrix: TransformItem) -> [TransformItem]? {
    let d = matrix.data
    guard d.count >= 6 else { return nil }
    let (a, b, c, dd, e, f) = (d[0], d[1], d[2], d[3], d[4], d[5])
    let delta = a * dd - b * c
    if delta == 0 { return nil }
    let s = hypot(c, dd)
    if s == 0 { return nil }

    var decomposition: [TransformItem] = []

    if e != 0 || f != 0 {
        decomposition.append(TransformItem(name: "translate", data: [e, f]))
    }

    let rotationAngleRads = Double.pi / 2 - (dd < 0 ? -1.0 : 1.0) * acos(-c / s)
    decomposition.append(TransformItem(name: "rotate", data: [
        radToDeg(rotationAngleRads), 0, 0,
    ]))

    let sx = delta / s
    let sy = s
    if sx != 1 || sy != 1 {
        decomposition.append(TransformItem(name: "scale", data: [sx, sy]))
    }

    let acPlusBd = a * c + b * dd
    if acPlusBd != 0 {
        decomposition.append(TransformItem(name: "skewY", data: [
            radToDeg(atan(acPlusBd / (c * c + dd * dd))),
        ]))
    }

    return decomposition
}

/// Convert translate(tx,ty)rotate(a) to rotate(a,cx,cy).
private func mergeTranslateAndRotate(tx: Double, ty: Double, a: Double) -> TransformItem {
    let rotAngleRads = degToRad(a)
    let d = 1 - cos(rotAngleRads)
    let e = sin(rotAngleRads)
    let cy = (d * ty + e * tx) / (d * d + e * e)
    let cx = (tx - e * cy) / d
    return TransformItem(name: "rotate", data: [a, cx, cy])
}

/// Check if a transform is an identity transform.
private func isIdentityTransform(_ t: TransformItem) -> Bool {
    switch t.name {
    case "rotate", "skewX", "skewY":
        return t.data[0] == 0
    case "scale":
        return t.data[0] == 1 && (t.data.count < 2 || t.data[1] == 1)
    case "translate":
        return t.data[0] == 0 && (t.data.count < 2 || t.data[1] == 0)
    default:
        return false
    }
}

/// Create an optimized scale transform (collapse [sx, sx] to [sx]).
private func createScaleTransform(_ data: [Double]) -> TransformItem {
    let scaleData: [Double]
    if data.count >= 2 && data[0] == data[1] {
        scaleData = [data[0]]
    } else {
        scaleData = Array(data.prefix(2))
    }
    return TransformItem(name: "scale", data: scaleData)
}

/// Optimize decomposed transforms (remove identities, merge translate+rotate, etc.).
private func optimizeTransforms(
    _ roundedTransforms: [TransformItem],
    _ rawTransforms: [TransformItem]
) -> [TransformItem] {
    var optimized: [TransformItem] = []
    var index = 0

    while index < roundedTransforms.count {
        let rt = roundedTransforms[index]

        if isIdentityTransform(rt) {
            index += 1; continue
        }

        switch rt.name {
        case "rotate":
            if rt.data[0] == 180 || rt.data[0] == -180 {
                let nextIdx = index + 1
                if nextIdx < roundedTransforms.count && roundedTransforms[nextIdx].name == "scale" {
                    optimized.append(createScaleTransform(roundedTransforms[nextIdx].data.map { -$0 }))
                    index += 2; continue
                } else {
                    optimized.append(TransformItem(name: "scale", data: [-1]))
                    index += 1; continue
                }
            }
            let rotData: [Double]
            if rt.data.count >= 3 && (rt.data[1] != 0 || rt.data[2] != 0) {
                rotData = Array(rt.data.prefix(3))
            } else {
                rotData = [rt.data[0]]
            }
            optimized.append(TransformItem(name: "rotate", data: rotData))

        case "scale":
            optimized.append(createScaleTransform(rt.data))

        case "skewX", "skewY":
            optimized.append(TransformItem(name: rt.name, data: [rt.data[0]]))

        case "translate":
            let nextIdx = index + 1
            if nextIdx < roundedTransforms.count {
                let next = roundedTransforms[nextIdx]
                if next.name == "rotate"
                    && next.data[0] != 180 && next.data[0] != -180 && next.data[0] != 0
                    && next.data.count >= 3 && next.data[1] == 0 && next.data[2] == 0 {
                    let rawData = rawTransforms[index].data
                    optimized.append(mergeTranslateAndRotate(
                        tx: rawData[0],
                        ty: rawData.count > 1 ? rawData[1] : 0,
                        a: rawTransforms[nextIdx].data[0]
                    ))
                    index += 2; continue
                }
            }
            let transData: [Double]
            if rt.data.count >= 2 && rt.data[1] != 0 {
                transData = Array(rt.data.prefix(2))
            } else {
                transData = [rt.data[0]]
            }
            optimized.append(TransformItem(name: "translate", data: transData))

        default:
            optimized.append(rt)
        }
        index += 1
    }

    return optimized.isEmpty ? [TransformItem(name: "scale", data: [1])] : optimized
}

// MARK: - matrixToTransform

/// Decompose a matrix into simple transforms and optimize.
/// Tries both QRAB and QRCD decompositions, returns the shorter result.
public func matrixToTransform(_ origMatrix: TransformItem, params: TransformParams) -> [TransformItem] {
    var decompositions: [[TransformItem]] = []
    if let qrab = decomposeQRAB(origMatrix) { decompositions.append(qrab) }
    if let qrcd = decomposeQRCD(origMatrix) { decompositions.append(qrcd) }

    var shortest: [TransformItem]?
    var shortestLen = Int.max

    for decomposition in decompositions {
        let rounded = decomposition.map { item -> TransformItem in
            var copy = TransformItem(name: item.name, data: item.data)
            return roundTransform(&copy, params: params)
        }
        let optimized = optimizeTransforms(rounded, decomposition)
        let len = js2transform(optimized, params: params).count
        if len < shortestLen {
            shortest = optimized
            shortestLen = len
        }
    }

    return shortest ?? [origMatrix]
}

// MARK: - Round Transform

/// Round a transform's data according to precision rules.
@discardableResult
public func roundTransform(_ transform: inout TransformItem, params: TransformParams) -> TransformItem {
    switch transform.name {
    case "translate":
        transform.data = floatRound(transform.data, params: params)
    case "rotate":
        var rounded = degRound(Array(transform.data.prefix(1)), params: params)
        rounded.append(contentsOf: floatRound(Array(transform.data.dropFirst()), params: params))
        transform.data = rounded
    case "skewX", "skewY":
        transform.data = degRound(transform.data, params: params)
    case "scale":
        transform.data = transformRound(transform.data, params: params)
    case "matrix":
        var rounded = transformRound(Array(transform.data.prefix(4)), params: params)
        rounded.append(contentsOf: floatRound(Array(transform.data.dropFirst(4)), params: params))
        transform.data = rounded
    default:
        break
    }
    return transform
}

private func degRound(_ data: [Double], params: TransformParams) -> [Double] {
    if let dp = params.degPrecision, dp >= 1, params.floatPrecision < 20 {
        return smartRound(dp, data)
    }
    return data.map { $0.rounded() }
}

private func floatRound(_ data: [Double], params: TransformParams) -> [Double] {
    if params.floatPrecision >= 1 && params.floatPrecision < 20 {
        return smartRound(params.floatPrecision, data)
    }
    return data.map { $0.rounded() }
}

private func transformRound(_ data: [Double], params: TransformParams) -> [Double] {
    if params.transformPrecision >= 1 && params.floatPrecision < 20 {
        return smartRound(params.transformPrecision, data)
    }
    return data.map { $0.rounded() }
}

/// Smart rounding: decreases accuracy while handling near-boundary values.
private func smartRound(_ precision: Int, _ data: [Double]) -> [Double] {
    var result = data
    let tolerance = pow(0.1, Double(precision))
    for i in stride(from: result.count - 1, through: 0, by: -1) {
        if toFixed(result[i], precision) != result[i] {
            let rounded = Double(String(format: "%.\(precision - 1)f", result[i]))!
            if abs(rounded - result[i]) >= tolerance {
                result[i] = Double(String(format: "%.\(precision)f", result[i]))!
            } else {
                result[i] = rounded
            }
        }
    }
    return result
}

// MARK: - Serialize Transform

/// Convert transforms to string representation.
public func js2transform(_ transforms: [TransformItem], params: TransformParams) -> String {
    transforms.map { transform in
        var t = transform
        roundTransform(&t, params: params)
        return "\(t.name)(\(cleanupOutData(t.data, params: params, command: nil)))"
    }.joined()
}

/// Convert a row of numbers to an optimized string view.
/// e.g. [0, -1, .5, .5] -> "0-1 .5.5"
public func cleanupOutData(
    _ data: [Double],
    params: TransformParams,
    command: Character?
) -> String {
    var str = ""
    var prev: Double = 0
    var hasPrev = false

    for (i, item) in data.enumerated() {
        var delimiter = " "
        if i == 0 { delimiter = "" }

        // Arc flags: no space after
        if params.negativeExtraSpace, let cmd = command, (cmd == "A" || cmd == "a") {
            let pos = i % 7
            if pos == 4 || pos == 5 { delimiter = "" }
        }

        let itemStr = params.leadingZero ? removeLeadingZero(item) : jsToString(item)

        if params.negativeExtraSpace && !delimiter.isEmpty
            && (item < 0 || (itemStr.first == "." && hasPrev && prev.truncatingRemainder(dividingBy: 1) != 0)) {
            delimiter = ""
        }

        hasPrev = true
        prev = item
        str += delimiter + itemStr
    }

    return str
}

// MARK: - Transform Arc (SVD)

/// Apply a matrix transform to arc parameters.
/// Uses SVD decomposition for ellipse transformation.
public func transformArc(cursor: (Double, Double), arc: inout [Double], transform: [Double]) {
    let x = arc[5] - cursor.0
    let y = arc[6] - cursor.1
    var a = arc[0]
    var b = arc[1]
    let rot = arc[2] * .pi / 180
    let cosRot = cos(rot)
    let sinRot = sin(rot)

    // Skip if radius is 0
    if a > 0 && b > 0 {
        var h = pow(x * cosRot + y * sinRot, 2) / (4 * a * a)
            + pow(y * cosRot - x * sinRot, 2) / (4 * b * b)
        if h > 1 {
            h = sqrt(h)
            a *= h
            b *= h
        }
    }

    let ellipse = [a * cosRot, a * sinRot, -b * sinRot, b * cosRot, 0.0, 0.0]
    let m = multiplyTransformMatrices(transform, ellipse)

    let lastCol = m[2] * m[2] + m[3] * m[3]
    let squareSum = m[0] * m[0] + m[1] * m[1] + lastCol
    let root = hypot(m[0] - m[3], m[1] + m[2]) * hypot(m[0] + m[3], m[1] - m[2])

    if root == 0 {
        // Circle
        arc[0] = sqrt(squareSum / 2)
        arc[1] = arc[0]
        arc[2] = 0
    } else {
        let majorAxisSqr = (squareSum + root) / 2
        let minorAxisSqr = (squareSum - root) / 2
        let major = abs(majorAxisSqr - lastCol) > 1e-6
        let sub = (major ? majorAxisSqr : minorAxisSqr) - lastCol
        let rowsSum = m[0] * m[2] + m[1] * m[3]
        let term1 = m[0] * sub + m[2] * rowsSum
        let term2 = m[1] * sub + m[3] * rowsSum
        arc[0] = sqrt(majorAxisSqr)
        arc[1] = sqrt(minorAxisSqr)
        arc[2] = ((major ? term2 < 0 : term1 > 0) ? -1.0 : 1.0)
            * acos((major ? term1 : term2) / hypot(term1, term2))
            * 180 / .pi
    }

    if (transform[0] < 0) != (transform[3] < 0) {
        // Flip sweep flag if coordinates are being flipped horizontally XOR vertically
        arc[4] = 1 - arc[4]
    }
}
