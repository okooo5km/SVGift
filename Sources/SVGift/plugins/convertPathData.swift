// convertPathData.swift
// Plugin to optimize path data: convert to relative, collapse, shorten, etc.
// okooo5km(十里)

import Foundation

// MARK: - Internal Types

/// Extended path data item with base/coords metadata for relative coordinate tracking.
private struct ExtPathItem {
    var command: Character
    var args: [Double]
    var base: [Double]   // absolute coordinates of the start of this segment
    var coords: [Double] // absolute coordinates of the end of this segment
    var sdata: [Double]? // preserved curve data for arc conversion checks

    init(command: Character, args: [Double], base: [Double] = [0, 0], coords: [Double] = [0, 0]) {
        self.command = command
        self.args = args
        self.base = base
        self.coords = coords
        self.sdata = nil
    }

    init(from item: PathDataItem) {
        self.command = item.command
        self.args = item.args
        self.base = [0, 0]
        self.coords = [0, 0]
        self.sdata = nil
    }
}

/// Circle description for arc conversion.
private struct Circle {
    var center: [Double]
    var radius: Double
}

/// Parameters for convertPathData.
private struct ConvertPathDataParams {
    var applyTransformsEnabled: Bool = true
    var applyTransformsStroked: Bool = true
    var makeArcsEnabled: Bool = true
    var arcThreshold: Double = 2.5
    var arcTolerance: Double = 0.5
    var straightCurves: Bool = true
    var convertToQ: Bool = true
    var lineShorthands: Bool = true
    var convertToZ: Bool = true
    var curveSmoothShorthands: Bool = true
    var floatPrecision: Int = 3
    var transformPrecision: Int = 5
    var smartArcRounding: Bool = true
    var removeUseless: Bool = true
    var collapseRepeated: Bool = true
    var utilizeAbsolute: Bool = true
    var leadingZero: Bool = true
    var negativeExtraSpace: Bool = true
    var noSpaceAfterFlags: Bool = false
    var forceAbsolutePath: Bool = false
}

// MARK: - Plugin Entry Point

public func makeConvertPathDataPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertPathData") { root, params, _ in
        var p = ConvertPathDataParams()
        if let v = params["applyTransforms"] { p.applyTransformsEnabled = v != "false" }
        if let v = params["applyTransformsStroked"] { p.applyTransformsStroked = v != "false" }
        if let v = params["makeArcs"] {
            if v == "false" { p.makeArcsEnabled = false }
        }
        if let v = params["makeArcs.threshold"] { p.arcThreshold = Double(v) ?? 2.5 }
        if let v = params["makeArcs.tolerance"] { p.arcTolerance = Double(v) ?? 0.5 }
        if let v = params["straightCurves"] { p.straightCurves = v != "false" }
        if let v = params["convertToQ"] { p.convertToQ = v != "false" }
        if let v = params["lineShorthands"] { p.lineShorthands = v != "false" }
        if let v = params["convertToZ"] { p.convertToZ = v != "false" }
        if let v = params["curveSmoothShorthands"] { p.curveSmoothShorthands = v != "false" }
        if let v = params["floatPrecision"] {
            if v == "false" {
                p.floatPrecision = -1  // disabled
            } else {
                p.floatPrecision = Int(v) ?? 3
            }
        }
        if let v = params["transformPrecision"] { p.transformPrecision = Int(v) ?? 5 }
        if let v = params["smartArcRounding"] { p.smartArcRounding = v != "false" }
        if let v = params["removeUseless"] { p.removeUseless = v != "false" }
        if let v = params["collapseRepeated"] { p.collapseRepeated = v != "false" }
        if let v = params["utilizeAbsolute"] { p.utilizeAbsolute = v != "false" }
        if let v = params["leadingZero"] { p.leadingZero = v != "false" }
        if let v = params["negativeExtraSpace"] { p.negativeExtraSpace = v != "false" }
        if let v = params["noSpaceAfterFlags"] { p.noSpaceAfterFlags = v == "true" }
        if let v = params["forceAbsolutePath"] { p.forceAbsolutePath = v == "true" }

        // Pre-pass: apply transforms
        if p.applyTransformsEnabled {
            let stylesheet = collectStylesheet(root)
            applyTransformsVisitor(root: root, stylesheet: stylesheet,
                                   transformPrecision: p.transformPrecision,
                                   applyTransformsStroked: p.applyTransformsStroked)
        }

        let stylesheet = collectStylesheet(root)

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    guard pathElems.contains(node.name),
                          let d = node.attributes["d"] else { return .continue }

                    let computedStyle = computeStyle(stylesheet: stylesheet, node: node)
                    let precision = p.floatPrecision
                    // Normalize error via string roundtrip to match JS:
                    // JS does +Math.pow(0.1, precision).toFixed(precision) → exact 0.001
                    // Swift pow(0.1, 3.0) = 0.0010000000000000002 (IEEE754 noise)
                    let error: Double = precision >= 0
                        ? Double(String(format: "%.\(precision)f", pow(0.1, Double(precision))))!
                        : 1e-2

                    let hasMarkerMid = computedStyle["marker-mid"] != nil

                    let maybeHasStroke: Bool = {
                        guard let s = computedStyle["stroke"] else { return false }
                        if case .dynamic = s { return true }
                        if case .static(let val, _) = s { return val != "none" }
                        return false
                    }()
                    let maybeHasLinecap: Bool = {
                        guard let lc = computedStyle["stroke-linecap"] else { return false }
                        if case .dynamic = lc { return true }
                        if case .static(let val, _) = lc { return val != "butt" }
                        return false
                    }()
                    let maybeHasStrokeAndLinecap = maybeHasStroke && maybeHasLinecap
                    let isSafeToUseZ: Bool = {
                        if !maybeHasStroke { return true }
                        guard let lc = computedStyle["stroke-linecap"],
                              case .static(let lcVal, _) = lc, lcVal == "round",
                              let lj = computedStyle["stroke-linejoin"],
                              case .static(let ljVal, _) = lj, ljVal == "round"
                        else { return false }
                        return true
                    }()

                    // Use cached path data from applyTransforms if available
                    // (avoids serialize/reparse precision loss — matches JS pathJS behavior)
                    var pathData: [PathDataItem]
                    if let cached = node.pathJS {
                        pathData = cached
                        node.pathJS = nil
                    } else {
                        pathData = parsePathData(d)
                    }
                    if pathData.isEmpty { return .continue }

                    // First moveto is always absolute per SVG spec
                    if pathData[0].command == "m" {
                        pathData[0].command = "M"
                    }

                    let includesVertices = pathData.contains {
                        $0.command != "m" && $0.command != "M"
                    }

                    // Convert to extended items
                    var data = pathData.map { ExtPathItem(from: $0) }

                    convertToRelative(&data)

                    data = filtersPass(
                        data, params: p,
                        precision: precision, error: error,
                        isSafeToUseZ: isSafeToUseZ,
                        maybeHasStrokeAndLinecap: maybeHasStrokeAndLinecap,
                        hasMarkerMid: hasMarkerMid
                    )

                    if p.utilizeAbsolute {
                        data = convertToMixed(data, params: p, precision: precision, error: error)
                    }

                    let hasMarker = node.attributes["marker-start"] != nil
                        || node.attributes["marker-end"] != nil
                    let isMarkersOnlyPath = hasMarker && includesVertices
                        && data.allSatisfy { $0.command == "m" || $0.command == "M" }

                    if isMarkersOnlyPath {
                        data.append(ExtPathItem(command: "z", args: []))
                    }

                    // Write back: js2path equivalent
                    let outItems = js2pathFilter(data)
                    node.attributes["d"] = stringifyPathData(
                        outItems, precision: precision >= 0 ? precision : nil,
                        disableSpaceAfterFlags: p.noSpaceAfterFlags
                    )
                    node.pathJS = outItems

                    return .continue
                }
            )
        )
    }
}

// MARK: - Pre-pass: Apply Transforms Visitor

/// Walk all elements and apply transforms to path elements.
private func applyTransformsVisitor(
    root: XastRoot,
    stylesheet: Stylesheet,
    transformPrecision: Int,
    applyTransformsStroked: Bool
) {
    func walkChildren(_ children: [XastChild]) {
        for child in children {
            if case .element(let el) = child {
                _ = applyTransforms(
                    node: el, stylesheet: stylesheet,
                    transformPrecision: transformPrecision,
                    applyTransformsStroked: applyTransformsStroked
                )
                walkChildren(el.children)
            }
        }
    }
    walkChildren(root.children)
}

// MARK: - js2path Filter (remove duplicate movetos)

private func js2pathFilter(_ data: [ExtPathItem]) -> [PathDataItem] {
    var result: [PathDataItem] = []
    for item in data {
        if !result.isEmpty && (item.command == "M" || item.command == "m") {
            let last = result[result.count - 1]
            if last.command == "M" || last.command == "m" {
                result.removeLast()
            }
        }
        result.append(PathDataItem(command: item.command, args: item.args))
    }
    return result
}

// MARK: - Convert Absolute to Relative

private func convertToRelative(_ pathData: inout [ExtPathItem]) {
    var start: [Double] = [0, 0]
    var cursor: [Double] = [0, 0]
    var prevCoords: [Double] = [0, 0]

    for i in 0..<pathData.count {
        var command = pathData[i].command
        var args = pathData[i].args

        switch command {
        case "m":
            cursor[0] += args[0]; cursor[1] += args[1]
            start[0] = cursor[0]; start[1] = cursor[1]

        case "M":
            if i != 0 { command = "m" }
            args[0] -= cursor[0]; args[1] -= cursor[1]
            cursor[0] += args[0]; cursor[1] += args[1]
            start[0] = cursor[0]; start[1] = cursor[1]

        case "l":
            cursor[0] += args[0]; cursor[1] += args[1]

        case "L":
            command = "l"
            args[0] -= cursor[0]; args[1] -= cursor[1]
            cursor[0] += args[0]; cursor[1] += args[1]

        case "h":
            cursor[0] += args[0]

        case "H":
            command = "h"
            args[0] -= cursor[0]; cursor[0] += args[0]

        case "v":
            cursor[1] += args[0]

        case "V":
            command = "v"
            args[0] -= cursor[1]; cursor[1] += args[0]

        case "c":
            cursor[0] += args[4]; cursor[1] += args[5]

        case "C":
            command = "c"
            args[0] -= cursor[0]; args[1] -= cursor[1]
            args[2] -= cursor[0]; args[3] -= cursor[1]
            args[4] -= cursor[0]; args[5] -= cursor[1]
            cursor[0] += args[4]; cursor[1] += args[5]

        case "s":
            cursor[0] += args[2]; cursor[1] += args[3]

        case "S":
            command = "s"
            args[0] -= cursor[0]; args[1] -= cursor[1]
            args[2] -= cursor[0]; args[3] -= cursor[1]
            cursor[0] += args[2]; cursor[1] += args[3]

        case "q":
            cursor[0] += args[2]; cursor[1] += args[3]

        case "Q":
            command = "q"
            args[0] -= cursor[0]; args[1] -= cursor[1]
            args[2] -= cursor[0]; args[3] -= cursor[1]
            cursor[0] += args[2]; cursor[1] += args[3]

        case "t":
            cursor[0] += args[0]; cursor[1] += args[1]

        case "T":
            command = "t"
            args[0] -= cursor[0]; args[1] -= cursor[1]
            cursor[0] += args[0]; cursor[1] += args[1]

        case "a":
            cursor[0] += args[5]; cursor[1] += args[6]

        case "A":
            command = "a"
            args[5] -= cursor[0]; args[6] -= cursor[1]
            cursor[0] += args[5]; cursor[1] += args[6]

        case "Z", "z":
            cursor[0] = start[0]; cursor[1] = start[1]

        default: break
        }

        pathData[i].command = command
        pathData[i].args = args
        pathData[i].base = prevCoords
        pathData[i].coords = [cursor[0], cursor[1]]
        prevCoords = pathData[i].coords
    }
}

// MARK: - Rounding Functions

private func strongRound(_ data: inout [Double], precision: Int, error: Double) {
    let precisionNum = precision
    for i in stride(from: data.count - 1, through: 0, by: -1) {
        let fixed = toFixed(data[i], precisionNum)
        if fixed != data[i] {
            let rounded = toFixed(data[i], precisionNum - 1)
            data[i] = toFixed(abs(rounded - data[i]), precisionNum + 1) >= error
                ? fixed : rounded
        }
    }
}

private func simpleRound(_ data: inout [Double]) {
    for i in stride(from: data.count - 1, through: 0, by: -1) {
        data[i] = data[i].rounded()
    }
}

private func roundData(_ data: inout [Double], precision: Int, error: Double) {
    if precision > 0 && precision < 20 {
        strongRound(&data, precision: precision, error: error)
    } else {
        simpleRound(&data)
    }
}

// MARK: - cleanupOutData for path commands

private func cleanupOutDataPath(
    _ data: [Double],
    params: ConvertPathDataParams,
    command: Character? = nil
) -> String {
    var str = ""
    var prev: Double = 0
    var hasPrev = false

    for (i, item) in data.enumerated() {
        var delimiter = " "
        if i == 0 { delimiter = "" }

        if params.noSpaceAfterFlags, let cmd = command, (cmd == "A" || cmd == "a") {
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

// MARK: - data2Path: Stringify items for length comparison

private func data2Path(_ items: [ExtPathItem], params: ConvertPathDataParams, precision: Int, error: Double) -> String {
    var result = ""
    for item in items {
        var args = item.args
        roundData(&args, precision: precision, error: error)
        let strData = cleanupOutDataPath(args, params: params, command: item.command)
        result += String(item.command) + strData
    }
    return result
}

// MARK: - Main Filters Loop

private func filtersPass(
    _ path: [ExtPathItem],
    params: ConvertPathDataParams,
    precision: Int,
    error: Double,
    isSafeToUseZ: Bool,
    maybeHasStrokeAndLinecap: Bool,
    hasMarkerMid: Bool
) -> [ExtPathItem] {
    var relSubpoint: [Double] = [0, 0]
    var pathBase: [Double] = [0, 0]
    var prev = ExtPathItem(command: "\0", args: [])
    var prevQControlPoint: [Double]? = nil
    var path = path

    var resultIndices: [Int] = []
    var i = 0
    while i < path.count {
        let qControlPoint = prevQControlPoint
        var item = path[i]
        var command = item.command
        var data = item.args
        let next: ExtPathItem? = (i + 1 < path.count) ? path[i + 1] : nil

        if command != "Z" && command != "z" {
            var sdata = data

            if command == "s" {
                sdata = [0, 0] + data
                let pdata = prev.args
                let n = pdata.count
                if n >= 4 {
                    sdata[0] = pdata[n - 2] - pdata[n - 4]
                    sdata[1] = pdata[n - 1] - pdata[n - 3]
                }
            }

            // Convert curves to arcs if possible
            if params.makeArcsEnabled && (command == "c" || command == "s") && isConvex(sdata) {
                if let circle = findCircle(sdata, arcThreshold: params.arcThreshold, arcTolerance: params.arcTolerance, error: error) {
                    var r = circle.radius
                    var rArr = [r]
                    roundData(&rArr, precision: precision, error: error)
                    r = rArr[0]
                    var angle = findArcAngle(sdata, circle: circle)
                    let sweep: Double = sdata[5] * sdata[0] - sdata[4] * sdata[1] > 0 ? 1 : 0

                    var arc = ExtPathItem(
                        command: "a",
                        args: [r, r, 0, 0, sweep, sdata[4], sdata[5]],
                        base: item.base,
                        coords: item.coords
                    )
                    var output: [ExtPathItem] = [arc]
                    var relCenter: [Double] = [
                        circle.center[0] - sdata[4],
                        circle.center[1] - sdata[5],
                    ]
                    let relCircle = Circle(center: relCenter, radius: circle.radius)
                    var arcCurves: [Int] = [i]  // indices into path
                    var hasPrev = 0
                    var suffix = ""
                    var nextLonghand: ExtPathItem? = nil

                    // Check if prev curve fits the arc
                    if (prev.command == "c" && isConvex(prev.args) && isArcPrev(prev.args, circle: circle))
                        || (prev.command == "a" && prev.sdata != nil && isArcPrev(prev.sdata!, circle: circle)) {
                        if let prevIdx = resultIndices.last {
                            arcCurves.insert(prevIdx, at: 0)
                        }
                        arc.base = prev.base
                        arc.args[5] = arc.coords[0] - arc.base[0]
                        arc.args[6] = arc.coords[1] - arc.base[1]
                        let prevData = prev.command == "a" ? (prev.sdata ?? prev.args) : prev.args
                        let prevAngle = findArcAngle(prevData, circle: Circle(
                            center: [prevData[4] + circle.center[0], prevData[5] + circle.center[1]],
                            radius: circle.radius
                        ))
                        angle += prevAngle
                        if angle > .pi { arc.args[3] = 1 }
                        hasPrev = 1
                        output[0] = arc
                    }

                    // Check if next curves fit the arc
                    var j = i
                    while true {
                        j += 1
                        guard j < path.count else { break }
                        let nextItem = path[j]
                        guard nextItem.command == "c" || nextItem.command == "s" else { break }

                        var nextData = nextItem.args
                        if nextItem.command == "s" {
                            var lh = ExtPathItem(command: "s", args: nextItem.args)
                            let prevArgs = path[j - 1].args
                            makeLonghand(&lh, prevData: prevArgs)
                            nextData = lh.args
                            nextLonghand = ExtPathItem(command: lh.command, args: Array(lh.args.prefix(2)))
                            suffix = data2Path([nextLonghand!], params: params, precision: precision, error: error)
                        }

                        let relCircleForCheck = Circle(center: relCenter, radius: relCircle.radius)
                        if isConvex(nextData) && isArc(nextData, circle: relCircleForCheck, arcThreshold: params.arcThreshold, arcTolerance: params.arcTolerance, error: error) {
                            angle += findArcAngle(nextData, circle: relCircleForCheck)
                            if angle - 2 * .pi > 1e-3 { break }
                            if angle > .pi { arc.args[3] = 1 }
                            arcCurves.append(j)
                            if 2 * .pi - angle > 1e-3 {
                                arc.coords = nextItem.coords
                                arc.args[5] = arc.coords[0] - arc.base[0]
                                arc.args[6] = arc.coords[1] - arc.base[1]
                            } else {
                                // Full circle
                                arc.args[5] = 2 * (relCenter[0] - nextData[4])
                                arc.args[6] = 2 * (relCenter[1] - nextData[5])
                                arc.coords = [arc.base[0] + arc.args[5], arc.base[1] + arc.args[6]]
                                let arc2 = ExtPathItem(
                                    command: "a",
                                    args: [r, r, 0, 0, sweep,
                                           nextItem.coords[0] - arc.coords[0],
                                           nextItem.coords[1] - arc.coords[1]],
                                    base: arc.coords,
                                    coords: nextItem.coords
                                )
                                output[0] = arc
                                output.append(arc2)
                                j += 1
                                break
                            }
                            relCenter[0] -= nextData[4]
                            relCenter[1] -= nextData[5]
                            output[0] = arc
                        } else {
                            break
                        }
                    }

                    // Check if arc representation is shorter
                    let arcCurveItems = arcCurves.map { path[$0] }
                    if (data2Path(output, params: params, precision: precision, error: error) + suffix).count
                        < data2Path(arcCurveItems, params: params, precision: precision, error: error).count {
                        // Fix up next 's' command if needed
                        if j < path.count && path[j].command == "s" {
                            makeLonghand(&path[j], prevData: path[j - 1].args)
                        }

                        if hasPrev > 0 {
                            let prevArc = output.removeFirst()
                            var prevArcArgs = prevArc.args
                            roundData(&prevArcArgs, precision: precision, error: error)
                            relSubpoint[0] += prevArcArgs[5] - prev.args[prev.args.count - 2]
                            relSubpoint[1] += prevArcArgs[6] - prev.args[prev.args.count - 1]
                            prev.command = "a"
                            prev.args = prevArcArgs
                            prev.coords = prevArc.coords
                            item.base = prev.coords
                            // Update the prev item in path
                            if let prevIdx = resultIndices.last {
                                path[prevIdx] = prev
                            }
                        }

                        if let firstArc = output.first {
                            arc = firstArc
                        }

                        if arcCurves.count == 1 {
                            item.sdata = sdata
                        } else if arcCurves.count - 1 - hasPrev > 0 {
                            // Remove consumed items, replace with remaining arcs
                            let removeStart = i + 1
                            let removeCount = arcCurves.count - 1 - hasPrev
                            let remaining = Array(output.dropFirst())
                            path.replaceSubrange(removeStart..<(removeStart + removeCount), with: remaining)
                        }

                        if output.isEmpty {
                            // Item was consumed by prev, skip it
                            i += 1
                            continue
                        }

                        command = "a"
                        data = arc.args
                        item.coords = arc.coords
                    }
                }
            }

            // Rounding relative coordinates with accumulating error correction
            if precision >= 0 {
                if command == "m" || command == "l" || command == "t"
                    || command == "q" || command == "s" || command == "c" {
                    for k in stride(from: data.count - 1, through: 0, by: -1) {
                        data[k] += item.base[k % 2] - relSubpoint[k % 2]
                    }
                } else if command == "h" {
                    data[0] += item.base[0] - relSubpoint[0]
                } else if command == "v" {
                    data[0] += item.base[1] - relSubpoint[1]
                } else if command == "a" {
                    data[5] += item.base[0] - relSubpoint[0]
                    data[6] += item.base[1] - relSubpoint[1]
                }
                roundData(&data, precision: precision, error: error)

                if command == "h" {
                    relSubpoint[0] += data[0]
                } else if command == "v" {
                    relSubpoint[1] += data[0]
                } else {
                    relSubpoint[0] += data[data.count - 2]
                    relSubpoint[1] += data[data.count - 1]
                }
                roundData(&relSubpoint, precision: precision, error: error)

                if command == "M" || command == "m" {
                    pathBase[0] = relSubpoint[0]
                    pathBase[1] = relSubpoint[1]
                }
            }

            // Smart arc rounding
            let sagitta: Double? = command == "a" ? calculateSagitta(data, error: error) : nil
            if params.smartArcRounding, let sag = sagitta, precision > 0 {
                for precisionNew in stride(from: precision, through: 0, by: -1) {
                    let radius = toFixed(data[0], precisionNew)
                    let newSagitta = calculateSagitta([radius, radius] + Array(data[2...]), error: error)
                    if let ns = newSagitta, abs(sag - ns) < error {
                        data[0] = radius
                        data[1] = radius
                    } else {
                        break
                    }
                }
            }

            // Convert straight curves into line segments
            if params.straightCurves {
                if (command == "c" && isCurveStraightLine(data, error: error))
                    || (command == "s" && isCurveStraightLine(sdata, error: error)) {
                    if i + 1 < path.count && path[i + 1].command == "s" {
                        makeLonghand(&path[i + 1], prevData: data)
                    }
                    command = "l"
                    data = Array(data.suffix(2))
                } else if command == "q" && isCurveStraightLine(data, error: error) {
                    if i + 1 < path.count && path[i + 1].command == "t" {
                        makeLonghand(&path[i + 1], prevData: data)
                    }
                    command = "l"
                    data = Array(data.suffix(2))
                } else if command == "t" && prev.command != "q" && prev.command != "t" {
                    command = "l"
                    data = Array(data.suffix(2))
                } else if command == "a"
                    && (data[0] == 0 || data[1] == 0 || (sagitta != nil && sagitta! < error)) {
                    command = "l"
                    data = Array(data.suffix(2))
                }
            }

            // Degree-lower c to q
            if params.convertToQ && command == "c" {
                let x1 = 0.75 * (item.base[0] + data[0]) - 0.25 * item.base[0]
                let x2 = 0.75 * (item.base[0] + data[2]) - 0.25 * (item.base[0] + data[4])
                if abs(x1 - x2) < error * 2 {
                    let y1 = 0.75 * (item.base[1] + data[1]) - 0.25 * item.base[1]
                    let y2 = 0.75 * (item.base[1] + data[3]) - 0.25 * (item.base[1] + data[5])
                    if abs(y1 - y2) < error * 2 {
                        var newData = [
                            x1 + x2 - item.base[0],
                            y1 + y2 - item.base[1],
                            data[4], data[5],
                        ]
                        roundData(&newData, precision: precision, error: error)
                        let originalLength = cleanupOutDataPath(data, params: params, command: "c").count
                        let newLength = cleanupOutDataPath(newData, params: params, command: "q").count
                        if newLength < originalLength {
                            command = "q"
                            data = newData
                            if i + 1 < path.count && path[i + 1].command == "s" {
                                makeLonghand(&path[i + 1], prevData: data)
                            }
                        }
                    }
                }
            }

            // Horizontal and vertical line shorthands
            if params.lineShorthands && command == "l" {
                if data[1] == 0 {
                    command = "h"
                    data = [data[0]]
                } else if data[0] == 0 {
                    command = "v"
                    data = [data[1]]
                }
            }

            // Collapse repeated commands
            if params.collapseRepeated && !hasMarkerMid
                && (command == "m" || command == "h" || command == "v")
                && prev.command != "\0"
                && command == Character(prev.command.lowercased())
                && ((command != "h" && command != "v")
                    || (prev.args[0] >= 0) == (data[0] >= 0)) {
                prev.args[0] += data[0]
                if command != "h" && command != "v" {
                    prev.args[1] += data[1]
                }
                prev.coords = item.coords
                // Update prev in path
                if let prevIdx = resultIndices.last {
                    path[prevIdx] = prev
                }
                // Skip this item
                i += 1
                continue
            }

            // Convert curves into smooth shorthands
            if params.curveSmoothShorthands && prev.command != "\0" {
                if command == "c" {
                    if prev.command == "c"
                        && abs(data[0] - -(prev.args[2] - prev.args[4])) < error
                        && abs(data[1] - -(prev.args[3] - prev.args[5])) < error {
                        command = "s"
                        data = Array(data[2...])
                    } else if prev.command == "s"
                        && abs(data[0] - -(prev.args[0] - prev.args[2])) < error
                        && abs(data[1] - -(prev.args[1] - prev.args[3])) < error {
                        command = "s"
                        data = Array(data[2...])
                    } else if prev.command != "c" && prev.command != "s"
                        && abs(data[0]) < error && abs(data[1]) < error {
                        command = "s"
                        data = Array(data[2...])
                    }
                } else if command == "q" {
                    if prev.command == "q"
                        && abs(data[0] - (prev.args[2] - prev.args[0])) < error
                        && abs(data[1] - (prev.args[3] - prev.args[1])) < error {
                        command = "t"
                        data = Array(data[2...])
                    } else if prev.command == "t", let qcp = qControlPoint {
                        let predicted = reflectPoint(qcp, base: item.base)
                        let real = [data[0] + item.base[0], data[1] + item.base[1]]
                        if abs(predicted[0] - real[0]) < error
                            && abs(predicted[1] - real[1]) < error {
                            command = "t"
                            data = Array(data[2...])
                        }
                    }
                }
            }

            // Remove useless non-first path segments
            if params.removeUseless && !maybeHasStrokeAndLinecap {
                if (command == "l" || command == "h" || command == "v"
                    || command == "q" || command == "t" || command == "c" || command == "s")
                    && data.allSatisfy({ $0 == 0 }) {
                    // Skip item, set path[i] = prev
                    path[i] = prev
                    i += 1
                    continue
                }
                if command == "a" && data[5] == 0 && data[6] == 0 {
                    path[i] = prev
                    i += 1
                    continue
                }
            }

            // Convert going home to z
            if params.convertToZ
                && (isSafeToUseZ || (next != nil && (next!.command == "Z" || next!.command == "z")))
                && (command == "l" || command == "h" || command == "v") {
                if abs(pathBase[0] - item.coords[0]) < error
                    && abs(pathBase[1] - item.coords[1]) < error {
                    command = "z"
                    data = []
                }
            }

            item.command = command
            item.args = data
        } else {
            // z resets coordinates
            relSubpoint[0] = pathBase[0]
            relSubpoint[1] = pathBase[1]
            if prev.command == "Z" || prev.command == "z" {
                // Remove duplicate z
                i += 1
                continue
            }
        }

        // Remove useless z at same position
        if (command == "Z" || command == "z")
            && params.removeUseless && isSafeToUseZ
            && abs(item.base[0] - item.coords[0]) < error / 10
            && abs(item.base[1] - item.coords[1]) < error / 10 {
            i += 1
            continue
        }

        // Track quadratic control point
        if command == "q" {
            prevQControlPoint = [data[0] + item.base[0], data[1] + item.base[1]]
        } else if command == "t" {
            if let qcp = qControlPoint {
                prevQControlPoint = reflectPoint(qcp, base: item.base)
            } else {
                prevQControlPoint = item.coords
            }
        } else {
            prevQControlPoint = nil
        }

        path[i] = item
        prev = item
        resultIndices.append(i)
        i += 1
    }

    return resultIndices.map { path[$0] }
}

// MARK: - Convert to Mixed (Absolute/Relative)

private func convertToMixed(
    _ inputPath: [ExtPathItem],
    params: ConvertPathDataParams,
    precision: Int,
    error: Double
) -> [ExtPathItem] {
    guard !inputPath.isEmpty else { return inputPath }

    let path = inputPath
    var prev = path[0]
    var result: [ExtPathItem] = [path[0]]

    for index in 1..<path.count {
        var item = path[index]
        if item.command == "Z" || item.command == "z" {
            prev = item
            result.append(item)
            continue
        }

        let command = item.command
        let data = item.args
        var adata = data
        var rdata = data

        if command == "m" || command == "l" || command == "t"
            || command == "q" || command == "s" || command == "c" {
            for k in stride(from: adata.count - 1, through: 0, by: -1) {
                adata[k] += item.base[k % 2]
            }
        } else if command == "h" {
            adata[0] += item.base[0]
        } else if command == "v" {
            adata[0] += item.base[1]
        } else if command == "a" {
            adata[5] += item.base[0]
            adata[6] += item.base[1]
        }

        roundData(&adata, precision: precision, error: error)
        roundData(&rdata, precision: precision, error: error)

        let absoluteDataStr = cleanupOutDataPath(adata, params: params, command: Character(command.uppercased()))
        let relativeDataStr = cleanupOutDataPath(rdata, params: params, command: command)

        // Convert to absolute if shorter or forced
        if params.forceAbsolutePath
            || (absoluteDataStr.count < relativeDataStr.count
                && !(params.negativeExtraSpace
                     && command == Character(prev.command.lowercased())
                     && prev.command.asciiValue.map({ $0 > 96 }) == true
                     && absoluteDataStr.count == relativeDataStr.count - 1
                     && (data[0] < 0
                         || (data[0].truncatingRemainder(dividingBy: 1) != 0
                             && floor(data[0]) == 0
                             && prev.args[prev.args.count - 1].truncatingRemainder(dividingBy: 1) != 0)))) {
            item.command = Character(command.uppercased())
            item.args = adata
        }

        prev = item
        result.append(item)
    }

    return result
}

// MARK: - Geometry Helpers

/// Check if curve is convex.
private func isConvex(_ data: [Double]) -> Bool {
    guard data.count >= 6 else { return false }
    guard let center = getIntersection([0, 0, data[2], data[3], data[0], data[1], data[4], data[5]]) else {
        return false
    }
    return (data[2] < center[0]) == (center[0] < 0)
        && (data[3] < center[1]) == (center[1] < 0)
        && (data[4] < center[0]) == (center[0] < data[0])
        && (data[5] < center[1]) == (center[1] < data[1])
}

/// Compute intersection of two lines.
private func getIntersection(_ coords: [Double]) -> [Double]? {
    let a1 = coords[1] - coords[3]
    let b1 = coords[2] - coords[0]
    let c1 = coords[0] * coords[3] - coords[2] * coords[1]
    let a2 = coords[5] - coords[7]
    let b2 = coords[6] - coords[4]
    let c2 = coords[4] * coords[7] - coords[5] * coords[6]
    let denom = a1 * b2 - a2 * b1

    if denom == 0 { return nil }

    let cross = [(b1 * c2 - b2 * c1) / denom, (a1 * c2 - a2 * c1) / -denom]
    if cross[0].isNaN || cross[1].isNaN || !cross[0].isFinite || !cross[1].isFinite {
        return nil
    }
    return cross
}

/// Cubic bezier point at parameter t.
private func getCubicBezierPoint(_ curve: [Double], t: Double) -> [Double] {
    let sqrT = t * t
    let cubT = sqrT * t
    let mt = 1 - t
    let sqrMt = mt * mt
    return [
        3 * sqrMt * t * curve[0] + 3 * mt * sqrT * curve[2] + cubT * curve[4],
        3 * sqrMt * t * curve[1] + 3 * mt * sqrT * curve[3] + cubT * curve[5],
    ]
}

/// Distance between two points.
private func getDistance(_ p1: [Double], _ p2: [Double]) -> Double {
    return hypot(p1[0] - p2[0], p1[1] - p2[1])
}

/// Find circle through 3 points of a cubic bezier curve.
private func findCircle(_ curve: [Double], arcThreshold: Double, arcTolerance: Double, error: Double) -> Circle? {
    guard curve.count >= 6 else { return nil }
    let midPoint = getCubicBezierPoint(curve, t: 0.5)
    let m1 = [midPoint[0] / 2, midPoint[1] / 2]
    let m2 = [(midPoint[0] + curve[4]) / 2, (midPoint[1] + curve[5]) / 2]
    guard let center = getIntersection([
        m1[0], m1[1],
        m1[0] + m1[1], m1[1] - m1[0],
        m2[0], m2[1],
        m2[0] + (m2[1] - midPoint[1]), m2[1] - (m2[0] - midPoint[0]),
    ]) else { return nil }

    let radius = getDistance([0, 0], center)
    let tolerance = min(arcThreshold * error, arcTolerance * radius / 100)

    guard radius < 1e15 else { return nil }

    for point in [0.25, 0.75] {
        if abs(getDistance(getCubicBezierPoint(curve, t: point), center) - radius) > tolerance {
            return nil
        }
    }

    return Circle(center: center, radius: radius)
}

/// Check if curve fits the given circle.
private func isArc(_ curve: [Double], circle: Circle, arcThreshold: Double, arcTolerance: Double, error: Double) -> Bool {
    let tolerance = min(arcThreshold * error, arcTolerance * circle.radius / 100)
    for point in [0.0, 0.25, 0.5, 0.75, 1.0] {
        if abs(getDistance(getCubicBezierPoint(curve, t: point), circle.center) - circle.radius) > tolerance {
            return false
        }
    }
    return true
}

/// Check if previous curve fits the given circle.
private func isArcPrev(_ curve: [Double], circle: Circle) -> Bool {
    guard curve.count >= 6 else { return false }
    // We cannot call isArc here because we don't have the params, so inline it
    // Actually, we need the error params. Let's use a simple tolerance.
    let shiftedCenter = [circle.center[0] + curve[4], circle.center[1] + curve[5]]
    let shiftedCircle = Circle(center: shiftedCenter, radius: circle.radius)
    // Use a generous tolerance for prev check
    for point in [0.0, 0.25, 0.5, 0.75, 1.0] {
        let ptOnCurve = getCubicBezierPoint(curve, t: point)
        let dist = getDistance(ptOnCurve, shiftedCircle.center)
        // Use 1% tolerance
        if abs(dist - shiftedCircle.radius) > shiftedCircle.radius * 0.01 + 0.01 {
            return false
        }
    }
    return true
}

/// Find angle of curve fitting arc.
private func findArcAngle(_ curve: [Double], circle: Circle) -> Double {
    guard curve.count >= 6 else { return 0 }
    let x1 = -circle.center[0]
    let y1 = -circle.center[1]
    let x2 = curve[4] - circle.center[0]
    let y2 = curve[5] - circle.center[1]
    let cosVal = (x1 * x2 + y1 * y2) / sqrt((x1 * x1 + y1 * y1) * (x2 * x2 + y2 * y2))
    return acos(max(-1, min(1, cosVal)))
}

/// Check if a curve is a straight line.
private func isCurveStraightLine(_ data: [Double], error: Double) -> Bool {
    var i = data.count - 2
    let a = -data[i + 1]  // y1 - y2 (y1 = 0)
    let b = data[i]       // x2 - x1 (x1 = 0)
    let d = 1.0 / (a * a + b * b)

    if i <= 1 || !d.isFinite { return false }

    i -= 2
    while i >= 0 {
        if sqrt(pow(a * data[i] + b * data[i + 1], 2) * d) > error {
            return false
        }
        i -= 2
    }
    return true
}

/// Calculate sagitta of an arc.
private func calculateSagitta(_ data: [Double], error: Double) -> Double? {
    guard data.count >= 7 else { return nil }
    if data[3] == 1 { return nil }
    let rx = data[0], ry = data[1]
    if abs(rx - ry) > error { return nil }
    let chord = hypot(data[5], data[6])
    if chord > rx * 2 { return nil }
    return rx - sqrt(rx * rx - 0.25 * chord * chord)
}

/// Convert shorthand curve to longhand.
private func makeLonghand(_ item: inout ExtPathItem, prevData: [Double]) {
    let n = prevData.count
    guard n >= 4 else { return }
    switch item.command {
    case "s": item.command = "c"
    case "t": item.command = "q"
    default: return
    }
    item.args.insert(prevData[n - 1] - prevData[n - 3], at: 0)
    item.args.insert(prevData[n - 2] - prevData[n - 4], at: 0)
}

/// Reflect a point across another point.
private func reflectPoint(_ controlPoint: [Double], base: [Double]) -> [Double] {
    return [2 * base[0] - controlPoint[0], 2 * base[1] - controlPoint[1]]
}
