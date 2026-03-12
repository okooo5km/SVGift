# SVGift

[![Swift CI](https://github.com/okooo5km/SVGift/actions/workflows/ci.yml/badge.svg)](https://github.com/okooo5km/SVGift/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Swift native implementation of [SVGO](https://github.com/svg/svgo)** — the popular Node.js SVG optimizer.

SVGift provides the same optimization capabilities as SVGO, with 49 built-in plugins (34 enabled by default). It is available as both a **CLI tool** and a **Swift library**.

## Installation

### Homebrew

```bash
brew install okooo5km/tap/svgift
```

Or manually:

```bash
brew tap okooo5km/tap
brew install svgift
```

### Build from source

```bash
git clone https://github.com/okooo5km/SVGift.git
cd svgo-swift
swift build -c release
# Binary at .build/release/svgift
```

### SwiftPM (as a library dependency)

```swift
.package(url: "https://github.com/okooo5km/SVGift.git", from: "0.3.0")
```

Then add `"SVGift"` to your target's dependencies.

## Usage

### CLI

```bash
# Optimize a single file (output to stdout)
svgift input.svg

# Optimize and write to a file
svgift input.svg -o output.svg

# Read from stdin
cat input.svg | svgift -

# Recursively optimize a directory (in-place)
svgift -r icons/

# Recursively optimize to a different directory
svgift -r icons/ -o optimized/

# Use a built-in preset (0-6 or name)
svgift input.svg --preset recommended
svgift input.svg --preset 4

# Enable multipass optimization
svgift input.svg --multipass -o output.svg

# Pretty-print output
svgift input.svg --pretty

# Custom indentation (default: 4, use -1 for tabs)
svgift input.svg --pretty --indent 2

# Set global float precision for numeric values
svgift input.svg --float-precision 2

# Use a config file
svgift input.svg --config svgo.config.json -o output.svg

# List available plugins / presets
svgift --show-plugins
svgift --show-presets
```

CLI flags (`--multipass`, `--pretty`, `--indent`, `--float-precision`) override the corresponding values in the preset or config file when provided.

### Library API

```swift
import SVGift

// Basic usage with default plugins
let input = "<svg>...</svg>"
let result = try optimize(input)
print(result.data)

// Use a built-in preset
let result = try optimize(input, preset: .recommended)  // L2
let result = try optimize(input, preset: .aggressive)    // L4

// Preset with customization
var options = OptimizeOptions.preset(.compact)
options.js2svg.pretty = true  // override a single field
let result = try optimize(input, options: options)

// Fully custom options
var options = OptimizeOptions(
    plugins: presetDefaultPlugins,
    pluginRegistry: builtinPluginRegistry
)
options.multipass = true
options.js2svg.pretty = true
let result = try optimize(input, options: options)
```

## Configuration

Create a JSON config file to customize optimization behavior:

```json
{
  "multipass": true,
  "floatPrecision": 3,
  "js2svg": {
    "pretty": true,
    "indent": 2
  },
  "plugins": [
    "removeDoctype",
    "removeComments",
    {
      "name": "removeAttrs",
      "params": {
        "attrs": ["fill", "stroke"]
      }
    }
  ]
}
```

### Top-level options

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `multipass` | `bool` | `false` | Run multiple optimization passes (up to 10) until output converges |
| `floatPrecision` | `int` | plugin default (3) | Global float precision injected into all plugins that support it |
| `js2svg.pretty` | `bool` | `false` | Pretty-print output with indentation |
| `js2svg.indent` | `int` | `4` | Indentation width (use `-1` for tabs) |
| `js2svg.useShortTags` | `bool` | `true` | Use self-closing tags (e.g. `<path/>`) |
| `js2svg.finalNewline` | `bool` | `false` | Add a final newline at end of file |

### Plugin formats

Plugins can be specified as strings, objects, or a mix of both:

```json
{
  "plugins": [
    "removeDoctype",
    { "name": "removeComments" },
    { "name": "cleanupIds", "params": { "minify": false } },
    { "name": "removeDesc", "enabled": false }
  ]
}
```

When no `plugins` key is provided, the 34 default plugins are used.

## Optimization Presets

SVGift provides 7 built-in optimization levels (L0-L6) that balance fidelity vs compression:

| Level | Name | Multipass | Precision | Key Features |
|-------|------|-----------|-----------|-------------|
| L0 | `safe` | No | 6 | Pretty output, IDs preserved, debug-friendly |
| L1 | `conservative` | Yes | 4 | Compact output, IDs preserved |
| L2 | `recommended` | Yes | 3 | Balanced, removeDimensions, prefixIds |
| L3 | `compact` | Yes | 2 | Size-oriented, ID minification |
| L4 | `aggressive` | Yes | 2 | Strips styles/scripts/raster images |
| L5 | `extreme` | Yes | 1 | Removes viewBox (fixed-size only) |
| L6 | `maximum` | Yes | 0 | Removes title, needs visual verification |

## Plugins

49 built-in plugins are available. See [docs/plugins.md](docs/plugins.md) for the complete list with descriptions and parameters.

**Default plugins (34):** removeDoctype, removeXMLProcInst, removeComments, removeDeprecatedAttrs, removeMetadata, removeEditorsNSData, cleanupAttrs, mergeStyles, inlineStyles, minifyStyles, cleanupIds, removeUselessDefs, cleanupNumericValues, convertColors, removeUnknownsAndDefaults, removeNonInheritableGroupAttrs, removeUselessStrokeAndFill, cleanupEnableBackground, removeHiddenElems, removeEmptyText, convertShapeToPath, convertEllipseToCircle, moveElemsAttrsToGroup, moveGroupAttrsToElems, collapseGroups, convertPathData, convertTransform, removeEmptyAttrs, removeEmptyContainers, mergePaths, removeUnusedNS, sortAttrs, sortDefsChildren, removeDesc

## Compatibility

SVGift aims for full compatibility with SVGO's optimization output. The test suite validates against 363 SVGO test fixtures with **100% pass rate** (L1 byte-exact and L2 normalized matching).

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`swift test`)
4. Commit your changes
5. Push to the branch and open a Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

- [SVGO](https://github.com/svg/svgo) — the original Node.js SVG optimizer
- Built by [okooo5km (十里)](https://github.com/okooo5km)
