# SVGO Rewrite Pitfalls — Lessons from the Go Implementation (OGVS)

> Author: okooo5km(十里)
> Date: 2026-03-06
> Source: [OGVS](https://github.com/okooo5km/ogvs) — 53 plugins, 363/363 fixture tests passing

This document summarizes all the tricky implementation details, hidden behaviors, and subtle bugs encountered when rewriting [SVGO](https://github.com/nicerobot/svgo) (Node.js) in Go. These lessons are **language-agnostic** — any team porting SVGO to Swift, Rust, Python, or another language will face the same issues.

The pitfalls are organized by subsystem, roughly in the order you'd encounter them during implementation.

---

## Table of Contents

1. [XML Parsing](#1-xml-parsing)
2. [AST Model & Stringifier](#2-ast-model--stringifier)
3. [Numeric Formatting](#3-numeric-formatting)
4. [CSS Parsing & Cascade](#4-css-parsing--cascade)
5. [Path Data & Geometry](#5-path-data--geometry)
6. [Regex Patterns](#6-regex-patterns)
7. [Collection Ordering & Mutation](#7-collection-ordering--mutation)
8. [Plugin-specific Gotchas](#8-plugin-specific-gotchas)
9. [Known Behavioral Differences](#9-known-behavioral-differences)
10. [Test Infrastructure](#10-test-infrastructure)

---

## 1. XML Parsing

### 1.1 Namespace Prefix Preservation (Critical)

**Problem:** Many XML parsers normalize namespace prefixes — if two prefixes map to the same URI, they get merged into one. SVGO preserves original prefixes exactly as written.

**Example:**
```xml
<svg xmlns:xlink="http://www.w3.org/1999/xlink"
     xmlns:xl="http://www.w3.org/1999/xlink">
  <use xlink:href="#a"/>
  <use xl:href="#b"/>
</svg>
```

Standard parsers would merge `xlink` and `xl` since they share the same URI. SVGO keeps both.

**Solution:** Use a raw/low-level tokenizer that returns tokens without namespace resolution. In Go, this meant `xml.Decoder.RawToken()` instead of `Token()`. In Swift, you'll need an equivalent approach — `XMLParser` may or may not suffice; verify this early.

### 1.2 CDATA vs Text Distinction

**Problem:** Most parsers merge CDATA sections and text nodes into the same token type. SVGO distinguishes them — `<style>` content wrapped in `<![CDATA[...]]>` must stay as CDATA in output.

**Solution:** After reading a text token, check the raw input bytes around the current parser offset. If the bytes just before the offset are `]]>`, the token was CDATA. Store a boolean flag (`isCDATA`) on the text node.

### 1.3 DOCTYPE & Entity Pre-scanning

**Problem:** SVG files may contain custom entity declarations in DOCTYPE:
```xml
<!DOCTYPE svg [
  <!ENTITY red "#ff0000">
]>
<svg><rect fill="&red;"/></svg>
```

Most XML parsers need entity definitions before parsing starts, but entities live inside the document itself.

**Solution:** Pre-scan the raw input string for `<!DOCTYPE ... [ ... ]>`, extract `<!ENTITY name "value">` declarations with regex, perform string replacement of `&name;` → `value` in the input, then parse the modified input.

**Side effect:** This changes the relative position of DOCTYPE in the output (it appears before `<?xml?>` processing instruction). This is a known cosmetic difference from SVGO.

### 1.4 Encoding Declaration Handling

**Problem:** Many SVG files declare `encoding="utf-16"` or `encoding="iso-8859-1"` but are actually UTF-8. SVGO ignores encoding declarations entirely.

**Solution:** The charset/encoding reader callback should return the input unchanged — never actually transcode.

### 1.5 Case Sensitivity

SVG is XML, not HTML. Element and attribute names are **case-sensitive**:
- `viewBox` (not `viewbox`)
- `linearGradient` (not `lineargradient`)
- `textPath` (not `textpath`)
- `clipPathUnits`, `gradientTransform`, `preserveAspectRatio`

**Never** lowercase element/attribute names in the parser. If you do, dozens of plugins will break silently.

### 1.6 Root-level Text Nodes

SVGO's parser silently skips text nodes at the root level (outside the `<svg>` element). Only element, comment, PI, and doctype nodes survive at root level. Whitespace-only text nodes inside non-text elements are also trimmed/dropped.

---

## 2. AST Model & Stringifier

### 2.1 Ordered Attributes

SVG attribute order matters for test compatibility and deterministic output. Standard dictionary/map types in most languages have undefined iteration order.

**Solution:** Use an ordered map (insertion-order-preserving) for element attributes. In Go we built `OrderedAttrs`; in Swift, consider a custom `OrderedDictionary` or `[(key, value)]` with index lookup.

### 2.2 Boolean Attributes (No-value Attributes)

HTML-style boolean attributes like `<svg focusable>` have no `=""` in the source. SVGO preserves this — the output should be `focusable`, not `focusable=""`.

**Solution:** Use a sentinel value (e.g., `"\x00"` or a dedicated enum case) to distinguish "attribute with empty string value" from "attribute with no value". The stringifier checks for this sentinel and omits `="..."` when found.

### 2.3 Self-closing Tags

With `UseShortTags: true` (default), elements with no children output as `<element/>`. With `false`, they output as `<element></element>`.

**Exception:** Inside text elements (`text`, `tspan`, `textPath`, etc.), never add indentation and always use the configured tag style regardless of context.

### 2.4 Text Element Whitespace

The stringifier must know which elements are "text elements" to preserve whitespace:
- `text`, `tspan`, `textPath`, `tref`, `altGlyph`, `title`, `desc`, `pre`
- Inside these: preserve all whitespace, no indentation
- Outside these: trim whitespace, drop empty text nodes
- CDATA: always preserved as-is

---

## 3. Numeric Formatting

### 3.1 Negative Zero (Critical)

**Problem:** IEEE 754 floats distinguish `-0.0` from `0.0`. After transformations, you'll frequently get `-0.0` results. JavaScript's `String(-0)` returns `"0"`, but most other languages format it as `"-0"`.

**Solution:** Before formatting any float, normalize: `if value == 0 { value = 0 }` (or equivalent). This affects path data, transforms, coordinates, colors — everywhere numbers appear.

### 3.2 Exponent Format

**Problem:** JavaScript formats `0.0000001` as `"1e-7"`, but many languages use 3-digit exponents: `"1e-07"` or `"1e-007"`.

**Solution:** After formatting, strip leading zeros from the exponent part: `1e-07` → `1e-7`, `1e+08` → `1e+8`.

### 3.3 Leading Zero Removal

SVGO removes leading zeros for numbers between -1 and 1:
- `0.5` → `.5`
- `-0.5` → `-.5`

This is a string post-processing step, not a formatting option. Only apply when `leadingZero` option is true (default in most plugins).

### 3.4 Precision and Rounding

`floatPrecision` (default 3) controls decimal places. Use proper rounding (round half away from zero), not truncation. JavaScript's `Number.toFixed()` has specific rounding behavior — replicate it exactly.

---

## 4. CSS Parsing & Cascade

### 4.1 Use a Real CSS Parser

SVGO uses a proper CSS parser (CSSTree) for `<style>` content, not regex. You must do the same. Regex-based CSS parsing will break on:
- Nested at-rules (`@media { @supports { ... } }`)
- String literals containing CSS-like syntax
- Comments inside selectors
- Escaped characters in identifiers

### 4.2 CSS Selector Matching

The `inlineStyles` plugin needs full CSS selector matching against the SVG DOM. Key features required:
- Type selectors (`rect`, `circle`)
- Class selectors (`.cls-1`)
- ID selectors (`#my-id`)
- Attribute selectors (`[fill]`, `[fill="red"]`)
- Combinators: descendant (space), child (`>`), adjacent sibling (`+`), general sibling (`~`)
- Pseudo-class: `:not()` with simple selectors
- NOT required: `:is()`, `:has()`, `:where()` (SVGO doesn't support these either)

**Matching direction:** Parse selectors left-to-right, but match right-to-left (start from the target element, walk up to ancestors). This requires a parent map.

### 4.3 Specificity Calculation

CSS specificity determines which rule wins when multiple rules target the same element. Standard (a, b, c) calculation where:
- a = ID selectors count
- b = class/attribute/pseudo-class selectors count
- c = type/pseudo-element selectors count
- Inline styles beat all stylesheet rules

### 4.4 CSS Compaction

The `minifyStyles` and `prefixIds` plugins need to re-serialize CSS from parsed form. Key requirements:
- Preserve at-rules (`@media`, `@keyframes`, `@font-face`)
- Remove empty rule sets
- Compact whitespace
- Handle selector lists (comma-separated)

### 4.5 CSS Custom Properties (var())

CSS custom properties (`--my-color: red`) and `var(--my-color)` references must be preserved through optimization. Plugins that modify style values must not strip or corrupt custom properties.

---

## 5. Path Data & Geometry

### 5.1 SVG Path BNF Parser

The `d` attribute of `<path>` elements uses a mini-language (M, L, C, A, Z, etc.). You need a proper state-machine parser following the SVG Path BNF grammar. Key subtleties:
- Implicit `lineto` after `moveto`: `M 0 0 10 10` means `M 0 0 L 10 10`
- Implicit command repetition: `L 0 0 10 10` means `L 0 0 L 10 10`
- Flag arguments in arcs are single digits (0 or 1) with no separator needed: `A 10 10 0 0110 20` is valid
- Commas and whitespace are interchangeable separators
- Negative numbers act as implicit separators: `10-5` means `10, -5`

### 5.2 Path Transform Application — Cache Invalidation (Critical)

**Problem:** In JavaScript, SVGO caches parsed path data on the DOM node object. After `applyTransforms` modifies the path data, subsequent plugins see the updated cached data. In other languages, there's no such automatic caching.

**Solution:** After transforming path data, you MUST serialize it back to the `d` attribute immediately:
```
pathData = applyTransforms(element)
element.setAttribute("d", stringifyPathData(pathData))
```

If you forget this step, downstream plugins (like `convertPathData`) will re-parse the original `d` attribute and get stale data.

### 5.3 Value Semantics vs Reference Semantics (Critical)

**Problem:** In SVGO's `convertPathData` plugin, JavaScript objects are passed by reference. When the code does:
```javascript
let arc = output[0];
arc.args = [...];  // This modifies output[0] too!
```

In languages with value semantics (Go structs, Swift structs), `arc` is a copy. Modifications to `arc` don't affect `output[0]`.

**Solution:** After any modifications to a copied path command, write it back:
```
arc = output[0]     // copy
arc.args = ...      // modify copy
output[0] = arc     // write back!
```

This affects `makeArcs()` in path optimization and several other path manipulation functions.

### 5.4 Arc Conversion & Transform

Arc commands (A/a) require special math when applying transforms:
- Non-uniform scaling or rotation changes the arc's rx, ry, and rotation angle
- The `transformArc()` function uses matrix decomposition (SVD-like) to compute new arc parameters
- Edge case: if the transform makes the arc degenerate (rx or ry → 0), convert to a line

### 5.5 Path Intersection (GJK Algorithm)

The `mergePaths` plugin needs to check if two paths intersect. OGVS implements the GJK (Gilbert-Johnson-Keerthi) collision detection algorithm for this. This is a non-trivial geometric algorithm — consider using a library if available.

---

## 6. Regex Patterns

### 6.1 Lookaheads

SVGO uses negative lookaheads like `(?!...)` in several plugins. Not all regex engines support them (Go's RE2 doesn't).

**Affected plugins:** `removeAttrs`, `removeElementsByAttr`

**Solution:** Either use a PCRE-compatible regex library as fallback, or rewrite the pattern without lookaheads (case-by-case).

### 6.2 Backreferences

SVGO uses backreferences (`\1`) in patterns like:
- **Hex color shortening:** `/#([0-9a-f])\1([0-9a-f])\2([0-9a-f])\3/i` — checks if each hex pair has identical digits
- **XML attribute quote matching:** `/standalone\s*=\s*(["'])no\1/` — ensures opening and closing quotes match
- **URL reference extraction:** `/url\((["']?)(#.+?)\1\)/` — ensures URL quotes match

**Solutions (without backreferences):**
1. **Hex colors:** Use a 6-char capture + manual pair comparison in code
2. **Quote matching:** Two separate regexes, one for single quotes and one for double quotes
3. **URL references:** 3-group capture `(quote1)(content)(quote2)` + validate `quote1 == quote2` in replacement function

### 6.3 Pattern Compilation Cost

Some plugins compile regex patterns from user-provided parameters (e.g., `removeAttrs` accepts regex strings). Cache compiled patterns to avoid re-compilation on every element visit.

---

## 7. Collection Ordering & Mutation

### 7.1 Map Iteration Order

**Problem:** When iterating over maps/dictionaries to generate output, random iteration order causes non-deterministic results. SVGO tests expect deterministic output.

**Affected plugins:** `reusePaths` (groups paths by content), `cleanupIds` (assigns new IDs), `sortAttrs`

**Solution:** Use ordered data structures or sort keys before iteration. For `reusePaths`, track insertion order with a separate list alongside the lookup map.

### 7.2 Mutation During Iteration (Critical)

**Problem:** Deleting or adding attributes/children while iterating over them causes undefined behavior in most languages.

**Affected operations:**
- Deleting attributes in `removeUnknownsAndDefaults`, `removeXlink`, `removeEditorsNSData`
- Removing child nodes in `removeEmptyContainers`, `collapseGroups`
- Moving nodes between parents in `moveElemsAttrsToGroup`

**Solution:** Always snapshot the collection before mutation:
```
keysToDelete = []
for each entry in attributes:
    if shouldDelete(entry):
        keysToDelete.append(entry.key)
for key in keysToDelete:
    attributes.delete(key)
```

---

## 8. Plugin-specific Gotchas

### 8.1 removeEmptyAttrs — Conditional Processing Exception

Empty attributes are normally removed, but these must be preserved even when empty:
- `requiredFeatures`
- `requiredExtensions`
- `systemLanguage`

**Why:** In SVG, empty conditional processing attributes prevent element rendering — they serve as guards.

### 8.2 prefixIds — CSS Token-based Rewriting

This plugin prefixes all IDs, classes, and references in the SVG. The CSS rewriting **must** use a proper CSS tokenizer, not regex, because:
- `#hash` in a selector is an ID, but `#fff` in a declaration value is a color
- `url(#id)` references need prefixing, but `url(https://...)` does not
- `@keyframes name` animation names need prefixing
- Nested at-rules (`@media { ... }`) require recursive handling

### 8.3 convertPathData — Precision Accumulation

Path optimization involves many floating-point operations. Without careful precision management, errors accumulate and output diverges from SVGO. Key rules:
- Apply `floatPrecision` (default 3) consistently via `ToFixed()` or equivalent
- Use `-1` precision (no rounding) for intermediate transforms
- Only round at the final serialization step

### 8.4 inlineStyles — Specificity-aware Inlining

When inlining CSS rules to `style=""` attributes:
- Higher-specificity rules override lower ones
- `!important` declarations always win
- Existing inline styles have highest base specificity
- Shorthand properties (e.g., `margin`) interact with longhand properties (e.g., `margin-top`)

### 8.5 cleanupIds — Reference Tracking

Before renaming or removing an ID, you must check ALL possible references:
- `url(#id)` in attributes and `<style>` blocks
- `xlink:href="#id"` and `href="#id"` on `<use>`, `<image>`, etc.
- `begin="id.click"` in animation elements
- CSS selectors like `#id` in `<style>` blocks

### 8.6 collapseGroups — Careful Attribute Merging

When collapsing a `<g>` into its single child:
- Merge attributes (child wins on conflict)
- `class` attributes are concatenated, not overwritten
- `transform` attributes must be composed (parent transform applied first)
- `clip-path`, `mask`, `filter` with conflicting values prevent collapsing

### 8.7 removeHiddenElems — Many Invisibility Conditions

Elements can be hidden in many ways:
- `display: none`
- `visibility: hidden` (but children can override)
- `opacity: 0`
- Zero-dimension shapes (`width="0"`, `height="0"`, `r="0"`, `rx="0"`, `ry="0"`)
- `<path d="">` (empty path)
- `viewBox` with zero width or height
- `clip-path` pointing to empty clip

Each condition has exceptions and edge cases. Test thoroughly against SVGO fixtures.

---

## 9. Known Behavioral Differences

These are differences we accepted between OGVS and SVGO. A new rewrite may choose differently:

### 9.1 Color Conversion in Inline Styles

- **SVGO:** Converts color names everywhere, including inside `style=""` attributes (`fill:blue` → `fill:#00f`)
- **OGVS:** Only converts colors in presentation attributes, not in CSS style declarations

### 9.2 DOCTYPE Output Order

- **SVGO:** Preserves original document order
- **OGVS:** DOCTYPE appears before `<?xml?>` processing instruction (due to pre-scanning)

These differences are cosmetic and don't affect optimization quality. All 363 SVGO test fixtures pass at L1 (byte-identical) level.

---

## 10. Test Infrastructure

### 10.1 SVGO Fixture Format

SVGO test fixtures follow this format:
```
description text

===

<svg>input svg</svg>

@@@

<svg>expected output</svg>
```

Optional plugin params can follow as JSON after a second `@@@`:
```
@@@

{"paramName": value}
```

### 10.2 Two-level Assertion Strategy

- **L1 (Strict):** Byte-identical comparison of output vs expected. This is the gold standard — 363/363 tests should pass at L1.
- **L2 (Canonical):** Normalized comparison (LF line endings, trimmed whitespace, sorted attributes, normalized numbers). Use as fallback during development, but aim for L1.

### 10.3 Idempotence Testing

Every plugin's output should be idempotent: running the optimizer twice should produce the same result as running it once. Test this by feeding each plugin's output back through the same plugin and asserting the output is unchanged.

### 10.4 Multipass Testing

SVGO supports `--multipass` mode (run optimizer repeatedly until output stabilizes). Test that multipass converges (doesn't loop forever) and produces valid output.

---

## Summary: Top 10 Things That Will Bite You

| # | Pitfall | Subsystem | Impact |
|---|---------|-----------|--------|
| 1 | Namespace prefix merging | XML Parser | Silent corruption of prefixed attributes |
| 2 | Case-sensitive SVG names | XML Parser | `viewBox` becomes `viewbox`, breaks everything |
| 3 | Negative zero formatting | Numbers | `-0` in output instead of `0` |
| 4 | Path data cache invalidation | Geometry | Downstream plugins get stale data |
| 5 | Value vs reference semantics | Geometry | Modifications to copies don't propagate |
| 6 | Regex backreferences | Patterns | Compilation failures on non-PCRE engines |
| 7 | Map iteration order | Collections | Non-deterministic output |
| 8 | Mutation during iteration | Collections | Crashes or skipped elements |
| 9 | CDATA vs text distinction | XML Parser | `<style>` content loses CDATA wrapping |
| 10 | CSS context-aware rewriting | CSS | `#fff` color treated as ID selector |

---

## Recommended Implementation Order

Based on our experience, this order minimizes blocked dependencies:

1. **XML parser + AST model + stringifier** — roundtrip 363 fixtures first
2. **Test infrastructure** — fixture loader, L1/L2 assertions, idempotence
3. **Plugin framework** — visitor pattern, registry, preset system
4. **Simple removal plugins** (Wave 0) — removeComments, removeDoctype, etc.
5. **Attribute plugins** (Wave 1) — cleanupAttrs, sortAttrs, etc.
6. **Tool infrastructure** — numeric utils, collections, SVG spec constants
7. **CSS parsing + cascade** — before any style-related plugins
8. **CSS plugins** (Wave 2) — mergeStyles, inlineStyles, minifyStyles
9. **Geometry infrastructure** — path parser, transform algebra
10. **Geometry plugins** (Wave 3) — convertColors, convertShapeToPath, etc.
11. **Removal/structure plugins** (Wave 4) — removeEmptyContainers, collapseGroups, etc.
12. **Complex plugins** (Wave 5) — convertPathData, convertTransform, cleanupIds
13. **Optional plugins** (Wave 6) — prefixIds, reusePaths, etc.
14. **CLI + integration tests**

Each wave should reach 100% fixture test pass rate before moving to the next.
