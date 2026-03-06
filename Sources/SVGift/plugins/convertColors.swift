// convertColors.swift
// Plugin to convert color values: rgb() to hex, named to hex, shorthand hex, etc.
// okooo5km(十里)

import Foundation

/// Convert color values in SVG attributes.
///
/// Parameters:
/// - `currentColor`: `"true"` converts non-none colors to `currentColor` (outside masks).
///   Can also be a specific color string to match.
/// - `names2hex`: `"true"` (default) converts named colors to hex.
/// - `rgb2hex`: `"true"` (default) converts `rgb()` to hex.
/// - `convertCase`: `"lower"` (default) lowercases hex. `"upper"` uppercases.
/// - `shorthex`: `"true"` (default) shortens `#aabbcc` to `#abc`.
/// - `shortname`: `"true"` (default) converts hex to shorter named color.
public func makeConvertColorsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "convertColors") { _, params, _ in
        let currentColor = params["currentColor"]
        let names2hex = params["names2hex"] != "false"
        let rgb2hex = params["rgb2hex"] != "false"
        let convertCase = params["convertCase"] ?? "lower"
        let shorthex = params["shorthex"] != "false"
        let shortname = params["shortname"] != "false"

        // RGB regex: rgb(r, g, b) or rgb(r g b), with optional % on values
        let rNumber = "([+-]?(?:\\d*\\.\\d+|\\d+\\.?)%?)"
        let rComma = "(?:\\s*,\\s*|\\s+)"
        let regRGB = try! NSRegularExpression(
            pattern: "^rgb\\(\\s*" + rNumber + rComma + rNumber + rComma + rNumber + "\\s*\\)$"
        )
        // Short hex: #aabbcc where each pair has identical digits
        let regHEX = try! NSRegularExpression(pattern: "^#(([a-fA-F0-9])\\2){3}$")

        var maskCounter = 0

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, _ in
                    if node.name == "mask" {
                        maskCounter += 1
                    }

                    for (name, value) in node.attributes {
                        guard colorsProps.contains(name) else { continue }
                        var val = value

                        // Convert to currentColor (outside masks)
                        if let cc = currentColor, maskCounter == 0 {
                            let matched: Bool
                            if cc == "true" {
                                matched = val != "none"
                            } else {
                                matched = val == cc
                            }
                            if matched {
                                val = "currentColor"
                            }
                        }

                        // Named color → hex
                        if names2hex {
                            if let hex = colorsNames[val.lowercased()] {
                                val = hex
                            }
                        }

                        // rgb() → hex
                        if rgb2hex {
                            let range = NSRange(val.startIndex..<val.endIndex, in: val)
                            if let match = regRGB.firstMatch(in: val, range: range) {
                                let components = (1...3).map { i -> Int in
                                    let r = match.range(at: i)
                                    let s = String(val[Range(r, in: val)!])
                                    let n: Double
                                    if s.hasSuffix("%") {
                                        n = (Double(s.dropLast()) ?? 0) * 2.55
                                    } else {
                                        n = Double(s) ?? 0
                                    }
                                    return max(0, min(Int(n.rounded()), 255))
                                }
                                val = convertRgbToHex(components[0], components[1], components[2])
                            }
                        }

                        // Case conversion (skip url references and currentColor)
                        if !convertCase.isEmpty && !includesUrlReference(val) && val != "currentColor" {
                            if convertCase == "lower" {
                                val = val.lowercased()
                            } else if convertCase == "upper" {
                                val = val.uppercased()
                            }
                        }

                        // Long hex → short hex: #aabbcc → #abc
                        if shorthex {
                            let hexRange = NSRange(val.startIndex..<val.endIndex, in: val)
                            if regHEX.firstMatch(in: val, range: hexRange) != nil && val.count == 7 {
                                let chars = Array(val)
                                val = "#" + String(chars[1]) + String(chars[3]) + String(chars[5])
                            }
                        }

                        // Hex → shorter name
                        if shortname {
                            if let name = colorsShortNames[val.lowercased()] {
                                if name.count < val.count {
                                    val = name
                                }
                            }
                        }

                        node.attributes[name] = val
                    }

                    return .continue
                },
                exit: { node, _ in
                    if node.name == "mask" {
                        maskCounter -= 1
                    }
                }
            )
        )
    }
}

/// Convert RGB components (0-255) to uppercase hex string.
private func convertRgbToHex(_ r: Int, _ g: Int, _ b: Int) -> String {
    let hexNumber = ((((256 + r) << 8) | g) << 8) | b
    let hexStr = String(hexNumber, radix: 16, uppercase: true)
    return "#" + String(hexStr.suffix(6))
}
