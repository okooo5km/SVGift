// Wave4PluginTests.swift
// Fixture-driven tests for all Wave 4 plugins
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Wave 4 Plugin Fixture-Driven Tests

@Test("reusePaths: fixture-driven test",
      arguments: loadWave4Fixtures(plugin: "reusePaths"))
func reusePathsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeHiddenElems: fixture-driven test",
      arguments: loadWave4Fixtures(plugin: "removeHiddenElems"))
func removeHiddenElemsFixture(fixture: PluginFixtureCase) throws {
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

@Test("convertTransform: fixture-driven test",
      arguments: loadWave4Fixtures(plugin: "convertTransform"))
func convertTransformFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeOffCanvasPaths: fixture-driven test",
      arguments: loadWave4Fixtures(plugin: "removeOffCanvasPaths"))
func removeOffCanvasPathsFixture(fixture: PluginFixtureCase) throws {
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

@Test("mergePaths: fixture-driven test",
      arguments: loadWave4Fixtures(plugin: "mergePaths"))
func mergePathsFixture(fixture: PluginFixtureCase) throws {
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

@Test("convertPathData: fixture-driven test",
      arguments: loadWave4Fixtures(plugin: "convertPathData"))
func convertPathDataFixture(fixture: PluginFixtureCase) throws {
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

// MARK: - Wave 4 Aggregate Pass Rate Test

@Test("Wave 4 plugins: aggregate L1/L2 pass rates")
func wave4AggregatePassRates() throws {
    let wave4Plugins = [
        "reusePaths", "removeHiddenElems", "convertTransform",
        "removeOffCanvasPaths", "mergePaths", "convertPathData",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in wave4Plugins {
        let fixtures = loadWave4Fixtures(plugin: pluginName)
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
            .appendingPathComponent("wave4-failures.ndjson")
        try writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 4 fixtures found")

    print("Wave 4 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed Wave 4 fixtures:")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Wave 0+1+2+3+4 Aggregate Pass Rate Test

@Test("Wave 0+1+2+3+4 plugins: aggregate L1/L2 pass rates")
func wave01234AggregatePassRates() throws {
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
        // Wave 3
        "convertEllipseToCircle", "convertColors", "convertShapeToPath",
        "cleanupNumericValues", "cleanupListOfValues",
        // Wave 4
        "reusePaths", "removeHiddenElems", "convertTransform",
        "removeOffCanvasPaths", "mergePaths", "convertPathData",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in allPlugins {
        let fixtures = loadWave4Fixtures(plugin: pluginName)
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
            .appendingPathComponent("wave01234-failures.ndjson")
        try writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 0+1+2+3+4 fixtures found")

    print("Wave 0+1+2+3+4 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed fixtures:")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Idempotency Tests

@Test("Wave 0+1+2+3+4 plugins: 2-pass idempotency check")
func wave01234Idempotency() throws {
    let allPlugins = [
        "removeDoctype", "removeXMLProcInst", "removeComments",
        "removeMetadata", "removeTitle", "removeDesc", "removeXMLNS",
        "cleanupAttrs", "removeEmptyAttrs", "removeDimensions",
        "removeUnusedNS", "sortAttrs", "sortDefsChildren",
        "mergeStyles", "convertStyleToAttrs", "removeAttributesBySelector",
        "inlineStyles", "minifyStyles",
        "convertEllipseToCircle", "convertColors", "convertShapeToPath",
        "cleanupNumericValues", "cleanupListOfValues",
        "reusePaths", "removeHiddenElems", "convertTransform",
        "removeOffCanvasPaths", "mergePaths", "convertPathData",
    ]

    var totalCount = 0
    var idempotentCount = 0
    var failures: [String] = []

    for pluginName in allPlugins {
        let fixtures = loadWave4Fixtures(plugin: pluginName)
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

    #expect(rate >= 95.0,
            "Idempotency rate \(String(format: "%.1f", rate))% is below 95% target. Failures: \(failures.joined(separator: "; "))")

    print("Idempotency: \(idempotentCount)/\(totalCount) (\(String(format: "%.1f", rate))%)")
}

// MARK: - Helpers

func loadWave4Fixtures(plugin pluginName: String) -> [PluginFixtureCase] {
    let testFile = #filePath
    let testsDir = (testFile as NSString).deletingLastPathComponent
    let projectTests = (testsDir as NSString).deletingLastPathComponent
    let dir = (projectTests as NSString).appendingPathComponent("Fixtures/SVGO/plugins")
    return (try? loadFixtures(forPlugin: pluginName, fromDirectory: dir)) ?? []
}
