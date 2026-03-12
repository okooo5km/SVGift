// svgo_swift.swift
// Main entry point for svgo-swift SVG optimization library
// okooo5km(十里)

/// Error types for SVG optimization
public enum SVGOError: Error {
    case notImplemented
    case parseError(String)
    case invalidInput(String)
}

/// Optimize an SVG string with the given options.
///
/// - Parameters:
///   - input: The SVG string to optimize
///   - options: Optimization options
/// - Returns: The optimization result containing the optimized SVG string
/// - Throws: SVGOError if optimization fails
public func optimize(_ input: String, options: OptimizeOptions = .init()) throws -> OptimizeResult {
    let maxPassCount = options.multipass ? 10 : 1
    var current = input

    for i in 0..<maxPassCount {
        let info = PluginInfo(path: options.path, multipassCount: i)

        // 1. Parse SVG into AST
        let ast = try parseSvg(current, path: options.path)

        // 2. Resolve and invoke plugins
        var resolved = resolvePlugins(options.plugins, from: options.pluginRegistry)

        // Inject global floatPrecision into plugins that don't specify their own
        if let fp = options.floatPrecision {
            let fpStr = String(fp)
            for i in resolved.indices {
                if resolved[i].params["floatPrecision"] == nil {
                    resolved[i].params["floatPrecision"] = fpStr
                }
            }
        }

        invokePlugins(ast, info: info, plugins: resolved)

        // 3. Stringify AST back to SVG
        let output = stringifySvg(ast, options: options.js2svg)

        // 4. Check if output has converged
        if output == current {
            break
        }
        current = output
    }

    return OptimizeResult(data: current)
}

/// Optimize an SVG string using a built-in optimization level.
///
/// - Parameters:
///   - input: The SVG string to optimize
///   - preset: The optimization level (L0-L6)
/// - Returns: The optimization result containing the optimized SVG string
/// - Throws: SVGOError if optimization fails
public func optimize(_ input: String, preset: OptimizationLevel) throws -> OptimizeResult {
    try optimize(input, options: .preset(preset))
}

// MARK: - Plugin Resolution

/// Resolve plugin configs against a registry of available plugins
public func resolvePlugins(_ configs: [PluginConfig], from registry: [String: ResolvedPlugin]) -> [ResolvedPlugin] {
    var resolved: [ResolvedPlugin] = []
    for config in configs {
        guard config.enabled else { continue }
        if var plugin = registry[config.name] {
            for (key, value) in config.params {
                plugin.params[key] = value
            }
            resolved.append(plugin)
        }
    }
    return resolved
}
