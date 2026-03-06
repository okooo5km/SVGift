// PluginFixtureTests.swift
// Fixture parser tests and compatibility test framework for SVGO plugins
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Fixture Parser Tests

@Test("Parse fixture with basic format (no description, no params)")
func parseBasicFixture() throws {
    let content = """
    <svg xmlns="http://www.w3.org/2000/svg">
        <!-- test -->
    </svg>

    @@@

    <svg xmlns="http://www.w3.org/2000/svg"/>
    """

    let fixture = try parseFixtureContent(content, filename: "removeComments.01.svg.txt")

    #expect(fixture.pluginName == "removeComments")
    #expect(fixture.index == "01")
    #expect(fixture.description == nil)
    #expect(fixture.inputSVG.contains("<!-- test -->"))
    #expect(fixture.expectedSVG.contains("<svg"))
    #expect(fixture.paramsJSON == nil)
}

@Test("Parse fixture with description (=== separator)")
func parseFixtureWithDescription() throws {
    let content = """
    Add multiple attributes

    ===

    <svg xmlns="http://www.w3.org/2000/svg">
        test
    </svg>

    @@@

    <svg xmlns="http://www.w3.org/2000/svg" data-icon>
        test
    </svg>

    @@@

    {"attributes":["data-icon"]}
    """

    let fixture = try parseFixtureContent(content, filename: "addAttributesToSVGElement.01.svg.txt")

    #expect(fixture.pluginName == "addAttributesToSVGElement")
    #expect(fixture.index == "01")
    #expect(fixture.description == "Add multiple attributes")
    #expect(fixture.inputSVG.contains("<svg"))
    #expect(fixture.expectedSVG.contains("data-icon"))
    #expect(fixture.paramsJSON == "{\"attributes\":[\"data-icon\"]}")
}

@Test("Parse fixture with params but no description")
func parseFixtureWithParamsNoDescription() throws {
    let content = """
    <!--!Copyright Notice-->
    <svg xmlns="http://www.w3.org/2000/svg">
        test
    </svg>

    @@@

    <svg xmlns="http://www.w3.org/2000/svg">
        test
    </svg>

    @@@

    {"preservePatterns":false}
    """

    let fixture = try parseFixtureContent(content, filename: "removeComments.03.svg.txt")

    #expect(fixture.pluginName == "removeComments")
    #expect(fixture.index == "03")
    #expect(fixture.description == nil)
    #expect(fixture.inputSVG.contains("<!--!Copyright Notice-->"))
    #expect(fixture.paramsJSON == "{\"preservePatterns\":false}")
}

@Test("Parse fixture extracts correct plugin name and index")
func parseFixtureMetadata() throws {
    let content = "<svg/>\n\n@@@\n\n<svg/>"

    let fixture = try parseFixtureContent(content, filename: "convertPathData.23.svg.txt")
    #expect(fixture.pluginName == "convertPathData")
    #expect(fixture.index == "23")
}

@Test("Parse fixture rejects invalid filename")
func parseFixtureInvalidFilename() throws {
    let content = "<svg/>\n\n@@@\n\n<svg/>"

    #expect(throws: FixtureParserError.self) {
        try parseFixtureContent(content, filename: "badname.svg")
    }
}

@Test("Parse fixture rejects missing separator")
func parseFixtureMissingSeparator() throws {
    let content = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"

    #expect(throws: FixtureParserError.self) {
        try parseFixtureContent(content, filename: "removeComments.01.svg.txt")
    }
}

@Test("Fixture label includes description when present")
func fixtureLabel() throws {
    let content = "My description\n\n===\n\n<svg/>\n\n@@@\n\n<svg/>"
    let fixture = try parseFixtureContent(content, filename: "testPlugin.01.svg.txt")
    #expect(fixture.label == "testPlugin.01 - My description")

    let content2 = "<svg/>\n\n@@@\n\n<svg/>"
    let fixture2 = try parseFixtureContent(content2, filename: "testPlugin.02.svg.txt")
    #expect(fixture2.label == "testPlugin.02")
}

// MARK: - Wave 0 Plugin Fixture Parsing Verification

/// Verify that all Wave 0 plugin fixtures can be parsed correctly
@Test("Wave 0 plugin fixtures parse successfully",
      arguments: [
          "removeDoctype",
          "removeXMLProcInst",
          "removeComments",
          "removeMetadata",
          "removeTitle",
          "removeDesc",
          "removeXMLNS",
      ])
func wave0FixturesParse(pluginName: String) throws {
    let fixturesDir = fixturesDirectory()
    let fm = FileManager.default

    // Get all fixture files for this plugin
    let allFiles = try fm.contentsOfDirectory(atPath: fixturesDir)
    let pluginFiles = allFiles
        .filter { $0.hasPrefix("\(pluginName).") && $0.hasSuffix(".svg.txt") }
        .sorted()

    // Skip if no fixtures exist for this plugin (some Wave 0 plugins may not have fixtures yet)
    guard !pluginFiles.isEmpty else {
        return
    }

    for filename in pluginFiles {
        let path = (fixturesDir as NSString).appendingPathComponent(filename)
        let fixture = try parseFixtureFile(at: path)

        // Verify basic structure
        #expect(fixture.pluginName == pluginName,
                "Plugin name mismatch for \(filename)")
        #expect(!fixture.inputSVG.isEmpty,
                "Empty input SVG in \(filename)")
        #expect(!fixture.expectedSVG.isEmpty,
                "Empty expected SVG in \(filename)")
    }
}

// MARK: - Compatibility Test Framework

/// Comparison result for a fixture test
struct FixtureTestResult {
    /// Whether the output matches expected exactly (byte-identical)
    let l1Pass: Bool
    /// Whether the output matches after normalization
    let l2Pass: Bool
    /// The actual output produced
    let actualOutput: String
    /// The expected output
    let expectedOutput: String
}

/// Run a single fixture test case against a plugin
func runFixtureTest(
    _ fixture: PluginFixtureCase,
    plugin: ResolvedPlugin
) throws -> FixtureTestResult {
    // Build optimize options with the single plugin
    let pluginConfig = PluginConfig(name: plugin.name, enabled: true)
    var options = OptimizeOptions(
        path: fixture.filename,
        plugins: [pluginConfig],
        pluginRegistry: [plugin.name: plugin]
    )
    options.js2svg = StringifyOptions(pretty: true, useShortTags: true)

    // Run optimization
    let result = try optimize(fixture.inputSVG, options: options)
    let actual = result.data

    // L1: Byte-exact comparison
    let l1Pass = actual == fixture.expectedSVG

    // L2: Normalized comparison
    let normalizedActual = normalizeForL2(actual)
    let normalizedExpected = normalizeForL2(fixture.expectedSVG)
    let l2Pass = normalizedActual == normalizedExpected

    return FixtureTestResult(
        l1Pass: l1Pass,
        l2Pass: l2Pass,
        actualOutput: actual,
        expectedOutput: fixture.expectedSVG
    )
}

/// Run all fixture tests for a given plugin and return pass/fail counts
func runAllFixtureTests(
    forPlugin pluginName: String,
    plugin: ResolvedPlugin
) throws -> (l1Passed: Int, l2Passed: Int, total: Int, failures: [(PluginFixtureCase, FixtureTestResult)]) {
    let fixtures = try loadFixtures(
        forPlugin: pluginName,
        fromDirectory: fixturesDirectory()
    )

    var l1Passed = 0
    var l2Passed = 0
    var failures: [(PluginFixtureCase, FixtureTestResult)] = []

    for fixture in fixtures {
        let result = try runFixtureTest(fixture, plugin: plugin)
        if result.l1Pass { l1Passed += 1 }
        if result.l2Pass { l2Passed += 1 }
        if !result.l2Pass {
            failures.append((fixture, result))
        }
    }

    return (l1Passed, l2Passed, fixtures.count, failures)
}

// MARK: - L2 Normalization

/// Normalize SVG output for L2 (lenient) comparison
func normalizeForL2(_ svg: String) -> String {
    var result = svg

    // Normalize line endings to \n
    result = result.replacingOccurrences(of: "\r\n", with: "\n")

    // Trim leading and trailing whitespace from each line
    // (handles indentation differences, e.g. comments at different depths)
    let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
    result = lines.map { line in
        String(line).trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
    }.joined(separator: "\n")

    // Normalize -0 to 0 (standalone numeric values)
    result = result.replacingOccurrences(
        of: #"(?<![.\d])-0(?![.\d])"#,
        with: "0",
        options: .regularExpression
    )

    // Normalize self-closing tags: <tag .../> and <tag ... /> to consistent form
    result = result.replacingOccurrences(
        of: #"\s*/>"#,
        with: "/>",
        options: .regularExpression
    )

    // Collapse whitespace sequences within element tags to single space.
    // Handles XMLParser attribute value normalization (\n\t → spaces in multiline attributes).
    let tagWsPattern = try! NSRegularExpression(
        pattern: #"<[^>]+>"#,
        options: .dotMatchesLineSeparators
    )
    let nsResult = result as NSString
    let tagMatches = tagWsPattern.matches(in: result, range: NSRange(location: 0, length: nsResult.length))
    // Process in reverse to preserve positions
    for match in tagMatches.reversed() {
        guard let range = Range(match.range, in: result) else { continue }
        let tag = String(result[range])
        // Collapse any whitespace sequence (including newlines) to a single space
        let collapsed = tag.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        if collapsed != tag {
            result.replaceSubrange(range, with: collapsed)
        }
    }

    // Normalize attribute order within elements (known XMLParser limitation:
    // attribute dict is unordered, so our output uses alphabetical order
    // which may differ from SVGO's insertion order).
    result = normalizeAttributeOrder(result)

    // Trim overall leading/trailing whitespace
    result = result.trimmingCharacters(in: .whitespacesAndNewlines)

    return result
}

/// Sort attributes within each XML element tag alphabetically for comparison.
/// This handles the XMLParser limitation of not preserving original attribute order.
private func normalizeAttributeOrder(_ svg: String) -> String {
    // Match opening tags with attributes: <tagname attr1="val1" attr2="val2"...>
    // Also handles self-closing tags.
    let tagPattern = try! NSRegularExpression(
        pattern: #"<([a-zA-Z][a-zA-Z0-9:_-]*)((?:\s+[a-zA-Z:_][a-zA-Z0-9:_.-]*(?:="[^"]*")?)+)\s*(/?)>"#
    )

    let nsStr = svg as NSString
    let fullRange = NSRange(location: 0, length: nsStr.length)
    var result = svg

    // Process matches in reverse to preserve string positions
    let matches = tagPattern.matches(in: svg, range: fullRange).reversed()
    for match in matches {
        guard let tagNameRange = Range(match.range(at: 1), in: result),
              let attrsRange = Range(match.range(at: 2), in: result),
              let closeRange = Range(match.range(at: 3), in: result) else { continue }

        let tagName = String(result[tagNameRange])
        let attrsStr = String(result[attrsRange])
        let closeSlash = String(result[closeRange])

        // Parse individual attributes
        let attrPattern = try! NSRegularExpression(
            pattern: #"([a-zA-Z:_][a-zA-Z0-9:_.-]*)(?:="([^"]*)")?"#
        )
        let attrNS = attrsStr as NSString
        let attrMatches = attrPattern.matches(in: attrsStr, range: NSRange(location: 0, length: attrNS.length))

        var attrs: [(name: String, full: String)] = []
        for am in attrMatches {
            let fullAttr = attrNS.substring(with: am.range)
            guard let nameRange = Range(am.range(at: 1), in: attrsStr) else { continue }
            let name = String(attrsStr[nameRange])
            attrs.append((name: name, full: fullAttr))
        }

        // Sort by attribute name
        attrs.sort { $0.name < $1.name }

        let sortedAttrs = attrs.map(\.full).joined(separator: " ")
        let replacement = "<\(tagName) \(sortedAttrs)\(closeSlash)>"

        let fullMatchRange = Range(match.range, in: result)!
        result.replaceSubrange(fullMatchRange, with: replacement)
    }

    return result
}

// MARK: - Failure Reporting

/// Write fixture test failures to an NDJSON file
func writeFailureReport(
    _ failures: [(PluginFixtureCase, FixtureTestResult)],
    to path: String
) throws {
    let fm = FileManager.default
    let dir = (path as NSString).deletingLastPathComponent
    if !fm.fileExists(atPath: dir) {
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    var lines: [String] = []
    for (fixture, result) in failures {
        // Build a simple JSON line manually to avoid Codable boilerplate
        let escaped = { (s: String) -> String in
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
        }
        let json = """
        {"plugin":"\(escaped(fixture.pluginName))","index":"\(escaped(fixture.index))","l1":\(result.l1Pass),"l2":\(result.l2Pass),"actual":"\(escaped(result.actualOutput))","expected":"\(escaped(result.expectedOutput))"}
        """
        lines.append(json)
    }

    try lines.joined(separator: "\n").write(
        toFile: path,
        atomically: true,
        encoding: .utf8
    )
}

// MARK: - Helpers

/// Get the path to the plugin fixtures directory
func fixturesDirectory() -> String {
    // Navigate from the test file location to the Fixtures directory
    // Tests/svgo-swiftTests/ -> Tests/Fixtures/SVGO/plugins/
    let testFile = #filePath
    let testsDir = (testFile as NSString)
        .deletingLastPathComponent  // remove filename
    let projectTests = (testsDir as NSString)
        .deletingLastPathComponent  // up from svgo-swiftTests to Tests
    return (projectTests as NSString)
        .appendingPathComponent("Fixtures/SVGO/plugins")
}
