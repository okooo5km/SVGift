// Wave6PluginTests.swift
// Fixture-driven tests for all Wave 6 plugins (non-preset-default)
// okooo5km(十里)

@testable import SVGift
import Foundation
import Testing

// MARK: - Wave 6 Plugin Fixture-Driven Tests

@Test("removeAttrs: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeAttrs"))
func removeAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeElementsByAttr: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeElementsByAttr"))
func removeElementsByAttrFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeScripts: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeScripts"))
func removeScriptsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeStyleElement: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeStyleElement"))
func removeStyleElementFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeRasterImages: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeRasterImages"))
func removeRasterImagesFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeViewBox: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeViewBox"))
func removeViewBoxFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeXlink: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeXlink"))
func removeXlinkFixture(fixture: PluginFixtureCase) throws {
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

@Test("addAttributesToSVGElement: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "addAttributesToSVGElement"))
func addAttributesToSVGElementFixture(fixture: PluginFixtureCase) throws {
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

@Test("addClassesToSVGElement: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "addClassesToSVGElement"))
func addClassesToSVGElementFixture(fixture: PluginFixtureCase) throws {
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

@Test("convertOneStopGradients: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "convertOneStopGradients"))
func convertOneStopGradientsFixture(fixture: PluginFixtureCase) throws {
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

@Test("removeNonInheritableGroupAttrs: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "removeNonInheritableGroupAttrs"))
func removeNonInheritableGroupAttrsFixture(fixture: PluginFixtureCase) throws {
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

@Test("cleanupEnableBackground: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "cleanupEnableBackground"))
func cleanupEnableBackgroundFixture(fixture: PluginFixtureCase) throws {
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

@Test("moveGroupAttrsToElems: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "moveGroupAttrsToElems"))
func moveGroupAttrsToElemsFixture(fixture: PluginFixtureCase) throws {
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

@Test("moveElemsAttrsToGroup: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "moveElemsAttrsToGroup"))
func moveElemsAttrsToGroupFixture(fixture: PluginFixtureCase) throws {
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

@Test("prefixIds: fixture-driven test",
      arguments: loadWave6Fixtures(plugin: "prefixIds"))
func prefixIdsFixture(fixture: PluginFixtureCase) throws {
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

// MARK: - Wave 6 Aggregate Pass Rate Test

@Test("Wave 6 plugins: aggregate L1/L2 pass rates")
func wave6AggregatePassRates() throws {
    let wave6Plugins = [
        "removeAttrs", "removeElementsByAttr", "removeScripts",
        "removeStyleElement", "removeRasterImages", "removeViewBox",
        "removeXlink", "addAttributesToSVGElement", "addClassesToSVGElement",
        "convertOneStopGradients", "removeNonInheritableGroupAttrs",
        "cleanupEnableBackground", "moveGroupAttrsToElems",
        "moveElemsAttrsToGroup", "prefixIds",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in wave6Plugins {
        let fixtures = loadWave6Fixtures(plugin: pluginName)
        for fixture in fixtures {
            do {
                let result = try runWave0FixtureTest(fixture)
                totalCount += 1
                if result.l1Pass { totalL1 += 1 }
                if result.l2Pass { totalL2 += 1 }
                if !result.l2Pass {
                    allFailures.append((fixture, result))
                }
            } catch {
                totalCount += 1
                let errorResult = FixtureTestResult(
                    l1Pass: false, l2Pass: false,
                    actualOutput: "ERROR: \(error)",
                    expectedOutput: fixture.expectedSVG
                )
                allFailures.append((fixture, errorResult))
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
            .appendingPathComponent("wave6-failures.ndjson")
        try? writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No Wave 6 fixtures found")

    print("Wave 6 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed Wave 6 fixtures:")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Full Aggregate Pass Rate Test (Wave 0-6)

@Test("Wave 0-6 plugins: aggregate L1/L2 pass rates")
func wave0to6AggregatePassRates() throws {
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
        // Wave 5
        "removeEditorsNSData", "removeEmptyText", "removeUselessDefs",
        "removeDeprecatedAttrs", "removeUselessStrokeAndFill",
        "removeEmptyContainers", "collapseGroups",
        "removeUnknownsAndDefaults", "cleanupIds",
        // Wave 6
        "removeAttrs", "removeElementsByAttr", "removeScripts",
        "removeStyleElement", "removeRasterImages", "removeViewBox",
        "removeXlink", "addAttributesToSVGElement", "addClassesToSVGElement",
        "convertOneStopGradients", "removeNonInheritableGroupAttrs",
        "cleanupEnableBackground", "moveGroupAttrsToElems",
        "moveElemsAttrsToGroup", "prefixIds",
    ]

    var totalL1 = 0
    var totalL2 = 0
    var totalCount = 0
    var allFailures: [(PluginFixtureCase, FixtureTestResult)] = []

    for pluginName in allPlugins {
        let fixtures = loadWave6Fixtures(plugin: pluginName)
        for fixture in fixtures {
            do {
                let result = try runWave0FixtureTest(fixture)
                totalCount += 1
                if result.l1Pass { totalL1 += 1 }
                if result.l2Pass { totalL2 += 1 }
                if !result.l2Pass {
                    allFailures.append((fixture, result))
                }
            } catch {
                totalCount += 1
                let errorResult = FixtureTestResult(
                    l1Pass: false, l2Pass: false,
                    actualOutput: "ERROR: \(error)",
                    expectedOutput: fixture.expectedSVG
                )
                allFailures.append((fixture, errorResult))
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
            .appendingPathComponent("wave0to6-failures.ndjson")
        try? writeFailureReport(allFailures, to: reportPath)
    }

    #expect(totalCount > 0, "No fixtures found")

    print("Wave 0-6 Summary: \(totalCount) fixtures, L1=\(String(format: "%.1f", l1Rate))%, L2=\(String(format: "%.1f", l2Rate))%")
    if !allFailures.isEmpty {
        print("Failed fixtures (\(allFailures.count)):")
        for (fixture, _) in allFailures {
            print("  - \(fixture.label)")
        }
    }
}

// MARK: - Helpers

func loadWave6Fixtures(plugin pluginName: String) -> [PluginFixtureCase] {
    let testFile = #filePath
    let testsDir = (testFile as NSString).deletingLastPathComponent
    let projectTests = (testsDir as NSString).deletingLastPathComponent
    let dir = (projectTests as NSString).appendingPathComponent("Fixtures/SVGO/plugins")
    return (try? loadFixtures(forPlugin: pluginName, fromDirectory: dir)) ?? []
}
