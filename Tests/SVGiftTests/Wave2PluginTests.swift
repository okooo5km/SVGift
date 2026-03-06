// Wave2PluginTests.swift
// Fixture-driven tests for all Wave 2 plugins
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Wave 2 Plugin Fixture-Driven Tests

@Test("mergeStyles: fixture-driven test",
      arguments: loadWave2Fixtures(plugin: "mergeStyles"))
func mergeStylesFixture(fixture: PluginFixtureCase) throws {
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

@Test("convertStyleToAttrs: fixture-driven test",
      arguments: loadWave2Fixtures(plugin: "convertStyleToAttrs"))
func convertStyleToAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeAttributesBySelector: fixture-driven test",
      arguments: loadWave2Fixtures(plugin: "removeAttributesBySelector"))
func removeAttributesBySelectorFixture(fixture: PluginFixtureCase) throws {
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

@Test("inlineStyles: fixture-driven test",
      arguments: loadWave2Fixtures(plugin: "inlineStyles"))
func inlineStylesFixture(fixture: PluginFixtureCase) throws {
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

@Test("minifyStyles: fixture-driven test",
      arguments: loadWave2Fixtures(plugin: "minifyStyles"))
func minifyStylesFixture(fixture: PluginFixtureCase) throws {
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

// MARK: - Wave 0+1+2 Aggregate Pass Rate Test

@Test("Wave 0+1+2 plugins: aggregate L1/L2 pass rates")
func wave012AggregatePassRates() throws {
    let allPlugins = [
        // Wave 0
        "removeDoctype", "removeXMLProcInst", "removeComments",
        "removeMetadata", "removeTitle", "removeDesc", "removeXMLNS",
        // Wave 1
        "cleanupAttrs", "removeEmptyAttrs", "removeDimensions",
        "removeUnusedNS", "sortAttrs", "sortDefsChildren",
        // Wave 2
        "mergeStyles", "convertStyleToAttrs", "removeAttributesBySelector",
        "inlineStyles", "minifyStyles",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in allPlugins {
        let fixtures = loadWave2Fixtures(plugin: pluginName)
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

    if !allFailures.isEmpty {
        let testFile = #filePath
        let projectRoot = ((testFile as NSString)
            .deletingLastPathComponent as NSString)
            .deletingLastPathComponent as NSString
        let reportsDir = projectRoot.appendingPathComponent("reports")
        let reportPath = (reportsDir as NSString)
            .appendingPathComponent("wave012-failures.ndjson")
        try writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 0+1+2 fixtures found")

    print("Wave 0+1+2 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed fixtures:")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Wave 2 Aggregate Pass Rate Test

@Test("Wave 2 plugins: aggregate L1/L2 pass rates")
func wave2AggregatePassRates() throws {
    let wave2Plugins = [
        "mergeStyles", "convertStyleToAttrs", "removeAttributesBySelector",
        "inlineStyles", "minifyStyles",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in wave2Plugins {
        let fixtures = loadWave2Fixtures(plugin: pluginName)
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

    #expect(totalCount > 0, "No Wave 2 fixtures found")

    print("Wave 2 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed Wave 2 fixtures:")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Idempotency Tests

@Test("Wave 0+1+2 plugins: 2-pass idempotency check")
func wave012Idempotency() throws {
    let allPlugins = [
        "removeDoctype", "removeXMLProcInst", "removeComments",
        "removeMetadata", "removeTitle", "removeDesc", "removeXMLNS",
        "cleanupAttrs", "removeEmptyAttrs", "removeDimensions",
        "removeUnusedNS", "sortAttrs", "sortDefsChildren",
        "mergeStyles", "convertStyleToAttrs", "removeAttributesBySelector",
        "inlineStyles", "minifyStyles",
    ]

    var totalCount = 0
    var idempotentCount = 0
    var failures: [String] = []

    for pluginName in allPlugins {
        let fixtures = loadWave2Fixtures(plugin: pluginName)
        for fixture in fixtures {
            guard let plugin = builtinPluginRegistry[fixture.pluginName] else { continue }
            totalCount += 1

            let pluginConfig = PluginConfig(name: plugin.name, enabled: true)
            var options = OptimizeOptions(
                plugins: [pluginConfig],
                pluginRegistry: [plugin.name: plugin]
            )
            options.js2svg = StringifyOptions(pretty: true, useShortTags: true)

            let result1 = try optimize(fixture.inputSVG, options: options)
            let result2 = try optimize(result1.data, options: options)

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

func loadWave2Fixtures(plugin pluginName: String) -> [PluginFixtureCase] {
    let testFile = #filePath
    let testsDir = (testFile as NSString).deletingLastPathComponent
    let projectTests = (testsDir as NSString).deletingLastPathComponent
    let dir = (projectTests as NSString).appendingPathComponent("Fixtures/SVGO/plugins")
    return (try? loadFixtures(forPlugin: pluginName, fromDirectory: dir)) ?? []
}
