// NumericUtils.swift
// Numeric rounding, formatting, and leading-zero removal utilities
// okooo5km(十里)

import Foundation

/// Round a number to fixed precision, matching JS `Math.round(num * 10^p) / 10^p`.
public func toFixed(_ num: Double, _ precision: Int) -> Double {
    let pow = Foundation.pow(10.0, Double(precision))
    return (num * pow).rounded() / pow
}

/// Remove the leading zero from small decimals:
/// `0.5` → `".5"`, `-0.5` → `"-.5"`.
/// Also normalizes exponent notation: `1e-07` → `1e-7`.
public func removeLeadingZero(_ value: Double) -> String {
    // Eliminate negative zero
    var v = value
    if v == 0 { v = 0 }

    let str = jsToString(v)

    if v > 0 && v < 1 && str.hasPrefix("0") {
        return String(str.dropFirst())
    }

    if v > -1 && v < 0 && str.count >= 2 && str[str.index(after: str.startIndex)] == "0" {
        // "-0.xxx" → "-.xxx"
        return String(str.first!) + String(str.dropFirst(2))
    }

    return str
}

/// Stringify a number with precision rounding and optional leading-zero removal.
public func stringifyNumber(_ value: Double, precision: Int, leadingZero: Bool = true) -> String {
    var num = toFixed(value, precision)
    // Eliminate negative zero
    if num == 0 { num = 0 }

    if leadingZero {
        return removeLeadingZero(num)
    } else {
        return jsToString(num)
    }
}

/// Convert a Double to String matching JavaScript's `Number.toString()` behavior:
/// integer-valued doubles omit the decimal point (e.g. `10.0` → `"10"`).
public func jsToString(_ value: Double) -> String {
    var v = value
    if v == 0 { v = 0 }
    // Check for integer value
    if v == v.rounded() && !v.isInfinite && abs(v) < 1e15 {
        return String(Int(v))
    }
    return normalizeExponent(String(v))
}

/// Normalize exponent notation: remove leading zeros in exponent part.
/// e.g. "1e-07" → "1e-7", "1e+03" → "1e+3"
private func normalizeExponent(_ str: String) -> String {
    guard let eIdx = str.firstIndex(where: { $0 == "e" || $0 == "E" }) else {
        return str
    }

    let base = str[str.startIndex..<eIdx]
    var expPart = String(str[str.index(after: eIdx)...])

    // Remove leading zeros from exponent (preserve sign)
    var sign = ""
    if expPart.hasPrefix("+") || expPart.hasPrefix("-") {
        sign = String(expPart.first!)
        expPart = String(expPart.dropFirst())
    }

    // Remove leading zeros
    let stripped = String(expPart.drop(while: { $0 == "0" }))
    let normalizedExp = stripped.isEmpty ? "0" : stripped

    return base + "e" + sign + normalizedExp
}
