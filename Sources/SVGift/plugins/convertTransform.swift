// convertTransform.swift
// Plugin to collapse/optimize transform attribute values
// okooo5km(十里)

import Foundation

/// Collapse multiple transformations, convert to short forms, and remove useless transforms.
public func makeConvertTransformPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertTransform") { _, params, _ in
        var tParams = TransformParams()
        if let v = params["convertToShorts"] { tParams.convertToShorts = v != "false" }
        if let v = params["degPrecision"] { tParams.degPrecision = Int(v) }
        if let v = params["floatPrecision"] { tParams.floatPrecision = Int(v) ?? 3 }
        if let v = params["transformPrecision"] { tParams.transformPrecision = Int(v) ?? 5 }
        if let v = params["matrixToTransform"] { tParams.matrixToTransform = v != "false" }
        if let v = params["shortTranslate"] { tParams.shortTranslate = v != "false" }
        if let v = params["shortScale"] { tParams.shortScale = v != "false" }
        if let v = params["shortRotate"] { tParams.shortRotate = v != "false" }
        if let v = params["removeUseless"] { tParams.removeUseless = v != "false" }
        if let v = params["collapseIntoOne"] { tParams.collapseIntoOne = v != "false" }
        if let v = params["leadingZero"] { tParams.leadingZero = v != "false" }
        if let v = params["negativeExtraSpace"] { tParams.negativeExtraSpace = v == "true" }

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    for attrName in ["transform", "gradientTransform", "patternTransform"] {
                        if node.attributes[attrName] != nil {
                            convertTransformAttr(node, attrName: attrName, params: tParams)
                        }
                    }
                    return .continue
                }
            )
        )
    }
}

private func convertTransformAttr(
    _ item: XastElement,
    attrName: String,
    params: TransformParams
) {
    var data = parseTransform(item.attributes[attrName]!)
    if data.isEmpty {
        item.attributes.removeValue(forKey: attrName)
        return
    }

    var p = definePrecision(data, params: params)

    if p.collapseIntoOne && data.count > 1 {
        data = [transformsMultiply(data)]
    }

    if p.convertToShorts {
        data = convertTransformsToShorts(data, params: &p)
    } else {
        for i in 0..<data.count {
            roundTransform(&data[i], params: p)
        }
    }

    if p.removeUseless {
        data = removeUselessTransforms(data)
    }

    if !data.isEmpty {
        item.attributes[attrName] = js2transform(data, params: p)
    } else {
        item.attributes.removeValue(forKey: attrName)
    }
}

/// Adjust precision based on actual matrix data.
private func definePrecision(_ data: [TransformItem], params: TransformParams) -> TransformParams {
    var p = params
    var matrixData: [Double] = []

    for item in data {
        if item.name == "matrix" {
            matrixData.append(contentsOf: Array(item.data.prefix(4)))
        }
    }

    var numberOfDigits = p.transformPrecision
    if !matrixData.isEmpty {
        let maxFloatDigits = matrixData.map { floatDigits($0) }.max() ?? p.transformPrecision
        p.transformPrecision = min(p.transformPrecision, max(maxFloatDigits, p.transformPrecision > 0 ? maxFloatDigits : p.transformPrecision))

        numberOfDigits = matrixData.map { n -> Int in
            let str = jsToString(n).replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            return str.count
        }.max() ?? numberOfDigits
    }

    if p.degPrecision == nil {
        p.degPrecision = max(0, min(p.floatPrecision, numberOfDigits - 2))
    }

    return p
}

/// Number of digits after decimal point.
private func floatDigits(_ n: Double) -> Int {
    let str = jsToString(n)
    guard let dotIdx = str.firstIndex(of: ".") else { return 0 }
    return str[str.index(after: dotIdx)...].count
}

/// Convert transforms to short forms.
private func convertTransformsToShorts(_ transforms: [TransformItem], params: inout TransformParams) -> [TransformItem] {
    var result = transforms

    var i = 0
    while i < result.count {
        // matrix → decomposed short forms
        if params.matrixToTransform && result[i].name == "matrix" {
            let decomposed = matrixToTransform(result[i], params: params)
            if js2transform(decomposed, params: params).count
                <= js2transform([result[i]], params: params).count {
                result.replaceSubrange(i...i, with: decomposed)
            }
        }

        roundTransform(&result[i], params: params)

        // translate(10, 0) → translate(10)
        if params.shortTranslate && result[i].name == "translate"
            && result[i].data.count == 2 && result[i].data[1] == 0 {
            result[i].data = [result[i].data[0]]
        }

        // scale(2, 2) → scale(2)
        if params.shortScale && result[i].name == "scale"
            && result[i].data.count == 2 && result[i].data[0] == result[i].data[1] {
            result[i].data = [result[i].data[0]]
        }

        // translate(cx,cy) rotate(a) translate(-cx,-cy) → rotate(a,cx,cy)
        if params.shortRotate && i >= 2
            && result[i - 2].name == "translate"
            && result[i - 1].name == "rotate"
            && result[i].name == "translate"
            && result[i - 2].data.count >= 2
            && result[i].data.count >= 2
            && result[i - 2].data[0] == -result[i].data[0]
            && result[i - 2].data[1] == -result[i].data[1] {
            let rotateItem = TransformItem(name: "rotate", data: [
                result[i - 1].data[0],
                result[i - 2].data[0],
                result[i - 2].data[1],
            ])
            result.replaceSubrange((i - 2)...i, with: [rotateItem])
            i -= 2
        }

        i += 1
    }

    return result
}

/// Remove identity/useless transforms.
private func removeUselessTransforms(_ transforms: [TransformItem]) -> [TransformItem] {
    transforms.filter { t in
        // translate(0), rotate(0), skewX(0), skewY(0)
        if ["translate", "rotate", "skewX", "skewY"].contains(t.name)
            && (t.data.count == 1 || t.name == "rotate")
            && t.data[0] == 0 {
            return false
        }
        // translate(0, 0)
        if t.name == "translate" && t.data[0] == 0 && (t.data.count < 2 || t.data[1] == 0) {
            return false
        }
        // scale(1) or scale(1, 1)
        if t.name == "scale" && t.data[0] == 1 && (t.data.count < 2 || t.data[1] == 1) {
            return false
        }
        // matrix(1 0 0 1 0 0)
        if t.name == "matrix" && t.data.count >= 6
            && t.data[0] == 1 && t.data[3] == 1
            && t.data[1] == 0 && t.data[2] == 0
            && t.data[4] == 0 && t.data[5] == 0 {
            return false
        }
        return true
    }
}
