// FixtureParser.swift
// Parser for SVGO plugin test fixture files (*.svg.txt)
// okooo5km(十里)

import Foundation

/// Error types for fixture parsing
public enum FixtureParserError: Error, CustomStringConvertible {
    case invalidFilename(String)
    case missingSeparator(String)
    case emptyInput(String)
    case emptyExpected(String)

    public var description: String {
        switch self {
        case .invalidFilename(let name):
            return "Invalid fixture filename: \(name) (expected: pluginName.NN.svg.txt)"
        case .missingSeparator(let file):
            return "Missing @@@ separator in fixture file: \(file)"
        case .emptyInput(let file):
            return "Empty input SVG in fixture file: \(file)"
        case .emptyExpected(let file):
            return "Empty expected SVG in fixture file: \(file)"
        }
    }
}

/// A parsed plugin test fixture case
public struct PluginFixtureCase: Sendable {
    /// Plugin name extracted from filename
    public let pluginName: String
    /// Test case index (e.g. "01")
    public let index: String
    /// Original fixture filename (e.g. "prefixIds.01.svg.txt")
    public let filename: String
    /// Optional description from the fixture file
    public let description: String?
    /// Input SVG
    public let inputSVG: String
    /// Expected output SVG
    public let expectedSVG: String
    /// Optional plugin parameters as JSON string
    public let paramsJSON: String?

    /// A display label for test output
    public var label: String {
        let desc = description.map { " - \($0)" } ?? ""
        return "\(pluginName).\(index)\(desc)"
    }
}

/// Parse a fixture file at the given path
public func parseFixtureFile(at path: String) throws -> PluginFixtureCase {
    let url = URL(fileURLWithPath: path)
    let filename = url.lastPathComponent
    let content = try String(contentsOf: url, encoding: .utf8)
    return try parseFixtureContent(content, filename: filename)
}

/// Parse fixture content with given filename for metadata extraction
public func parseFixtureContent(_ content: String, filename: String) throws -> PluginFixtureCase {
    // 1. Extract plugin name and index from filename
    let (pluginName, index) = try extractMetadata(from: filename)

    // 2. Normalize content: trim outer whitespace, normalize line endings
    let normalized = content
        .replacingOccurrences(of: "\r\n", with: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    // 3. Check for description separator (===)
    var description: String? = nil
    var mainContent: String

    // Use regex to split on \s*===\s* (only first occurrence)
    if let equalsRange = normalized.range(
        of: #"\s*===\s*"#,
        options: .regularExpression
    ) {
        let before = String(normalized[normalized.startIndex..<equalsRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let after = String(normalized[equalsRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !before.isEmpty {
            description = before
        }
        mainContent = after
    } else {
        mainContent = normalized
    }

    // 4. Split on @@@ separator
    let atParts = splitOnSeparator(mainContent, separator: #"\s*@@@\s*"#)

    guard atParts.count >= 2 else {
        throw FixtureParserError.missingSeparator(filename)
    }

    let inputSVG = atParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
    let expectedSVG = atParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
    let paramsJSON: String? = atParts.count >= 3
        ? atParts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        : nil

    guard !inputSVG.isEmpty else {
        throw FixtureParserError.emptyInput(filename)
    }
    guard !expectedSVG.isEmpty else {
        throw FixtureParserError.emptyExpected(filename)
    }

    return PluginFixtureCase(
        pluginName: pluginName,
        index: index,
        filename: filename,
        description: description,
        inputSVG: inputSVG,
        expectedSVG: expectedSVG,
        paramsJSON: paramsJSON?.isEmpty == true ? nil : paramsJSON
    )
}

// MARK: - Private Helpers

/// Extract plugin name and test index from a fixture filename
private func extractMetadata(from filename: String) throws -> (pluginName: String, index: String) {
    // Pattern: pluginName.NN.svg.txt
    let pattern = #"^(.+)\.(\d+)\.svg\.txt$"#
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(
              in: filename,
              range: NSRange(filename.startIndex..., in: filename)
          ),
          match.numberOfRanges == 3,
          let nameRange = Range(match.range(at: 1), in: filename),
          let indexRange = Range(match.range(at: 2), in: filename)
    else {
        throw FixtureParserError.invalidFilename(filename)
    }

    return (String(filename[nameRange]), String(filename[indexRange]))
}

/// Split a string on a regex separator pattern, returning all parts
private func splitOnSeparator(_ string: String, separator: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: separator) else {
        return [string]
    }

    let nsString = string as NSString
    let fullRange = NSRange(location: 0, length: nsString.length)
    let matches = regex.matches(in: string, range: fullRange)

    if matches.isEmpty {
        return [string]
    }

    var parts: [String] = []
    var lastEnd = 0

    for match in matches {
        let partRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
        parts.append(nsString.substring(with: partRange))
        lastEnd = match.range.location + match.range.length
    }

    // Add the remaining part after the last separator
    if lastEnd <= nsString.length {
        let remaining = nsString.substring(from: lastEnd)
        parts.append(remaining)
    }

    return parts
}

// MARK: - Batch Loading

/// Load all fixture files from a directory for a specific plugin
public func loadFixtures(
    forPlugin pluginName: String,
    fromDirectory directory: String
) throws -> [PluginFixtureCase] {
    let fm = FileManager.default
    let files = try fm.contentsOfDirectory(atPath: directory)
        .filter { $0.hasPrefix("\(pluginName).") && $0.hasSuffix(".svg.txt") }
        .sorted()

    return try files.map { filename in
        let path = (directory as NSString).appendingPathComponent(filename)
        return try parseFixtureFile(at: path)
    }
}

/// Load all fixture files from a directory
public func loadAllFixtures(fromDirectory directory: String) throws -> [PluginFixtureCase] {
    let fm = FileManager.default
    let files = try fm.contentsOfDirectory(atPath: directory)
        .filter { $0.hasSuffix(".svg.txt") }
        .sorted()

    return try files.compactMap { filename in
        let path = (directory as NSString).appendingPathComponent(filename)
        return try parseFixtureFile(at: path)
    }
}
