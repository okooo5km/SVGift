import Foundation

@main
struct SVGOSwiftDev {
  static func main() {
    do {
      try run()
    } catch {
      fputs("error: \(error)\n", stderr)
      exit(1)
    }
  }

  private static func run() throws {
    var args = Array(CommandLine.arguments.dropFirst())

    guard let command = args.first else {
      printHelp()
      return
    }
    args.removeFirst()

    switch command {
    case "help", "-h", "--help":
      printHelp()

    case "import-fixtures":
      let source = value(for: ["--source", "-s"], in: args)
        ?? "/Users/5km/Dev/Web/svgo/test"
      let destination = value(for: ["--destination", "-d"], in: args)
        ?? "Tests/Fixtures/SVGO"
      try importFixtures(sourceRoot: source, destinationRoot: destination)

    case "run-regression":
      let svgoRoot = value(for: ["--svgo-root", "-r"], in: args)
        ?? "/Users/5km/Dev/Web/svgo"
      let subset = value(for: ["--subset"], in: args) ?? "all"
      try runRegression(svgoRoot: svgoRoot, subset: subset)

    default:
      fputs("Unknown command: \(command)\n\n", stderr)
      printHelp()
      exit(2)
    }
  }

  private static func printHelp() {
    print(
      """
      svgo-swift-dev

      USAGE:
        swift run svgo-swift-dev <command> [options]

      COMMANDS:
        import-fixtures   Copy fixtures from SVGO source repo into this package
        run-regression    Run SVGO regression pipeline through Swift wrapper

      OPTIONS (import-fixtures):
        --source, -s       Source test root (default: /Users/5km/Dev/Web/svgo/test)
        --destination, -d  Destination root (default: Tests/Fixtures/SVGO)

      OPTIONS (run-regression):
        --svgo-root, -r    SVGO repository root (default: /Users/5km/Dev/Web/svgo)
        --subset           all | extract | optimize | compare (default: all)
      """
    )
  }

  private static func value(for keys: [String], in args: [String]) -> String? {
    for (index, arg) in args.enumerated() where keys.contains(arg) {
      let next = index + 1
      if next < args.count {
        return args[next]
      }
    }
    return nil
  }

  private static func importFixtures(sourceRoot: String, destinationRoot: String) throws {
    let fm = FileManager.default
    let cwd = fm.currentDirectoryPath

    let sourceURL = URL(fileURLWithPath: sourceRoot)
    let destinationURL = URL(fileURLWithPath: destinationRoot, relativeTo: URL(fileURLWithPath: cwd)).standardizedFileURL

    let required = ["plugins", "cli", "svgo", "regression"]

    guard fm.fileExists(atPath: sourceURL.path) else {
      throw DevError.pathNotFound(sourceURL.path)
    }

    try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)

    var copiedCount = 0
    for folder in required {
      let src = sourceURL.appendingPathComponent(folder)
      guard fm.fileExists(atPath: src.path) else {
        throw DevError.pathNotFound(src.path)
      }

      let dst = destinationURL.appendingPathComponent(folder)
      if fm.fileExists(atPath: dst.path) {
        try fm.removeItem(at: dst)
      }
      try fm.copyItem(at: src, to: dst)
      copiedCount += 1
    }

    print("Imported \(copiedCount) fixture folders")
    print("From: \(sourceURL.path)")
    print("To:   \(destinationURL.path)")
  }

  private static func runRegression(svgoRoot: String, subset: String) throws {
    let fm = FileManager.default
    guard fm.fileExists(atPath: svgoRoot) else {
      throw DevError.pathNotFound(svgoRoot)
    }

    let node = "/usr/bin/env"
    let commonPrefix = ["node"]

    func script(_ relativePath: String) -> String {
      URL(fileURLWithPath: svgoRoot)
        .appendingPathComponent(relativePath)
        .path
    }

    switch subset {
    case "extract":
      try runProcess(executable: node, arguments: commonPrefix + [script("test/regression/extract.js")], cwd: svgoRoot)
    case "optimize":
      try runProcess(executable: node, arguments: commonPrefix + [script("test/regression/optimize.js")], cwd: svgoRoot)
    case "compare":
      try runProcess(executable: node, arguments: commonPrefix + [script("test/regression/compare.js")], cwd: svgoRoot)
    case "all":
      try runProcess(executable: node, arguments: commonPrefix + [script("test/regression/extract.js")], cwd: svgoRoot)
      try runProcess(executable: node, arguments: commonPrefix + [script("test/regression/optimize.js")], cwd: svgoRoot)
      try runProcess(executable: node, arguments: commonPrefix + [script("test/regression/compare.js")], cwd: svgoRoot)
    default:
      throw DevError.invalidSubset(subset)
    }
  }

  private static func runProcess(executable: String, arguments: [String], cwd: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: cwd)
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      throw DevError.processFailed(code: Int(process.terminationStatus), command: ([executable] + arguments).joined(separator: " "))
    }
  }
}

enum DevError: Error, CustomStringConvertible {
  case pathNotFound(String)
  case invalidSubset(String)
  case processFailed(code: Int, command: String)

  var description: String {
    switch self {
    case .pathNotFound(let path):
      return "Path not found: \(path)"
    case .invalidSubset(let subset):
      return "Invalid subset: \(subset). Expected: all | extract | optimize | compare"
    case .processFailed(let code, let command):
      return "Process failed (\(code)): \(command)"
    }
  }
}
