// PathIntersection.swift
// GJK collision detection for SVG paths
// okooo5km(十里)

import Foundation

// MARK: - Point Types

/// A convex hull or subpath point set with extremes tracking.
private struct PointSet {
    var list: [[Double]] = []
    var minX: Int = 0
    var minY: Int = 0
    var maxX: Int = 0
    var maxY: Int = 0
}

/// Collection of subpath point sets with global bounds.
private struct Points {
    var list: [PointSet] = []
    var minX: Double = 0
    var minY: Double = 0
    var maxX: Double = 0
    var maxY: Double = 0
}

// MARK: - Public API

/// Check if two paths have an intersection using convex hull + GJK algorithm.
public func pathsIntersect(_ path1: [PathDataItem], _ path2: [PathDataItem]) -> Bool {
    let points1 = gatherPoints(convertRelativeToAbsolute(path1))
    let points2 = gatherPoints(convertRelativeToAbsolute(path2))

    // AABB check
    if points1.maxX <= points2.minX || points2.maxX <= points1.minX
        || points1.maxY <= points2.minY || points2.maxY <= points1.minY {
        return false
    }

    // Per-subpath AABB check
    let allSeparated = points1.list.allSatisfy { set1 in
        points2.list.allSatisfy { set2 in
            guard !set1.list.isEmpty && !set2.list.isEmpty else { return true }
            return set1.list[set1.maxX][0] <= set2.list[set2.minX][0]
                || set2.list[set2.maxX][0] <= set1.list[set1.minX][0]
                || set1.list[set1.maxY][1] <= set2.list[set2.minY][1]
                || set2.list[set2.maxY][1] <= set1.list[set1.minY][1]
        }
    }
    if allSeparated { return false }

    // Build convex hulls
    let hullNest1 = points1.list.map { convexHull($0) }
    let hullNest2 = points2.list.map { convexHull($0) }

    // GJK collision detection
    for hull1 in hullNest1 {
        if hull1.list.count < 3 { continue }
        for hull2 in hullNest2 {
            if hull2.list.count < 3 { continue }
            if gjk(hull1, hull2) { return true }
        }
    }

    return false
}

// MARK: - Convert Relative to Absolute

private func convertRelativeToAbsolute(_ data: [PathDataItem]) -> [PathDataItem] {
    var result: [PathDataItem] = []
    var start: [Double] = [0, 0]
    var cursor: [Double] = [0, 0]

    for item in data {
        var command = item.command
        var args = item.args

        if command == "m" {
            args[0] += cursor[0]; args[1] += cursor[1]; command = "M"
        }
        if command == "M" {
            cursor[0] = args[0]; cursor[1] = args[1]
            start[0] = cursor[0]; start[1] = cursor[1]
        }
        if command == "h" { args[0] += cursor[0]; command = "H" }
        if command == "H" { cursor[0] = args[0] }
        if command == "v" { args[0] += cursor[1]; command = "V" }
        if command == "V" { cursor[1] = args[0] }
        if command == "l" {
            args[0] += cursor[0]; args[1] += cursor[1]; command = "L"
        }
        if command == "L" { cursor[0] = args[0]; cursor[1] = args[1] }
        if command == "c" {
            for j in stride(from: 0, to: 6, by: 2) { args[j] += cursor[0]; args[j+1] += cursor[1] }
            command = "C"
        }
        if command == "C" { cursor[0] = args[4]; cursor[1] = args[5] }
        if command == "s" {
            for j in stride(from: 0, to: 4, by: 2) { args[j] += cursor[0]; args[j+1] += cursor[1] }
            command = "S"
        }
        if command == "S" { cursor[0] = args[2]; cursor[1] = args[3] }
        if command == "q" {
            for j in stride(from: 0, to: 4, by: 2) { args[j] += cursor[0]; args[j+1] += cursor[1] }
            command = "Q"
        }
        if command == "Q" { cursor[0] = args[2]; cursor[1] = args[3] }
        if command == "t" {
            args[0] += cursor[0]; args[1] += cursor[1]; command = "T"
        }
        if command == "T" { cursor[0] = args[0]; cursor[1] = args[1] }
        if command == "a" {
            args[5] += cursor[0]; args[6] += cursor[1]; command = "A"
        }
        if command == "A" { cursor[0] = args[5]; cursor[1] = args[6] }
        if command == "z" || command == "Z" {
            cursor[0] = start[0]; cursor[1] = start[1]; command = "z"
        }

        result.append(PathDataItem(command: command, args: args))
    }
    return result
}

// MARK: - Gather Points

/// Add a point to a PointSet, returning updated global bounds.
private func addPointToSet(
    _ path: inout PointSet,
    _ point: [Double],
    globalMinX: Double, globalMinY: Double,
    globalMaxX: Double, globalMaxY: Double,
    hasGlobalPoints: Bool
) -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
    var gMinX = globalMinX, gMinY = globalMinY
    var gMaxX = globalMaxX, gMaxY = globalMaxY
    if path.list.isEmpty || point[1] > path.list[path.maxY][1] {
        path.maxY = path.list.count
        gMaxY = hasGlobalPoints ? max(point[1], gMaxY) : point[1]
    }
    if path.list.isEmpty || point[0] > path.list[path.maxX][0] {
        path.maxX = path.list.count
        gMaxX = hasGlobalPoints ? max(point[0], gMaxX) : point[0]
    }
    if path.list.isEmpty || point[1] < path.list[path.minY][1] {
        path.minY = path.list.count
        gMinY = hasGlobalPoints ? min(point[1], gMinY) : point[1]
    }
    if path.list.isEmpty || point[0] < path.list[path.minX][0] {
        path.minX = path.list.count
        gMinX = hasGlobalPoints ? min(point[0], gMinX) : point[0]
    }
    path.list.append(point)
    return (gMinX, gMinY, gMaxX, gMaxY)
}

private func gatherPoints(_ pathData: [PathDataItem]) -> Points {
    var points = Points()
    var prevCtrlPoint: [Double] = [0, 0]
    var totalPointCount = 0

    func addPt(_ subPathIdx: Int, _ point: [Double]) {
        let hasGlobal = totalPointCount > 0
        let bounds = addPointToSet(
            &points.list[subPathIdx], point,
            globalMinX: points.minX, globalMinY: points.minY,
            globalMaxX: points.maxX, globalMaxY: points.maxY,
            hasGlobalPoints: hasGlobal
        )
        points.minX = bounds.minX; points.minY = bounds.minY
        points.maxX = bounds.maxX; points.maxY = bounds.maxY
        totalPointCount += 1
    }

    for i in 0..<pathData.count {
        let item = pathData[i]
        var subPathIdx = points.list.isEmpty ? -1 : points.list.count - 1
        let prev = i == 0 ? nil : pathData[i - 1]

        if subPathIdx < 0 {
            points.list.append(PointSet())
            subPathIdx = 0
        }

        let basePoint = points.list[subPathIdx].list.isEmpty
            ? nil
            : points.list[subPathIdx].list.last
        let data = item.args

        switch item.command {
        case "M":
            points.list.append(PointSet())
            subPathIdx = points.list.count - 1

        case "H":
            if let bp = basePoint {
                addPt(subPathIdx, [data[0], bp[1]])
            }

        case "V":
            if let bp = basePoint {
                addPt(subPathIdx, [bp[0], data[0]])
            }

        case "Q":
            addPt(subPathIdx, Array(data[0..<2]))
            prevCtrlPoint = [data[2] - data[0], data[3] - data[1]]

        case "T":
            if let bp = basePoint, let p = prev, (p.command == "Q" || p.command == "T") {
                let ctrlPoint = [bp[0] + prevCtrlPoint[0], bp[1] + prevCtrlPoint[1]]
                addPt(subPathIdx, ctrlPoint)
                prevCtrlPoint = [data[0] - ctrlPoint[0], data[1] - ctrlPoint[1]]
            }

        case "C":
            if let bp = basePoint {
                addPt(subPathIdx, [
                    0.5 * (bp[0] + data[0]), 0.5 * (bp[1] + data[1]),
                ])
            }
            addPt(subPathIdx, [
                0.5 * (data[0] + data[2]), 0.5 * (data[1] + data[3]),
            ])
            addPt(subPathIdx, [
                0.5 * (data[2] + data[4]), 0.5 * (data[3] + data[5]),
            ])
            prevCtrlPoint = [data[4] - data[2], data[5] - data[3]]

        case "S":
            if let bp = basePoint, let p = prev, (p.command == "C" || p.command == "S") {
                addPt(subPathIdx, [
                    bp[0] + 0.5 * prevCtrlPoint[0], bp[1] + 0.5 * prevCtrlPoint[1],
                ])
                let ctrlPoint = [bp[0] + prevCtrlPoint[0], bp[1] + prevCtrlPoint[1]]
                addPt(subPathIdx, [
                    0.5 * (ctrlPoint[0] + data[0]), 0.5 * (ctrlPoint[1] + data[1]),
                ])
            }
            addPt(subPathIdx, [
                0.5 * (data[0] + data[2]), 0.5 * (data[1] + data[3]),
            ])
            prevCtrlPoint = [data[2] - data[0], data[3] - data[1]]

        case "A":
            if let bp = basePoint {
                let curves = arcToCubic(
                    x1: bp[0], y1: bp[1],
                    rx: data[0], ry: data[1], angle: data[2],
                    largeArcFlag: data[3], sweepFlag: data[4],
                    x2: data[5], y2: data[6]
                )
                var currentBase = bp
                var curveIdx = 0
                while curveIdx + 5 < curves.count {
                    let cData = Array(curves[curveIdx..<curveIdx + 6]).enumerated().map { (idx, n) in
                        n + (currentBase[idx % 2])
                    }
                    addPt(subPathIdx, [
                        0.5 * (currentBase[0] + cData[0]), 0.5 * (currentBase[1] + cData[1]),
                    ])
                    addPt(subPathIdx, [
                        0.5 * (cData[0] + cData[2]), 0.5 * (cData[1] + cData[3]),
                    ])
                    addPt(subPathIdx, [
                        0.5 * (cData[2] + cData[4]), 0.5 * (cData[3] + cData[5]),
                    ])
                    curveIdx += 6
                    if curveIdx + 5 < curves.count {
                        currentBase = [cData[4], cData[5]]
                        addPt(subPathIdx, currentBase)
                    }
                }
            }

        default:
            break
        }

        // Save final command coordinates
        if data.count >= 2 {
            addPt(subPathIdx, Array(data.suffix(2)))
        }
    }

    return points
}

// MARK: - Arc to Cubic Bezier (a2c)

/// Convert an arc to one or more cubic Bezier curves.
/// Returns flat array of relative curve control points [x1,y1,x2,y2,x,y,...].
public func arcToCubic(
    x1: Double, y1: Double,
    rx inRx: Double, ry inRy: Double, angle: Double,
    largeArcFlag: Double, sweepFlag: Double,
    x2: Double, y2: Double,
    recursive: [Double]? = nil
) -> [Double] {
    let _120 = Double.pi * 120 / 180
    let rad = Double.pi / 180 * angle
    var res: [Double] = []

    let rotateX = { (x: Double, y: Double, rad: Double) -> Double in x * cos(rad) - y * sin(rad) }
    let rotateY = { (x: Double, y: Double, rad: Double) -> Double in x * sin(rad) + y * cos(rad) }

    var rx = inRx, ry = inRy
    var x1 = x1, y1 = y1, x2 = x2, y2 = y2
    var f1: Double, f2: Double, cx: Double, cy: Double

    if let rec = recursive {
        f1 = rec[0]; f2 = rec[1]; cx = rec[2]; cy = rec[3]
    } else {
        x1 = rotateX(x1, y1, -rad)
        y1 = rotateY(x1, y1, -rad)
        x2 = rotateX(x2, y2, -rad)
        y2 = rotateY(x2, y2, -rad)
        let x = (x1 - x2) / 2
        let y = (y1 - y2) / 2
        var h = (x * x) / (rx * rx) + (y * y) / (ry * ry)
        if h > 1 {
            h = sqrt(h)
            rx = h * rx
            ry = h * ry
        }
        let rx2 = rx * rx
        let ry2 = ry * ry
        let k = (largeArcFlag == sweepFlag ? -1.0 : 1.0)
            * sqrt(abs((rx2 * ry2 - rx2 * y * y - ry2 * x * x) / (rx2 * y * y + ry2 * x * x)))
        cx = k * rx * y / ry + (x1 + x2) / 2
        cy = k * -ry * x / rx + (y1 + y2) / 2

        let clampedF1 = max(-1.0, min(1.0, Double(String(format: "%.9f", (y1 - cy) / ry))!))
        let clampedF2 = max(-1.0, min(1.0, Double(String(format: "%.9f", (y2 - cy) / ry))!))
        f1 = asin(clampedF1)
        f2 = asin(clampedF2)

        if x1 < cx { f1 = .pi - f1 }
        if x2 < cx { f2 = .pi - f2 }
        if f1 < 0 { f1 = .pi * 2 + f1 }
        if f2 < 0 { f2 = .pi * 2 + f2 }
        if sweepFlag != 0 && f1 > f2 { f1 = f1 - .pi * 2 }
        if sweepFlag == 0 && f2 > f1 { f2 = f2 - .pi * 2 }
    }

    var df = f2 - f1
    if abs(df) > _120 {
        let f2old = f2
        let x2old = x2
        let y2old = y2
        f2 = f1 + _120 * (sweepFlag != 0 && f2 > f1 ? 1 : -1)
        x2 = cx + rx * cos(f2)
        y2 = cy + ry * sin(f2)
        res = arcToCubic(
            x1: x2, y1: y2, rx: rx, ry: ry, angle: angle,
            largeArcFlag: 0, sweepFlag: sweepFlag,
            x2: x2old, y2: y2old,
            recursive: [f2, f2old, cx, cy]
        )
    }

    df = f2 - f1
    let c1 = cos(f1), s1 = sin(f1)
    let c2 = cos(f2), s2 = sin(f2)
    let t = tan(df / 4)
    let hx = 4.0 / 3.0 * rx * t
    let hy = 4.0 / 3.0 * ry * t
    let m: [Double] = [
        -hx * s1, hy * c1,
        x2 + hx * s2 - x1, y2 - hy * c2 - y1,
        x2 - x1, y2 - y1,
    ]

    if recursive != nil {
        return m + res
    } else {
        res = m + res
        var newres: [Double] = Array(repeating: 0, count: res.count)
        for i in 0..<res.count {
            newres[i] = i % 2 != 0
                ? rotateY(res[i - 1], res[i], rad)
                : rotateX(res[i], res[i + 1], rad)
        }
        return newres
    }
}

// MARK: - Convex Hull (Monotone Chain)

private func convexHull(_ points: PointSet) -> PointSet {
    if points.list.isEmpty { return points }
    var pts = points
    pts.list.sort { a, b in
        a[0] == b[0] ? a[1] < b[1] : a[0] < b[0]
    }

    var lower: [[Double]] = []
    var minY = 0, bottom = 0
    for i in 0..<pts.list.count {
        while lower.count >= 2
            && cross(lower[lower.count - 2], lower[lower.count - 1], pts.list[i]) <= 0 {
            lower.removeLast()
        }
        if pts.list[i][1] < pts.list[minY][1] {
            minY = i; bottom = lower.count
        }
        lower.append(pts.list[i])
    }

    var upper: [[Double]] = []
    var maxY = pts.list.count - 1, top = 0
    for i in stride(from: pts.list.count - 1, through: 0, by: -1) {
        while upper.count >= 2
            && cross(upper[upper.count - 2], upper[upper.count - 1], pts.list[i]) <= 0 {
            upper.removeLast()
        }
        if pts.list[i][1] > pts.list[maxY][1] {
            maxY = i; top = upper.count
        }
        upper.append(pts.list[i])
    }

    if !upper.isEmpty { upper.removeLast() }
    if !lower.isEmpty { lower.removeLast() }

    let hullList = lower + upper
    return PointSet(
        list: hullList,
        minX: 0,
        minY: bottom,
        maxX: lower.count,
        maxY: (lower.count + top) % max(hullList.count, 1)
    )
}

private func cross(_ o: [Double], _ a: [Double], _ b: [Double]) -> Double {
    (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
}

// MARK: - GJK Algorithm

private func gjk(_ hull1: PointSet, _ hull2: PointSet) -> Bool {
    var simplex: [[Double]] = [getSupport(hull1, hull2, [1, 0])]
    var direction = minus2d(simplex[0])

    var iterations = 10000
    while true {
        iterations -= 1
        if iterations == 0 { return true }

        simplex.append(getSupport(hull1, hull2, direction))
        if dot2d(direction, simplex.last!) <= 0 { return false }
        if processSimplex(&simplex, &direction) { return true }
    }
}

private func getSupport(_ a: PointSet, _ b: PointSet, _ direction: [Double]) -> [Double] {
    sub2d(supportPoint(a, direction), supportPoint(b, minus2d(direction)))
}

private func supportPoint(_ polygon: PointSet, _ direction: [Double]) -> [Double] {
    var index: Int
    if direction[1] >= 0 {
        index = direction[0] < 0 ? polygon.maxY : polygon.maxX
    } else {
        index = direction[0] < 0 ? polygon.minX : polygon.minY
    }

    var maxVal = -Double.infinity
    var value: Double
    repeat {
        value = dot2d(polygon.list[index], direction)
        if value <= maxVal { break }
        maxVal = value
        index = (index + 1) % polygon.list.count
    } while true

    return polygon.list[(index == 0 ? polygon.list.count : index) - 1]
}

private func processSimplex(_ simplex: inout [[Double]], _ direction: inout [Double]) -> Bool {
    if simplex.count == 2 {
        let a = simplex[1], b = simplex[0]
        let ao = minus2d(a)
        let ab = sub2d(b, a)
        if dot2d(ao, ab) > 0 {
            let o = orth2d(ab, a)
            direction[0] = o[0]; direction[1] = o[1]
        } else {
            direction[0] = ao[0]; direction[1] = ao[1]
            simplex.removeFirst()
        }
    } else {
        let a = simplex[2], b = simplex[1], c = simplex[0]
        let ab = sub2d(b, a), ac = sub2d(c, a), ao = minus2d(a)
        let acb = orth2d(ab, ac) // perpendicular to AB facing away from C
        let abc = orth2d(ac, ab) // perpendicular to AC facing away from B

        if dot2d(acb, ao) > 0 {
            if dot2d(ab, ao) > 0 {
                direction[0] = acb[0]; direction[1] = acb[1]
                simplex.removeFirst() // [b, a]
            } else {
                direction[0] = ao[0]; direction[1] = ao[1]
                simplex.removeSubrange(0..<2) // [a]
            }
        } else if dot2d(abc, ao) > 0 {
            if dot2d(ac, ao) > 0 {
                direction[0] = abc[0]; direction[1] = abc[1]
                simplex.remove(at: 1) // [c, a]
            } else {
                direction[0] = ao[0]; direction[1] = ao[1]
                simplex.removeSubrange(0..<2) // [a]
            }
        } else {
            return true
        }
    }
    return false
}

// MARK: - 2D Vector Operations

private func minus2d(_ v: [Double]) -> [Double] { [-v[0], -v[1]] }
private func sub2d(_ v1: [Double], _ v2: [Double]) -> [Double] { [v1[0] - v2[0], v1[1] - v2[1]] }
private func dot2d(_ v1: [Double], _ v2: [Double]) -> Double { v1[0] * v2[0] + v1[1] * v2[1] }

private func orth2d(_ v: [Double], _ from: [Double]) -> [Double] {
    let o = [-v[1], v[0]]
    return dot2d(o, minus2d(from)) < 0 ? minus2d(o) : o
}
