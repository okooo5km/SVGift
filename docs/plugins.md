# SVGift Plugins

All 49 built-in plugins. Plugins marked with ✅ are enabled by default (`preset-default`).

## Plugins by Optimization Level

SVGift provides 7 built-in presets (L0-L6). All levels share a common base of 33 preset-default plugins. The table below shows what each level adds or changes relative to that base.

### Base plugins (all levels)

All levels include these 33 plugins from preset-default (in execution order):

`removeDoctype`, `removeXMLProcInst`, `removeComments`, `removeDeprecatedAttrs`, `removeMetadata`, `removeEditorsNSData`, `cleanupAttrs`, `mergeStyles`, `inlineStyles`, `minifyStyles`, `cleanupIds`, `removeUselessDefs`, `cleanupNumericValues`, `convertColors`, `removeUnknownsAndDefaults`, `removeNonInheritableGroupAttrs`, `removeUselessStrokeAndFill`, `cleanupEnableBackground`, `removeHiddenElems`, `removeEmptyText`, `convertShapeToPath`, `convertEllipseToCircle`, `moveElemsAttrsToGroup`, `moveGroupAttrsToElems`, `collapseGroups`, `convertPathData`, `convertTransform`, `removeEmptyAttrs`, `removeEmptyContainers`, `mergePaths`, `removeUnusedNS`, `sortAttrs`, `sortDefsChildren`

### Per-level additions and parameter overrides

| Level | Extra Plugins | Parameter Overrides | Output |
|-------|--------------|---------------------|--------|
| L0 `safe` | `removeDesc` (disabled) | `cleanupIds`: minify=false | pretty=true, precision=6, single-pass |
| L1 `conservative` | `removeDesc` (disabled) | `cleanupIds`: minify=false | precision=4, multipass |
| L2 `recommended` | +`removeDesc`, +`removeDimensions`, +`prefixIds`(prefix="o") | `cleanupIds`: minify=false | precision=3, multipass |
| L3 `compact` | +`removeDesc`, +`removeDimensions` | (defaults) | precision=2, multipass |
| L4 `aggressive` | +`removeDesc`, +`removeDimensions`, +`removeStyleElement`, +`removeScripts`, +`removeRasterImages` | (defaults) | precision=2, multipass |
| L5 `extreme` | L4 plugins + `removeViewBox` | (defaults) | precision=1, multipass |
| L6 `maximum` | L5 plugins + `removeTitle` | (defaults) | precision=0, multipass |

### Key differences explained

- **`cleanupIds` minify** — L0-L2 set `minify=false` to preserve original IDs. L3+ use the default (`minify=true`), which replaces IDs with short generated names for smaller output.
- **`prefixIds`** — Only L2 enables this plugin (with `prefix="o"`, `delim=""`). It prevents ID collisions when multiple SVGs are embedded in the same HTML page. L3+ omit it because ID minification already produces unique short IDs per file.
- **`removeDesc`** — L0 and L1 explicitly disable this plugin to preserve `<desc>` elements. L2+ enable it.
- **`removeDimensions`** — Added at L2+. Removes `width`/`height` attributes so the SVG scales via CSS `viewBox`.

---

## preset-default Plugins (34)

These plugins run in the following order when using the default configuration:

| # | Plugin | Description |
|---|--------|-------------|
| 1 | `removeDoctype` | Remove `<!DOCTYPE>` declaration |
| 2 | `removeXMLProcInst` | Remove `<?xml?>` processing instruction |
| 3 | `removeComments` | Remove XML comments. Params: `preservePatterns` (array of regex strings) |
| 4 | `removeDeprecatedAttrs` | Remove deprecated SVG attributes |
| 5 | `removeMetadata` | Remove `<metadata>` elements |
| 6 | `removeEditorsNSData` | Remove editor-specific namespaces, attributes, and elements (Inkscape, Sketch, etc.) |
| 7 | `cleanupAttrs` | Clean up whitespace in attribute values. Params: `newlines` (bool), `trim` (bool), `spaces` (bool) |
| 8 | `mergeStyles` | Merge multiple `<style>` elements into one |
| 9 | `inlineStyles` | Inline CSS rules into matching elements' `style` attributes. Params: `onlyMatchedOnce` (bool), `removeMatchedSelectors` (bool), `useMqs` (array), `usePseudos` (array) |
| 10 | `minifyStyles` | Minify CSS in `<style>` elements. Params: `usage` (bool) |
| 11 | `cleanupIds` | Remove unused IDs and minify used IDs. Params: `remove` (bool), `minify` (bool), `preserve` (array), `preservePrefixes` (array), `force` (bool) |
| 12 | `removeUselessDefs` | Remove elements in `<defs>` that are not referenced |
| 13 | `cleanupNumericValues` | Round numeric values; optimize viewBox. Params: `floatPrecision` (int), `leadingZero` (bool), `defaultPx` (bool), `convertToPx` (bool) |
| 14 | `convertColors` | Convert color values to shorter forms. Params: `currentColor` (bool/string), `names2hex` (bool), `rgb2hex` (bool), `convertCase` (string: "lower"/"upper"), `shorthex` (bool), `shortname` (bool) |
| 15 | `removeUnknownsAndDefaults` | Remove unknown elements/attributes and default values. Params: `unknownContent` (bool), `unknownAttrs` (bool), `defaultAttrs` (bool), `defaultMarkupDeclarations` (bool), `uselessOverrides` (bool), `keepDataAttrs` (bool), `keepAriaAttrs` (bool), `keepRoleAttr` (bool) |
| 16 | `removeNonInheritableGroupAttrs` | Remove non-inheritable presentation attributes from groups |
| 17 | `removeUselessStrokeAndFill` | Remove useless `stroke` and `fill` attributes. Params: `stroke` (bool), `fill` (bool), `removeNone` (bool) |
| 18 | `cleanupEnableBackground` | Remove or clean up `enable-background` attributes |
| 19 | `removeHiddenElems` | Remove hidden/invisible elements. Params: multiple boolean flags for specific removal behaviors |
| 20 | `removeEmptyText` | Remove empty `<text>`, `<tspan>`, `<tref>` elements |
| 21 | `convertShapeToPath` | Convert basic shapes to `<path>`. Params: `convertArcs` (bool) |
| 22 | `convertEllipseToCircle` | Convert `<ellipse>` with equal rx/ry to `<circle>` |
| 23 | `moveElemsAttrsToGroup` | Move common attributes from group children to the group |
| 24 | `moveGroupAttrsToElems` | Move attributes from groups with single children to the child |
| 25 | `collapseGroups` | Collapse unnecessary `<g>` wrapper groups |
| 26 | `convertPathData` | Optimize path data: convert to relative/absolute, merge commands, remove redundancy. Params: `applyTransforms` (bool), `applyTransformsStroked` (bool), `floatPrecision` (int), `transformPrecision` (int), and more |
| 27 | `convertTransform` | Optimize transform attributes. Params: `floatPrecision` (int), `transformPrecision` (int), and more |
| 28 | `removeEmptyAttrs` | Remove attributes with empty values |
| 29 | `removeEmptyContainers` | Remove empty container elements |
| 30 | `mergePaths` | Merge adjacent `<path>` elements. Params: `force` (bool), `floatPrecision` (int) |
| 31 | `removeUnusedNS` | Remove unused namespace declarations |
| 32 | `sortAttrs` | Sort element attributes for consistency. Params: `xmlnsOrder` (string: "front"/"alphabetical") |
| 33 | `sortDefsChildren` | Sort children of `<defs>` for deterministic output |
| 34 | `removeDesc` | Remove `<desc>` elements. Params: `removeAny` (bool) |

## Non-default Plugins (15)

These plugins are available but not enabled by default. Enable them via config file or CLI.

| Plugin | Description |
|--------|-------------|
| `addAttributesToSVGElement` | Add attributes to the root `<svg>` element. Params: `attributes` (dict or array) |
| `addClassesToSVGElement` | Add class names to the root `<svg>` element. Params: `classNames` (array) or `className` (string) |
| `cleanupListOfValues` | Round numeric values in list-type attributes (e.g., `points`, `viewBox`). Params: `floatPrecision` (int), `leadingZero` (bool), `defaultPx` (bool), `convertToPx` (bool) |
| `convertOneStopGradients` | Convert single-stop gradients to a plain color |
| `prefixIds` | Prefix IDs and references to avoid conflicts. Params: `prefix` (string/bool), `delim` (string) |
| `removeAttrs` | Remove specified attributes by pattern. Params: `attrs` (string or array of patterns) |
| `removeDimensions` | Remove `width`/`height` attributes (use `viewBox` instead) |
| `removeElementsByAttr` | Remove elements matching attribute patterns. Params: `id` (array), `class` (array) |
| `removeRasterImages` | Remove raster `<image>` elements |
| `removeScripts` | Remove `<script>` elements and event handler attributes |
| `removeStyleElement` | Remove `<style>` elements |
| `removeTitle` | Remove `<title>` elements |
| `removeViewBox` | Remove `viewBox` attribute when it matches `width`/`height` |
| `removeXlink` | Remove xlink namespace usage; upgrade to SVG 2 `href`. Params: `includeLegacy` (bool) |
| `removeXMLNS` | Remove `xmlns` attribute from root SVG (for inline use) |
