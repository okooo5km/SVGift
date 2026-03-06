// PresentationAttrs.swift
// SVG presentation attributes collection (from SVGO _collections.js)
// okooo5km(十里)

/// Set of SVG presentation attributes that can be set via CSS or XML attributes.
/// Matches SVGO's `attrsGroups.presentation`.
public let presentationAttrs: Set<String> = [
    "alignment-baseline",
    "baseline-shift",
    "clip",
    "clip-path",
    "clip-rule",
    "color",
    "color-interpolation",
    "color-interpolation-filters",
    "color-profile",
    "color-rendering",
    "cursor",
    "direction",
    "display",
    "dominant-baseline",
    "enable-background",
    "fill",
    "fill-opacity",
    "fill-rule",
    "filter",
    "flood-color",
    "flood-opacity",
    "font-family",
    "font-size",
    "font-size-adjust",
    "font-stretch",
    "font-style",
    "font-variant",
    "font-weight",
    "glyph-orientation-horizontal",
    "glyph-orientation-vertical",
    "image-rendering",
    "letter-spacing",
    "lighting-color",
    "marker-end",
    "marker-mid",
    "marker-start",
    "mask",
    "opacity",
    "overflow",
    "paint-order",
    "pointer-events",
    "shape-rendering",
    "stop-color",
    "stop-opacity",
    "stroke",
    "stroke-dasharray",
    "stroke-dashoffset",
    "stroke-linecap",
    "stroke-linejoin",
    "stroke-miterlimit",
    "stroke-opacity",
    "stroke-width",
    "text-anchor",
    "text-decoration",
    "text-overflow",
    "text-rendering",
    "transform",
    "transform-origin",
    "unicode-bidi",
    "vector-effect",
    "visibility",
    "word-spacing",
    "writing-mode",
]

/// Inheritable presentation attributes (subset of presentationAttrs)
public let inheritableAttrs: Set<String> = [
    "clip-rule",
    "color",
    "color-interpolation",
    "color-interpolation-filters",
    "color-profile",
    "color-rendering",
    "cursor",
    "direction",
    "dominant-baseline",
    "fill",
    "fill-opacity",
    "fill-rule",
    "font",
    "font-family",
    "font-size",
    "font-size-adjust",
    "font-stretch",
    "font-style",
    "font-variant",
    "font-weight",
    "glyph-orientation-horizontal",
    "glyph-orientation-vertical",
    "image-rendering",
    "letter-spacing",
    "marker",
    "marker-end",
    "marker-mid",
    "marker-start",
    "paint-order",
    "pointer-events",
    "shape-rendering",
    "stroke",
    "stroke-dasharray",
    "stroke-dashoffset",
    "stroke-linecap",
    "stroke-linejoin",
    "stroke-miterlimit",
    "stroke-opacity",
    "stroke-width",
    "text-anchor",
    "text-rendering",
    "transform",
    "visibility",
    "word-spacing",
    "writing-mode",
]

/// Presentation attributes that are NOT inheritable when applied to group elements
public let presentationNonInheritableGroupAttrs: Set<String> = [
    "clip-path",
    "display",
    "filter",
    "mask",
    "opacity",
    "text-decoration",
    "transform",
    "unicode-bidi",
]

/// Pseudo-class categories from SVGO _collections.js
public struct PseudoClassCategories {
    public static let functional: Set<String> = ["is", "not", "where", "has"]
    public static let treeStructural: Set<String> = [
        "empty", "first-child", "first-of-type", "last-child", "last-of-type",
        "nth-child", "nth-last-child", "nth-last-of-type", "nth-of-type",
        "only-child", "only-of-type", "root",
    ]
    public static let userAction: Set<String> = [
        "active", "focus-visible", "focus-within", "focus", "hover",
    ]
    public static let location: Set<String> = [
        "any-link", "link", "local-link", "scope", "target-within", "target", "visited",
    ]
    public static let timeDimensional: Set<String> = ["current", "past", "future"]
    public static let resourceState: Set<String> = ["playing", "paused"]

    /// Pseudo-classes that can be evaluated at optimization time
    public static let preserved: Set<String> = functional.union(treeStructural)
}
