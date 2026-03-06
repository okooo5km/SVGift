// Wave0PluginTests.swift
// Fixture-driven tests for all Wave 0 plugins
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Wave 0 Plugin Fixture-Driven Tests

/// Test each Wave 0 plugin against all its fixture files.
/// Each test loads fixtures, runs the plugin via the optimize pipeline,
/// and compares output using L2 normalization.

@Test("removeDoctype: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeDoctype"))
func removeDoctypeFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

@Test("removeXMLProcInst: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeXMLProcInst"))
func removeXMLProcInstFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

@Test("removeComments: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeComments"))
func removeCommentsFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

@Test("removeMetadata: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeMetadata"))
func removeMetadataFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

@Test("removeTitle: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeTitle"))
func removeTitleFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

@Test("removeDesc: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeDesc"))
func removeDescFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

@Test("removeXMLNS: fixture-driven test",
      arguments: loadWave0Fixtures(plugin: "removeXMLNS"))
func removeXMLNSFixture(fixture: PluginFixtureCase) throws {
    let result = try runWave0FixtureTest(fixture)
    #expect(result.l2Pass,
            """
            \(fixture.label) failed L2 comparison.
            --- Expected ---
            \(result.expectedOutput)
            --- Actual ---
            \(result.actualOutput)
            """)
}

// MARK: - Aggregate Pass Rate Test

@Test("Wave 0 plugins: aggregate L1/L2 pass rates")
func wave0AggregatePassRates() throws {
    let wave0Plugins = [
        "removeDoctype",
        "removeXMLProcInst",
        "removeComments",
        "removeMetadata",
        "removeTitle",
        "removeDesc",
        "removeXMLNS",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in wave0Plugins {
        let fixtures = loadWave0Fixtures(plugin: pluginName)
        for fixture in fixtures {
            let result = try runWave0FixtureTest(fixture)
            totalCount += 1
            if result.l1Pass { totalL1 += 1 }
            if result.l2Pass { totalL2 += 1 }
            if !result.l2Pass {
                allFailures.append((fixture, result))
            }
        }
    }

    // Report pass rates
    let l1Rate = totalCount > 0 ? Double(totalL1) / Double(totalCount) * 100 : 0
    let l2Rate = totalCount > 0 ? Double(totalL2) / Double(totalCount) * 100 : 0

    // Write failure report if any
    if !allFailures.isEmpty {
        let testFile = #filePath
        let projectRoot = ((testFile as NSString)
            .deletingLastPathComponent as NSString)
            .deletingLastPathComponent as NSString
        let reportsDir = projectRoot.appendingPathComponent("reports")
        let reportPath = (reportsDir as NSString)
            .appendingPathComponent("wave0-failures.ndjson")
        try writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 0 fixtures found")
    #expect(l2Rate >= 95.0,
            "Wave 0 L2 pass rate \(String(format: "%.1f", l2Rate))% is below 95% target (\(totalL2)/\(totalCount))")

    // Log summary (visible in test output)
    print("Wave 0 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
}

// MARK: - Helpers

/// Load fixture cases for a given plugin, suitable for parameterized tests.
/// Returns an empty array if no fixtures exist (test will be skipped).
func loadWave0Fixtures(plugin pluginName: String) -> [PluginFixtureCase] {
    let dir = wave0FixturesDirectory()
    return (try? loadFixtures(forPlugin: pluginName, fromDirectory: dir)) ?? []
}

/// Run a single fixture test for a Wave 0 plugin, resolving the plugin
/// from the builtin registry and applying any fixture params.
func runWave0FixtureTest(_ fixture: PluginFixtureCase) throws -> FixtureTestResult {
    guard var plugin = builtinPluginRegistry[fixture.pluginName] else {
        throw SVGOError.invalidInput("Plugin '\(fixture.pluginName)' not found in builtinPluginRegistry")
    }

    // Apply fixture params if present
    if let paramsJSON = fixture.paramsJSON {
        if let data = paramsJSON.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (key, value) in json {
                // Convert param values to String for the plugin's [String: String] params
                // Note: check NSNumber before Bool because Swift bridges all NSNumber to Bool.
                // Use CFBooleanGetTypeID to distinguish actual JSON booleans from numbers.
                if let numVal = value as? NSNumber {
                    if CFGetTypeID(numVal) == CFBooleanGetTypeID() {
                        plugin.params[key] = numVal.boolValue ? "true" : "false"
                    } else {
                        plugin.params[key] = numVal.stringValue
                    }
                } else if let strVal = value as? String {
                    plugin.params[key] = strVal
                } else {
                    // For arrays/objects, keep as JSON string
                    if let subData = try? JSONSerialization.data(withJSONObject: value),
                       let subStr = String(data: subData, encoding: .utf8) {
                        plugin.params[key] = subStr
                    }
                }
            }
        }
    }

    return try runFixtureTest(fixture, plugin: plugin)
}

/// Get the path to the plugin fixtures directory (from this test file)
private func wave0FixturesDirectory() -> String {
    let testFile = #filePath
    let testsDir = (testFile as NSString).deletingLastPathComponent
    let projectTests = (testsDir as NSString).deletingLastPathComponent
    return (projectTests as NSString).appendingPathComponent("Fixtures/SVGO/plugins")
}
