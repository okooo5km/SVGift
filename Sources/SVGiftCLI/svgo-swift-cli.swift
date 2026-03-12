// SVGiftCLI.swift
// CLI tool for SVGift SVG optimization
// okooo5km(十里)

import ArgumentParser
import Foundation
import SVGift

// MARK: - ANSI Color Helpers

private let useColor = isatty(fileno(stderr)) != 0

private func green(_ s: String) -> String { useColor ? "\u{1B}[32m\(s)\u{1B}[39m" : s }
private func red(_ s: String) -> String { useColor ? "\u{1B}[31m\(s)\u{1B}[39m" : s }

@main
struct SVGiftCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "svgift",
        abstract: "SVG Optimizer - a Swift native implementation of SVGO",
        version: svgoSwiftVersion
    )

    @Argument(help: "Input SVG file or directory path. Use '-' for stdin.")
    var input: String?

    @Option(name: .shortAndLong, help: "Output file or directory path. Defaults to stdout for single file.")
    var output: String?

    @Flag(name: .shortAndLong, help: "Recursively process directories.")
    var recursive: Bool = false

    @Flag(name: .long, help: "Enable multipass optimization.")
    var multipass: Bool = false

    @Flag(name: .long, help: "Pretty-print the output SVG.")
    var pretty: Bool = false

    @Option(name: .long, help: "Indentation width (default: 4). Use -1 for tabs.")
    var indent: Int?

    @Option(name: .long, help: "Global float precision for numeric values (default: plugin default).")
    var floatPrecision: Int?

    @Option(name: .long, help: "Optimization preset level (0-6 or name: safe, conservative, recommended, compact, aggressive, extreme, maximum).")
    var preset: String?

    @Option(name: .long, help: "Path to JSON config file.")
    var config: String?

    @Flag(name: .long, help: "Show list of available plugins.")
    var showPlugins: Bool = false

    @Flag(name: .long, help: "Show list of available presets.")
    var showPresets: Bool = false

    @Flag(name: .shortAndLong, help: "Quiet mode. Suppress progress output.")
    var quiet: Bool = false

    mutating func run() throws {
        if showPresets {
            printAvailablePresets()
            return
        }
        if showPlugins {
            printAvailablePlugins()
            return
        }

        // Build base options
        let baseOptions = try buildOptions()

        // Determine input mode
        if let inputPath = input, inputPath != "-" {
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: inputPath, isDirectory: &isDir) else {
                throw CLIError.fileNotFound(inputPath)
            }

            if isDir.boolValue {
                // Directory mode
                guard recursive else {
                    throw CLIError.directoryRequiresRecursive(inputPath)
                }
                try processDirectory(inputPath, baseOptions: baseOptions)
            } else {
                // Single file mode
                try processSingleFile(inputPath, baseOptions: baseOptions)
            }
        } else {
            // stdin mode
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard !data.isEmpty, let svgInput = String(data: data, encoding: .utf8), !svgInput.isEmpty else {
                throw CLIError.emptyInput
            }
            var options = baseOptions
            options.path = nil
            let result = try optimize(svgInput, options: options)
            if let outputPath = output {
                try result.data.write(toFile: outputPath, atomically: true, encoding: .utf8)
            } else {
                print(result.data, terminator: "")
            }
        }
    }

    // MARK: - Private

    private func buildOptions() throws -> OptimizeOptions {
        var options: OptimizeOptions
        if let configPath = config {
            options = try loadConfig(at: configPath)
        } else if let presetStr = preset {
            guard let level = parsePresetLevel(presetStr) else {
                throw CLIError.invalidPreset(presetStr)
            }
            options = .preset(level)
        } else {
            options = OptimizeOptions(
                plugins: presetDefaultPlugins,
                pluginRegistry: builtinPluginRegistry
            )
        }

        // CLI flags override config only when explicitly provided.
        // --multipass and --pretty are Bool flags: they are only "true" when
        // the user explicitly passes them on the command line, so we can
        // safely use them as overrides (false is ArgumentParser's default
        // and means "not provided").
        if multipass {
            options.multipass = true
        }
        if pretty {
            options.js2svg.pretty = true
        }
        if let indent {
            options.js2svg.indent = indent
        }
        if let floatPrecision {
            options.floatPrecision = floatPrecision
        }

        if options.pluginRegistry.isEmpty {
            options.pluginRegistry = builtinPluginRegistry
        }
        return options
    }

    private func processSingleFile(_ inputPath: String, baseOptions: OptimizeOptions) throws {
        let svgInput = try String(contentsOfFile: inputPath, encoding: .utf8)
        var options = baseOptions
        options.path = inputPath

        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try optimize(svgInput, options: options)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let outputPath = output ?? inputPath

        if output == nil {
            // No output specified: write to stdout
            print(result.data, terminator: "")
        } else {
            try result.data.write(toFile: outputPath, atomically: true, encoding: .utf8)
            if !quiet {
                printFileResult(
                    filename: (inputPath as NSString).lastPathComponent,
                    originalBytes: svgInput.utf8.count,
                    optimizedBytes: result.data.utf8.count,
                    timeMs: Int(elapsed * 1000),
                    isFirst: true
                )
            }
        }
    }

    private func processDirectory(_ dirPath: String, baseOptions: OptimizeOptions) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: dirPath) else {
            throw CLIError.cannotReadDirectory(dirPath)
        }

        var svgFiles: [String] = []
        while let relativePath = enumerator.nextObject() as? String {
            if relativePath.hasSuffix(".svg") {
                svgFiles.append(relativePath)
            }
        }

        guard !svgFiles.isEmpty else {
            if !quiet {
                FileHandle.standardError.write("No .svg files found in \(dirPath)\n".data(using: .utf8)!)
            }
            return
        }

        var successCount = 0
        var errorCount = 0
        var errors: [(String, String)] = []
        var isFirst = true

        for relativePath in svgFiles.sorted() {
            let inputFile = (dirPath as NSString).appendingPathComponent(relativePath)
            let outputFile: String
            if let outputDir = output {
                outputFile = (outputDir as NSString).appendingPathComponent(relativePath)
                // Ensure output subdirectory exists
                let outputSubDir = (outputFile as NSString).deletingLastPathComponent
                try fm.createDirectory(atPath: outputSubDir, withIntermediateDirectories: true)
            } else {
                outputFile = inputFile // In-place
            }

            do {
                let svgInput = try String(contentsOfFile: inputFile, encoding: .utf8)
                var options = baseOptions
                options.path = inputFile
                let startTime = CFAbsoluteTimeGetCurrent()
                let result = try optimize(svgInput, options: options)
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                try result.data.write(toFile: outputFile, atomically: true, encoding: .utf8)
                successCount += 1
                if !quiet {
                    printFileResult(
                        filename: relativePath,
                        originalBytes: svgInput.utf8.count,
                        optimizedBytes: result.data.utf8.count,
                        timeMs: Int(elapsed * 1000),
                        isFirst: isFirst
                    )
                    isFirst = false
                }
            } catch {
                errorCount += 1
                errors.append((relativePath, error.localizedDescription))
                if !quiet {
                    FileHandle.standardError.write("  ✗ \(relativePath): \(error.localizedDescription)\n".data(using: .utf8)!)
                }
            }
        }

        if !quiet {
            FileHandle.standardError.write("\nDone: \(successCount) optimized, \(errorCount) failed, \(svgFiles.count) total\n".data(using: .utf8)!)
        }

        if errorCount > 0 {
            throw ExitCode(1)
        }
    }

    private func printFileResult(
        filename: String,
        originalBytes: Int,
        optimizedBytes: Int,
        timeMs: Int,
        isFirst: Bool
    ) {
        let stderr = FileHandle.standardError
        let beforeKiB = Double(originalBytes) / 1024.0
        let afterKiB = Double(optimizedBytes) / 1024.0

        let diff = originalBytes > 0
            ? Double(originalBytes - optimizedBytes) / Double(originalBytes) * 100.0
            : 0.0
        let pctStr = String(format: "%.1f", abs(diff))
        let op: String
        let coloredPct: String
        if diff >= 0 {
            op = "-"
            coloredPct = green("\(op) \(pctStr)%")
        } else {
            op = "+"
            coloredPct = red("\(op) \(pctStr)%")
        }

        let beforeStr = String(format: "%.3f", beforeKiB)
        let afterStr = String(format: "%.3f", afterKiB)

        if !isFirst {
            stderr.write("\n".data(using: .utf8)!)
        }
        stderr.write("\(filename):\nDone in \(timeMs) ms!\n\(beforeStr) KiB \(coloredPct) = \(afterStr) KiB\n".data(using: .utf8)!)
    }

    private func printAvailablePlugins() {
        print("Available plugins:\n")
        let defaultNames = Set(presetDefaultPlugins.map(\.name))
        for name in builtinPluginRegistry.keys.sorted() {
            let marker = defaultNames.contains(name) ? " (default)" : ""
            print("  - \(name)\(marker)")
        }
    }

    private func printAvailablePresets() {
        print("Available optimization presets:\n")
        for level in OptimizationLevel.allCases {
            print("  \(level.rawValue)  \(level.description)")
        }
        print("\nUsage: svgift input.svg --preset <level>")
        print("  level can be a number (0-6) or a name (safe, conservative, ...)")
    }

    private func parsePresetLevel(_ value: String) -> OptimizationLevel? {
        // Try numeric first
        if let n = Int(value) {
            return .level(n)
        }
        // Try name matching (case-insensitive)
        switch value.lowercased() {
        case "safe":         return .safe
        case "conservative": return .conservative
        case "recommended":  return .recommended
        case "compact":      return .compact
        case "aggressive":   return .aggressive
        case "extreme":      return .extreme
        case "maximum":      return .maximum
        default:             return nil
        }
    }
}

enum CLIError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case emptyInput
    case directoryRequiresRecursive(String)
    case cannotReadDirectory(String)
    case invalidPreset(String)

    var description: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .emptyInput:
            return "No input provided. Pass a file path or pipe SVG via stdin."
        case .directoryRequiresRecursive(let path):
            return "'\(path)' is a directory. Use --recursive (-r) to process directories."
        case .cannotReadDirectory(let path):
            return "Cannot read directory: \(path)"
        case .invalidPreset(let value):
            return "Invalid preset '\(value)'. Use 0-6 or: safe, conservative, recommended, compact, aggressive, extreme, maximum."
        }
    }
}
