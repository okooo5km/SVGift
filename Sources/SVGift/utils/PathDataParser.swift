// PathDataParser.swift
// SVG path data parser (parsePathData state machine)
// okooo5km(十里)

import Foundation

/// Argument count per SVG path command.
private let argsCountPerCommand: [Character: Int] = [
    "M": 2, "m": 2,
    "Z": 0, "z": 0,
    "L": 2, "l": 2,
    "H": 1, "h": 1,
    "V": 1, "v": 1,
    "C": 6, "c": 6,
    "S": 4, "s": 4,
    "Q": 4, "q": 4,
    "T": 2, "t": 2,
    "A": 7, "a": 7,
]

private func isCommand(_ c: Character) -> Bool {
    argsCountPerCommand[c] != nil
}

private func isWhiteSpace(_ c: Character) -> Bool {
    c == " " || c == "\t" || c == "\r" || c == "\n"
}

private func isDigit(_ c: Character) -> Bool {
    guard let v = c.asciiValue else { return false }
    return v >= 48 && v <= 57
}

/// State machine states for readNumber.
private enum ReadNumberState {
    case none, sign, whole, decimalPoint, decimal, e, exponentSign, exponent
}

/// Read a number starting at `cursor` in `chars`.
/// Returns (newCursor, number) where number is nil if no valid number found.
/// newCursor points to the last character consumed.
private func readNumber(_ chars: [Character], _ cursor: Int) -> (Int, Double?) {
    var i = cursor
    var value = ""
    var state = ReadNumberState.none

    while i < chars.count {
        let c = chars[i]
        if c == "+" || c == "-" {
            if state == .none {
                state = .sign
                value.append(c)
                i += 1; continue
            }
            if state == .e {
                state = .exponentSign
                value.append(c)
                i += 1; continue
            }
        }
        if isDigit(c) {
            if state == .none || state == .sign || state == .whole {
                state = .whole
                value.append(c)
                i += 1; continue
            }
            if state == .decimalPoint || state == .decimal {
                state = .decimal
                value.append(c)
                i += 1; continue
            }
            if state == .e || state == .exponentSign || state == .exponent {
                state = .exponent
                value.append(c)
                i += 1; continue
            }
        }
        if c == "." {
            if state == .none || state == .sign || state == .whole {
                state = .decimalPoint
                value.append(c)
                i += 1; continue
            }
        }
        if c == "E" || c == "e" {
            if state == .whole || state == .decimalPoint || state == .decimal {
                state = .e
                value.append(c)
                i += 1; continue
            }
        }
        break
    }

    if let number = Double(value), !number.isNaN {
        return (i - 1, number)
    }
    return (cursor, nil)
}

/// Parse SVG path data string into array of PathDataItem.
/// Matches SVGO's `parsePathData` behavior exactly.
public func parsePathData(_ string: String) -> [PathDataItem] {
    let chars = Array(string)
    var pathData: [PathDataItem] = []
    var command: Character? = nil
    var args: [Double] = []
    var argsCount = 0
    var canHaveComma = false
    var hadComma = false

    var i = 0
    while i < chars.count {
        let c = chars[i]

        if isWhiteSpace(c) {
            i += 1; continue
        }

        // allow comma only between arguments
        if canHaveComma && c == "," {
            if hadComma { break }
            hadComma = true
            i += 1; continue
        }

        if isCommand(c) {
            if hadComma { return pathData }
            if command == nil {
                // moveto should be leading command
                if c != "M" && c != "m" { return pathData }
            } else if !args.isEmpty {
                // stop if previous command arguments are not flushed
                return pathData
            }
            command = c
            args = []
            argsCount = argsCountPerCommand[c]!
            canHaveComma = false
            // flush command without arguments
            if argsCount == 0 {
                pathData.append(PathDataItem(command: c, args: []))
            }
            i += 1; continue
        }

        // avoid parsing arguments if no command detected
        guard let cmd = command else { return pathData }

        // read next argument
        var newCursor = i
        var number: Double? = nil

        if cmd == "A" || cmd == "a" {
            let position = args.count
            if position == 0 || position == 1 {
                // allow only positive number without sign as first two arguments
                if c != "+" && c != "-" {
                    (newCursor, number) = readNumber(chars, i)
                }
            }
            if position == 2 || position == 5 || position == 6 {
                (newCursor, number) = readNumber(chars, i)
            }
            if position == 3 || position == 4 {
                // read flags
                if c == "0" { number = 0 }
                if c == "1" { number = 1 }
            }
        } else {
            (newCursor, number) = readNumber(chars, i)
        }

        guard let num = number else { return pathData }
        args.append(num)
        canHaveComma = true
        hadComma = false
        i = newCursor

        // flush arguments when necessary count is reached
        if args.count == argsCount {
            pathData.append(PathDataItem(command: cmd, args: args))
            // subsequent moveto coordinates are treated as implicit lineto commands
            if cmd == "M" { command = "L" }
            if cmd == "m" { command = "l" }
            args = []
        }

        i += 1
    }

    return pathData
}
