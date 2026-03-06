// Wave1PluginTests.swift
// Fixture-driven tests for all Wave 1 plugins
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Wave 1 Plugin Fixture-Driven Tests

@Test("cleanupAttrs: fixture-driven test",
      arguments: loadWave1Fixtures(plugin: "cleanupAttrs"))
func cleanupAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeEmptyAttrs: fixture-driven test",
      arguments: loadWave1Fixtures(plugin: "removeEmptyAttrs"))
func removeEmptyAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeDimensions: fixture-driven test",
      arguments: loadWave1Fixtures(plugin: "removeDimensions"))
func removeDimensionsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeUnusedNS: fixture-driven test",
      arguments: loadWave1Fixtures(plugin: "removeUnusedNS"))
func removeUnusedNSFixture(fixture: PluginFixtureCase) throws {
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

@Test("sortAttrs: fixture-driven test",
      arguments: loadWave1Fixtures(plugin: "sortAttrs"))
func sortAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("sortDefsChildren: fixture-driven test",
      arguments: loadWave1Fixtures(plugin: "sortDefsChildren"))
func sortDefsChildrenFixture(fixture: PluginFixtureCase) throws {
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

// MARK: - Wave 0+1 Aggregate Pass Rate Test

@Test("Wave 0+1 plugins: aggregate L1/L2 pass rates")
func wave01AggregatePassRates() throws {
    let allPlugins = [
        // Wave 0
        "removeDoctype",
        "removeXMLProcInst",
        "removeComments",
        "removeMetadata",
        "removeTitle",
        "removeDesc",
        "removeXMLNS",
        // Wave 1
        "cleanupAttrs",
        "removeEmptyAttrs",
        "removeDimensions",
        "removeUnusedNS",
        "sortAttrs",
        "sortDefsChildren",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in allPlugins {
        let fixtures = loadWave1Fixtures(plugin: pluginName)
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
            .appendingPathComponent("wave01-failures.ndjson")
        try writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 0+1 fixtures found")
    #expect(l2Rate >= 95.0,
            "Wave 0+1 L2 pass rate \(String(format: "%.1f", l2Rate))% is below 95% target (\(totalL2)/\(totalCount))")

    print("Wave 0+1 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
}

// MARK: - Idempotency Tests

@Test("Wave 0+1 plugins: 2-pass idempotency check")
func wave01Idempotency() throws {
    let allPlugins = [
        "removeDoctype", "removeXMLProcInst", "removeComments",
        "removeMetadata", "removeTitle", "removeDesc", "removeXMLNS",
        "cleanupAttrs", "removeEmptyAttrs", "removeDimensions",
        "removeUnusedNS", "sortAttrs", "sortDefsChildren",
    ]

    var totalCount = 0
    var idempotentCount = 0
    var failures: [String] = []

    for pluginName in allPlugins {
        let fixtures = loadWave1Fixtures(plugin: pluginName)
        for fixture in fixtures {
            guard let plugin = builtinPluginRegistry[fixture.pluginName] else { continue }
            totalCount += 1

            let pluginConfig = PluginConfig(name: plugin.name, enabled: true)
            var options = OptimizeOptions(
                plugins: [pluginConfig],
                pluginRegistry: [plugin.name: plugin]
            )
            options.js2svg = StringifyOptions(pretty: true, useShortTags: true)

            // Pass 1
            let result1 = try optimize(fixture.inputSVG, options: options)
            // Pass 2
            let result2 = try optimize(result1.data, options: options)

            // Use L2 normalization for idempotency check since XMLParser
            // doesn't preserve attribute order, causing harmless reordering
            // between passes.
            let norm1 = normalizeForL2(result1.data)
            let norm2 = normalizeForL2(result2.data)
            if norm1 == norm2 {
                idempotentCount += 1
            } else {
                failures.append("\(fixture.label): output changed on 2nd pass")
            }
        }
    }

    let rate = totalCount > 0 ? Double(idempotentCount) / Double(totalCount) * 100 : 0

    #expect(rate >= 98.0,
            "Idempotency rate \(String(format: "%.1f", rate))% is below 98% target. Failures: \(failures.joined(separator: "; "))")

    print("Idempotency: \(idempotentCount)/\(totalCount) (\(String(format: "%.1f", rate))%)")
}

// MARK: - Helpers

func loadWave1Fixtures(plugin pluginName: String) -> [PluginFixtureCase] {
    let testFile = #filePath
    let testsDir = (testFile as NSString).deletingLastPathComponent
    let projectTests = (testsDir as NSString).deletingLastPathComponent
    let dir = (projectTests as NSString).appendingPathComponent("Fixtures/SVGO/plugins")
    return (try? loadFixtures(forPlugin: pluginName, fromDirectory: dir)) ?? []
}
