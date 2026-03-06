// PathDataSerializer.swift
// SVG path data serialization (stringifyPathData)
// okooo5km(十里)

import Foundation

/// A single path data command with arguments.
public struct PathDataItem {
    public var command: Character
    public var args: [Double]

    public init(command: Character, args: [Double]) {
        self.command = command
        self.args = args
    }
}

/// Serialize path data items to SVG path string.
/// Matches SVGO `stringifyPathData` behavior.
public func stringifyPathData(
    _ pathData: [PathDataItem],
    precision: Int? = nil,
    disableSpaceAfterFlags: Bool = false
) -> String {
    guard !pathData.isEmpty else { return "" }

    if pathData.count == 1 {
        let item = pathData[0]
        return String(item.command) + stringifyArgs(
            command: item.command, args: item.args,
            precision: precision, disableSpaceAfterFlags: disableSpaceAfterFlags
        )
    }

    var result = ""

    // Start with a mutable copy of the first item
    var prevCommand = pathData[0].command
    var prevArgs = pathData[0].args

    // Match leading moveto with following lineto
    if pathData[1].command == "L" {
        prevCommand = "M"
    } else if pathData[1].command == "l" {
        prevCommand = "m"
    }

    for i in 1..<pathData.count {
        let command = pathData[i].command
        let args = pathData[i].args

        let canCombine: Bool
        if prevCommand == command && prevCommand != "M" && prevCommand != "m" {
            canCombine = true
        } else if (prevCommand == "M" && command == "L") ||
                    (prevCommand == "m" && command == "l") {
            canCombine = true
        } else {
            canCombine = false
        }

        if canCombine {
            prevArgs.append(contentsOf: args)
            if i == pathData.count - 1 {
                result += String(prevCommand) + stringifyArgs(
                    command: prevCommand, args: prevArgs,
                    precision: precision, disableSpaceAfterFlags: disableSpaceAfterFlags
                )
            }
        } else {
            result += String(prevCommand) + stringifyArgs(
                command: prevCommand, args: prevArgs,
                precision: precision, disableSpaceAfterFlags: disableSpaceAfterFlags
            )

            if i == pathData.count - 1 {
                result += String(command) + stringifyArgs(
                    command: command, args: args,
                    precision: precision, disableSpaceAfterFlags: disableSpaceAfterFlags
                )
            } else {
                prevCommand = command
                prevArgs = args
            }
        }
    }

    return result
}

/// Stringify command arguments with SVGO-compatible spacing rules.
private func stringifyArgs(
    command: Character,
    args: [Double],
    precision: Int?,
    disableSpaceAfterFlags: Bool
) -> String {
    var result = ""
    var previous: Double?

    for i in 0..<args.count {
        let rounded: Double
        let roundedStr: String

        if let p = precision {
            rounded = toFixed(args[i], p)
            roundedStr = removeLeadingZero(rounded == 0 ? 0 : rounded)
        } else {
            var v = args[i]
            if v == 0 { v = 0 }
            rounded = v
            roundedStr = removeLeadingZero(v)
        }

        if disableSpaceAfterFlags &&
            (command == "A" || command == "a") &&
            (i % 7 == 4 || i % 7 == 5) {
            // Arc flag positions: no space separator
            result += roundedStr
        } else if i == 0 || rounded < 0 {
            // First arg or negative number: no leading space
            result += roundedStr
        } else if previous != nil && !isInteger(previous!) && !roundedStr.isEmpty && !isDigitChar(roundedStr.first!) {
            // Previous was decimal and current starts with "." — implicit separator
            result += roundedStr
        } else {
            result += " " + roundedStr
        }

        previous = rounded
    }

    return result
}

/// Check if a Double is an integer value.
private func isInteger(_ value: Double) -> Bool {
    value == value.rounded() && !value.isInfinite
}

/// Check if a character is an ASCII digit (0-9).
private func isDigitChar(_ c: Character) -> Bool {
    let v = c.asciiValue ?? 0
    return v >= 48 && v <= 57
}
