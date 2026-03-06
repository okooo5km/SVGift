// Collections.swift
// SVG element and attribute group collections (from SVGO _collections.js)
// okooo5km(十里)

import Foundation

// MARK: - Element Groups

/// Groups of SVG elements by category.
public let elemsGroups: [String: Set<String>] = [
    "animation": [
        "animate", "animateColor", "animateMotion", "animateTransform", "set",
    ],
    "descriptive": ["desc", "metadata", "title"],
    "shape": [
        "circle", "ellipse", "line", "path", "polygon", "polyline", "rect",
    ],
    "structural": ["defs", "g", "svg", "symbol", "use"],
    "paintServer": [
        "hatch", "linearGradient", "meshGradient", "pattern",
        "radialGradient", "solidColor",
    ],
    "nonRendering": [
        "clipPath", "filter", "linearGradient", "marker", "mask",
        "pattern", "radialGradient", "solidColor", "symbol",
    ],
    "container": [
        "a", "defs", "foreignObject", "g", "marker", "mask",
        "missing-glyph", "pattern", "svg", "switch", "symbol",
    ],
    "textContent": [
        "a", "altGlyph", "altGlyphDef", "altGlyphItem", "glyph",
        "glyphRef", "text", "textPath", "tref", "tspan",
    ],
    "textContentChild": ["altGlyph", "textPath", "tref", "tspan"],
    "lightSource": [
        "feDiffuseLighting", "feDistantLight", "fePointLight",
        "feSpecularLighting", "feSpotLight",
    ],
    "filterPrimitive": [
        "feBlend", "feColorMatrix", "feComponentTransfer", "feComposite",
        "feConvolveMatrix", "feDiffuseLighting", "feDisplacementMap",
        "feDropShadow", "feFlood", "feFuncA", "feFuncB", "feFuncG",
        "feFuncR", "feGaussianBlur", "feImage", "feMerge", "feMergeNode",
        "feMorphology", "feOffset", "feSpecularLighting", "feTile",
        "feTurbulence",
    ],
]

/// Elements where whitespace is significant.
public let textElems: Set<String> = {
    var result = elemsGroups["textContent"] ?? []
    result.insert("pre")
    result.insert("title")
    return result
}()

/// Elements that can have a `d` attribute.
public let pathElems: Set<String> = ["glyph", "missing-glyph", "path"]

// MARK: - Attribute Groups

/// Groups of SVG attributes by category.
public let attrsGroups: [String: Set<String>] = [
    "animationAddition": ["additive", "accumulate"],
    "animationAttributeTarget": ["attributeType", "attributeName"],
    "animationEvent": ["onbegin", "onend", "onrepeat", "onload"],
    "animationTiming": [
        "begin", "dur", "end", "fill", "max", "min",
        "repeatCount", "repeatDur", "restart",
    ],
    "animationValue": [
        "by", "calcMode", "from", "keySplines", "keyTimes", "to", "values",
    ],
    "conditionalProcessing": [
        "requiredExtensions", "requiredFeatures", "systemLanguage",
    ],
    "core": ["id", "tabindex", "xml:base", "xml:lang", "xml:space"],
    "graphicalEvent": [
        "onactivate", "onclick", "onfocusin", "onfocusout", "onload",
        "onmousedown", "onmousemove", "onmouseout", "onmouseover", "onmouseup",
    ],
    "presentation": [
        "alignment-baseline", "baseline-shift", "clip-path", "clip-rule",
        "clip", "color-interpolation-filters", "color-interpolation",
        "color-profile", "color-rendering", "color", "cursor", "direction",
        "display", "dominant-baseline", "enable-background", "fill-opacity",
        "fill-rule", "fill", "filter", "flood-color", "flood-opacity",
        "font-family", "font-size-adjust", "font-size", "font-stretch",
        "font-style", "font-variant", "font-weight",
        "glyph-orientation-horizontal", "glyph-orientation-vertical",
        "image-rendering", "letter-spacing", "lighting-color", "marker-end",
        "marker-mid", "marker-start", "mask", "opacity", "overflow",
        "paint-order", "pointer-events", "shape-rendering", "stop-color",
        "stop-opacity", "stroke-dasharray", "stroke-dashoffset",
        "stroke-linecap", "stroke-linejoin", "stroke-miterlimit",
        "stroke-opacity", "stroke-width", "stroke", "text-anchor",
        "text-decoration", "text-overflow", "text-rendering",
        "transform-origin", "transform", "unicode-bidi", "vector-effect",
        "visibility", "word-spacing", "writing-mode",
    ],
    "xlink": [
        "xlink:actuate", "xlink:arcrole", "xlink:href", "xlink:role",
        "xlink:show", "xlink:title", "xlink:type",
    ],
    "documentEvent": [
        "onabort", "onerror", "onresize", "onscroll", "onunload", "onzoom",
    ],
    "documentElementEvent": ["oncopy", "oncut", "onpaste"],
    "globalEvent": [
        "oncancel", "oncanplay", "oncanplaythrough", "onchange", "onclick",
        "onclose", "oncuechange", "ondblclick", "ondrag", "ondragend",
        "ondragenter", "ondragleave", "ondragover", "ondragstart", "ondrop",
        "ondurationchange", "onemptied", "onended", "onerror", "onfocus",
        "oninput", "oninvalid", "onkeydown", "onkeypress", "onkeyup",
        "onload", "onloadeddata", "onloadedmetadata", "onloadstart",
        "onmousedown", "onmouseenter", "onmouseleave", "onmousemove",
        "onmouseout", "onmouseover", "onmouseup", "onmousewheel", "onpause",
        "onplay", "onplaying", "onpointercancel", "onpointerdown",
        "onpointerenter", "onpointerleave", "onpointermove", "onpointerout",
        "onpointerover", "onpointerup", "onprogress", "onratechange",
        "onreset", "onseeked", "onseeking", "onselect", "onshow",
        "onstalled", "onsubmit", "onsuspend", "ontimeupdate", "ontoggle",
        "onvolumechange", "onwaiting",
    ],
]

// MARK: - Reference Properties

/// Attributes that can contain URL references (e.g. `url(#id)`).
public let referencesProps: Set<String> = [
    "clip-path", "color-profile", "fill", "filter",
    "marker-end", "marker-mid", "marker-start", "mask", "stroke", "style",
]

// inheritableAttrs and presentationNonInheritableGroupAttrs are defined in PresentationAttrs.swift
