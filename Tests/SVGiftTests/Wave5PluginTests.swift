// Wave5PluginTests.swift
// Fixture-driven tests for all Wave 5 plugins (preset-default completions)
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Wave 5a Plugin Fixture-Driven Tests

@Test("removeEditorsNSData: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeEditorsNSData"))
func removeEditorsNSDataFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeEmptyText: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeEmptyText"))
func removeEmptyTextFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeUselessDefs: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeUselessDefs"))
func removeUselessDefsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeDeprecatedAttrs: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeDeprecatedAttrs"))
func removeDeprecatedAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeUselessStrokeAndFill: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeUselessStrokeAndFill"))
func removeUselessStrokeAndFillFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeEmptyContainers: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeEmptyContainers"))
func removeEmptyContainersFixture(fixture: PluginFixtureCase) throws {
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

@Test("collapseGroups: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "collapseGroups"))
func collapseGroupsFixture(fixture: PluginFixtureCase) throws {
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

// MARK: - Wave 5b Plugin Fixture-Driven Tests

@Test("removeUnknownsAndDefaults: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "removeUnknownsAndDefaults"))
func removeUnknownsAndDefaultsFixture(fixture: PluginFixtureCase) throws {
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

@Test("cleanupIds: fixture-driven test",
      arguments: loadWave5Fixtures(plugin: "cleanupIds"))
func cleanupIdsFixture(fixture: PluginFixtureCase) throws {
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

// MARK: - Wave 5 Aggregate Pass Rate Test

@Test("Wave 5 plugins: aggregate L1/L2 pass rates")
func wave5AggregatePassRates() throws {
    let wave5Plugins = [
        "removeEditorsNSData", "removeEmptyText", "removeUselessDefs",
        "removeDeprecatedAttrs", "removeUselessStrokeAndFill",
        "removeEmptyContainers", "collapseGroups",
        "removeUnknownsAndDefaults", "cleanupIds",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in wave5Plugins {
        let fixtures = loadWave5Fixtures(plugin: pluginName)
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
            .appendingPathComponent("wave5-failures.ndjson")
        try writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 5 fixtures found")

    print("Wave 5 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed Wave 5 fixtures:")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Helpers

func loadWave5Fixtures(plugin pluginName: String) -> [PluginFixtureCase] {
    let testFile = #filePath
    let testsDir = (testFile as NSString).deletingLastPathComponent
    let projectTests = (testsDir as NSString).deletingLastPathComponent
    let dir = (projectTests as NSString).appendingPathComponent("Fixtures/SVGO/plugins")
    return (try? loadFixtures(forPlugin: pluginName, fromDirectory: dir)) ?? []
}
