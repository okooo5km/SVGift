// OptimizationLevel.swift
// Built-in optimization presets (L0-L6) for SVGift
// okooo5km(十里)

/// Built-in optimization levels from safe (L0) to maximum (L6).
///
/// Each level defines a combination of multipass, floatPrecision, output
/// formatting, and plugin selection that balances fidelity vs compression.
///
/// Usage:
/// ```swift
/// // Use a named preset
/// let result = try optimize(svg, preset: .recommended)
///
/// // Use a numeric level
/// let result = try optimize(svg, preset: .level(4))
///
/// // Get options to customize further
/// var options = OptimizeOptions.preset(.aggressive)
/// options.js2svg.pretty = true
/// let result = try optimize(svg, options: options)
/// ```
public enum OptimizationLevel: Int, CaseIterable, Sendable {
    /// L0: Safe / debug-friendly. Pretty-printed output, high precision,
    /// single pass. IDs preserved without minification.
    case safe = 0

    /// L1: Conservative production. Multipass enabled, slightly reduced
    /// precision, compact output. IDs preserved without minification.
    case conservative = 1

    /// L2: Recommended default. Balanced compression with ID collision
    /// prevention (prefixIds). Removes dimensions, enables removeDesc.
    case recommended = 2

    /// L3: Compact / size-oriented. Lower precision, ID minification
    /// enabled. No prefixIds (saves bytes when collision is not a concern).
    case compact = 3

    /// L4: Aggressive. Strips style elements, scripts, and raster images.
    /// Suitable for icon systems and controlled environments.
    case aggressive = 4

    /// L5: Extreme. Removes viewBox in addition to L4 removals.
    /// Only for fixed-size rendering contexts.
    case extreme = 5

    /// L6: Maximum compression. Removes title, viewBox, and all
    /// non-essential content. Requires strict visual verification.
    case maximum = 6

    /// Create from a numeric level (0-6). Returns nil if out of range.
    public static func level(_ n: Int) -> OptimizationLevel? {
        OptimizationLevel(rawValue: n)
    }

    /// Human-readable description of this level.
    public var description: String {
        switch self {
        case .safe:         return "L0: safe (debug-friendly, pretty output)"
        case .conservative: return "L1: conservative (production, single-line)"
        case .recommended:  return "L2: recommended (balanced, prefixIds)"
        case .compact:      return "L3: compact (size-oriented)"
        case .aggressive:   return "L4: aggressive (strips styles/scripts/rasters)"
        case .extreme:      return "L5: extreme (removes viewBox)"
        case .maximum:      return "L6: maximum (removes title, needs verification)"
        }
    }
}

// MARK: - OptimizeOptions preset factory

extension OptimizeOptions {
    /// Create options from a built-in optimization level.
    ///
    /// The returned options include the appropriate plugin registry.
    /// You can further customize individual fields after creation.
    public static func preset(_ level: OptimizationLevel) -> OptimizeOptions {
        // Base plugins shared by all levels (30 plugins from preset-default,
        // minus removeDesc which is level-dependent)
        let basePluginNames: [String] = [
            "removeDoctype",
            "removeXMLProcInst",
            "removeComments",
            "removeDeprecatedAttrs",
            "removeMetadata",
            "removeEditorsNSData",
            "cleanupAttrs",
            "mergeStyles",
            "inlineStyles",
            "minifyStyles",
            "cleanupIds",
            "removeUselessDefs",
            "cleanupNumericValues",
            "convertColors",
            "removeUnknownsAndDefaults",
            "removeNonInheritableGroupAttrs",
            "removeUselessStrokeAndFill",
            "cleanupEnableBackground",
            "removeHiddenElems",
            "removeEmptyText",
            "convertShapeToPath",
            "convertEllipseToCircle",
            "moveElemsAttrsToGroup",
            "moveGroupAttrsToElems",
            "collapseGroups",
            "convertPathData",
            "convertTransform",
            "removeEmptyAttrs",
            "removeEmptyContainers",
            "mergePaths",
            "removeUnusedNS",
            "sortAttrs",
            "sortDefsChildren",
        ]

        var plugins = basePluginNames.map { PluginConfig(name: $0) }

        // Per-level adjustments
        let multipass: Bool
        let floatPrecision: Int
        let pretty: Bool

        switch level {
        case .safe:
            multipass = false
            floatPrecision = 6
            pretty = true
            // cleanupIds: don't minify
            if let idx = plugins.firstIndex(where: { $0.name == "cleanupIds" }) {
                plugins[idx].params["minify"] = "false"
            }
            // removeDesc disabled
            plugins.append(PluginConfig(name: "removeDesc", enabled: false))

        case .conservative:
            multipass = true
            floatPrecision = 4
            pretty = false
            // cleanupIds: don't minify
            if let idx = plugins.firstIndex(where: { $0.name == "cleanupIds" }) {
                plugins[idx].params["minify"] = "false"
            }
            // removeDesc disabled
            plugins.append(PluginConfig(name: "removeDesc", enabled: false))

        case .recommended:
            multipass = true
            floatPrecision = 3
            pretty = false
            // cleanupIds: don't minify
            if let idx = plugins.firstIndex(where: { $0.name == "cleanupIds" }) {
                plugins[idx].params["minify"] = "false"
            }
            // removeDesc enabled
            plugins.append(PluginConfig(name: "removeDesc"))
            // removeDimensions
            plugins.append(PluginConfig(name: "removeDimensions"))
            // prefixIds with short prefix
            plugins.append(PluginConfig(
                name: "prefixIds",
                params: ["prefix": "o", "delim": ""]
            ))

        case .compact:
            multipass = true
            floatPrecision = 2
            pretty = false
            // cleanupIds: minify enabled (default)
            // removeDesc enabled
            plugins.append(PluginConfig(name: "removeDesc"))
            // removeDimensions
            plugins.append(PluginConfig(name: "removeDimensions"))

        case .aggressive:
            multipass = true
            floatPrecision = 2
            pretty = false
            // cleanupIds: minify enabled (default)
            // removeDesc enabled
            plugins.append(PluginConfig(name: "removeDesc"))
            // removeDimensions
            plugins.append(PluginConfig(name: "removeDimensions"))
            // Aggressive removals
            plugins.append(PluginConfig(name: "removeStyleElement"))
            plugins.append(PluginConfig(name: "removeScripts"))
            plugins.append(PluginConfig(name: "removeRasterImages"))

        case .extreme:
            multipass = true
            floatPrecision = 1
            pretty = false
            // cleanupIds: minify enabled (default)
            // removeDesc enabled
            plugins.append(PluginConfig(name: "removeDesc"))
            // removeDimensions
            plugins.append(PluginConfig(name: "removeDimensions"))
            // Aggressive removals
            plugins.append(PluginConfig(name: "removeStyleElement"))
            plugins.append(PluginConfig(name: "removeScripts"))
            plugins.append(PluginConfig(name: "removeRasterImages"))
            // Extreme: remove viewBox
            plugins.append(PluginConfig(name: "removeViewBox"))

        case .maximum:
            multipass = true
            floatPrecision = 0
            pretty = false
            // cleanupIds: minify enabled (default)
            // removeDesc enabled
            plugins.append(PluginConfig(name: "removeDesc"))
            // removeDimensions
            plugins.append(PluginConfig(name: "removeDimensions"))
            // Aggressive removals
            plugins.append(PluginConfig(name: "removeStyleElement"))
            plugins.append(PluginConfig(name: "removeScripts"))
            plugins.append(PluginConfig(name: "removeRasterImages"))
            // Extreme: remove viewBox + title
            plugins.append(PluginConfig(name: "removeViewBox"))
            plugins.append(PluginConfig(name: "removeTitle"))
        }

        return OptimizeOptions(
            multipass: multipass,
            js2svg: StringifyOptions(indent: 2, pretty: pretty),
            plugins: plugins,
            floatPrecision: floatPrecision,
            pluginRegistry: builtinPluginRegistry
        )
    }
}
