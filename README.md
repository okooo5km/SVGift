# SVGift

[![Swift CI](https://github.com/okooo5km/svgo-swift/actions/workflows/ci.yml/badge.svg)](https://github.com/okooo5km/svgo-swift/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Swift native implementation of [SVGO](https://github.com/svg/svgo)** — the popular Node.js SVG optimizer.

SVGift provides the same optimization capabilities as SVGO, with 49 built-in plugins (34 enabled by default). It is available as both a **CLI tool** and a **Swift library**.

## Installation

### Homebrew

```bash
brew install okooo5km/tap/svgift
```

### Build from source

```bash
git clone https://github.com/okooo5km/svgo-swift.git
cd svgo-swift
swift build -c release
# Binary at .build/release/svgift
```

### SwiftPM (as a library dependency)

```swift
.package(url: "https://github.com/okooo5km/svgo-swift.git", from: "0.1.0")
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

# Enable multipass optimization
svgift input.svg --multipass -o output.svg

# Pretty-print output
svgift input.svg --pretty

# Use a config file
svgift input.svg --config svgo.config.json -o output.svg

# List available plugins
svgift --show-plugins
```

### Library API

```swift
import SVGift

// Basic usage with default plugins
let input = "<svg>...</svg>"
let result = try optimize(input)
print(result.data)

// Custom options
var options = OptimizeOptions(
    plugins: presetDefaultPlugins,
    pluginRegistry: builtinPluginRegistry
)
options.multipass = true
options.js2svg.pretty = true
let result = try optimize(input, options: options)
```

## Configuration

Create a JSON config file to customize plugin behavior:

```json
{
  "multipass": true,
  "plugins": [
    "preset-default",
    {
      "name": "removeAttrs",
      "params": {
        "attrs": ["fill", "stroke"]
      }
    },
    {
      "name": "addAttributesToSVGElement",
      "params": {
        "attributes": {
          "xmlns": "http://www.w3.org/2000/svg"
        }
      }
    }
  ]
}
```

### Disabling a default plugin

```json
{
  "plugins": [
    "preset-default",
    {
      "name": "removeComments",
      "enabled": false
    }
  ]
}
```

### Customizing plugin parameters

```json
{
  "plugins": [
    {
      "name": "preset-default",
      "params": {
        "overrides": {
          "cleanupIds": {
            "minify": false
          }
        }
      }
    }
  ]
}
```

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
