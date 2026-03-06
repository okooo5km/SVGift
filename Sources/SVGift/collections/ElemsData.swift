// ElemsData.swift
// SVG element definitions ported from SVGO _collections.js
// okooo5km(十里)

import Foundation

// MARK: - Types

/// Configuration for deprecated attributes on an SVG element.
public struct DeprecatedAttrs: Sendable {
    /// Attributes that can be safely removed.
    public var safe: Set<String>
    /// Attributes that are unsafe to remove (may affect rendering).
    public var unsafe: Set<String>

    public init(safe: Set<String> = [], unsafe: Set<String> = []) {
        self.safe = safe
        self.unsafe = unsafe
    }
}

/// Configuration for an SVG element: its attribute groups, specific attributes,
/// defaults, deprecated attributes, and allowed children.
public struct ElemConfig: Sendable {
    /// Attribute group names this element participates in.
    public var attrsGroups: Set<String>
    /// Specific attributes for this element (beyond groups).
    public var attrs: Set<String>
    /// Default attribute values.
    public var defaults: [String: String]
    /// Deprecated attributes.
    public var deprecated: DeprecatedAttrs?
    /// Allowed child element groups.
    public var contentGroups: Set<String>
    /// Specific allowed child elements.
    public var content: Set<String>

    public init(
        attrsGroups: Set<String> = [],
        attrs: Set<String> = [],
        defaults: [String: String] = [:],
        deprecated: DeprecatedAttrs? = nil,
        contentGroups: Set<String> = [],
        content: Set<String> = []
    ) {
        self.attrsGroups = attrsGroups
        self.attrs = attrs
        self.defaults = defaults
        self.deprecated = deprecated
        self.contentGroups = contentGroups
        self.content = content
    }
}

// MARK: - Attribute Group Defaults

/// Default values for attributes within each attribute group.
public let attrsGroupsDefaults: [String: [String: String]] = [
    "core": [
        "xml:space": "default",
    ],
    "presentation": [
        "clip": "auto",
        "clip-path": "none",
        "clip-rule": "nonzero",
        "mask": "none",
        "opacity": "1",
        "stop-color": "#000",
        "stop-opacity": "1",
        "fill-opacity": "1",
        "fill-rule": "nonzero",
        "fill": "#000",
        "stroke": "none",
        "stroke-width": "1",
        "stroke-linecap": "butt",
        "stroke-linejoin": "miter",
        "stroke-miterlimit": "4",
        "stroke-dasharray": "none",
        "stroke-dashoffset": "0",
        "stroke-opacity": "1",
        "paint-order": "normal",
        "vector-effect": "none",
        "display": "inline",
        "visibility": "visible",
        "marker-start": "none",
        "marker-mid": "none",
        "marker-end": "none",
        "color-interpolation": "sRGB",
        "color-interpolation-filters": "linearRGB",
        "color-rendering": "auto",
        "shape-rendering": "auto",
        "text-rendering": "auto",
        "image-rendering": "auto",
        "font-style": "normal",
        "font-variant": "normal",
        "font-weight": "normal",
        "font-stretch": "normal",
        "font-size": "medium",
        "font-size-adjust": "none",
        "kerning": "auto",
        "letter-spacing": "normal",
        "word-spacing": "normal",
        "text-decoration": "none",
        "text-anchor": "start",
        "text-overflow": "clip",
        "writing-mode": "lr-tb",
        "glyph-orientation-vertical": "auto",
        "glyph-orientation-horizontal": "0deg",
        "direction": "ltr",
        "unicode-bidi": "normal",
        "dominant-baseline": "auto",
        "alignment-baseline": "baseline",
        "baseline-shift": "baseline",
    ],
    "transferFunction": [
        "slope": "1",
        "intercept": "0",
        "amplitude": "1",
        "exponent": "1",
        "offset": "0",
    ],
]

// MARK: - Attribute Group Deprecated

/// Deprecated attributes within each attribute group.
public let attrsGroupsDeprecated: [String: DeprecatedAttrs] = [
    "animationAttributeTarget": DeprecatedAttrs(unsafe: ["attributeType"]),
    "conditionalProcessing": DeprecatedAttrs(unsafe: ["requiredFeatures"]),
    "core": DeprecatedAttrs(unsafe: ["xml:base", "xml:lang", "xml:space"]),
    "presentation": DeprecatedAttrs(unsafe: [
        "clip", "color-profile", "enable-background",
        "glyph-orientation-horizontal", "glyph-orientation-vertical", "kerning",
    ]),
]

// MARK: - Editor Namespaces

/// Namespace URIs used by SVG editors that can be safely removed.
public let editorNamespaces: Set<String> = [
    "http://creativecommons.org/ns#",
    "http://inkscape.sourceforge.net/DTD/sodipodi-0.dtd",
    "http://krita.org/namespaces/svg/krita",
    "http://ns.adobe.com/AdobeIllustrator/10.0/",
    "http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/",
    "http://ns.adobe.com/Extensibility/1.0/",
    "http://ns.adobe.com/Flows/1.0/",
    "http://ns.adobe.com/GenericCustomNamespace/1.0/",
    "http://ns.adobe.com/Graphs/1.0/",
    "http://ns.adobe.com/ImageReplacement/1.0/",
    "http://ns.adobe.com/SaveForWeb/1.0/",
    "http://ns.adobe.com/Variables/1.0/",
    "http://ns.adobe.com/XPath/1.0/",
    "http://purl.org/dc/elements/1.1/",
    "http://schemas.microsoft.com/visio/2003/SVGExtensions/",
    "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
    "http://taptrix.com/vectorillustrator/svg_extensions",
    "http://www.bohemiancoding.com/sketch/ns",
    "http://www.figma.com/figma/ns",
    "http://www.inkscape.org/namespaces/inkscape",
    "http://www.serif.com/",
    "http://www.vector.evaxdesign.sk",
    "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
    "https://boxy-svg.com",
]

// MARK: - Element Definitions

/// Complete SVG element definitions from SVGO _collections.js.
public let elems: [String: ElemConfig] = [
    "a": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "style", "target", "transform"],
        defaults: ["target": "_self"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view", "tspan"]
    ),
    "altGlyph": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation", "xlink"],
        attrs: ["class", "dx", "dy", "externalResourcesRequired", "format", "glyphRef", "rotate", "style", "x", "y"]
    ),
    "altGlyphDef": ElemConfig(
        attrsGroups: ["core"],
        content: ["glyphRef"]
    ),
    "altGlyphItem": ElemConfig(
        attrsGroups: ["core"],
        content: ["glyphRef", "altGlyphItem"]
    ),
    "animate": ElemConfig(
        attrsGroups: ["animationAddition", "animationAttributeTarget", "animationEvent", "animationTiming", "animationValue", "conditionalProcessing", "core", "presentation", "xlink"],
        attrs: ["externalResourcesRequired"],
        contentGroups: ["descriptive"]
    ),
    "animateColor": ElemConfig(
        attrsGroups: ["animationAddition", "animationAttributeTarget", "animationEvent", "animationTiming", "animationValue", "conditionalProcessing", "core", "presentation", "xlink"],
        attrs: ["externalResourcesRequired"],
        contentGroups: ["descriptive"]
    ),
    "animateMotion": ElemConfig(
        attrsGroups: ["animationAddition", "animationEvent", "animationTiming", "animationValue", "conditionalProcessing", "core", "xlink"],
        attrs: ["externalResourcesRequired", "keyPoints", "origin", "path", "rotate"],
        defaults: ["rotate": "0"],
        contentGroups: ["descriptive"],
        content: ["mpath"]
    ),
    "animateTransform": ElemConfig(
        attrsGroups: ["animationAddition", "animationAttributeTarget", "animationEvent", "animationTiming", "animationValue", "conditionalProcessing", "core", "xlink"],
        attrs: ["externalResourcesRequired", "type"],
        contentGroups: ["descriptive"]
    ),
    "circle": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "cx", "cy", "externalResourcesRequired", "r", "style", "transform"],
        defaults: ["cx": "0", "cy": "0"],
        contentGroups: ["animation", "descriptive"]
    ),
    "clipPath": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "presentation"],
        attrs: ["class", "clipPathUnits", "externalResourcesRequired", "style", "transform"],
        defaults: ["clipPathUnits": "userSpaceOnUse"],
        contentGroups: ["animation", "descriptive", "shape"],
        content: ["text", "use"]
    ),
    "color-profile": ElemConfig(
        attrsGroups: ["core", "xlink"],
        attrs: ["local", "name", "rendering-intent"],
        defaults: ["name": "sRGB", "rendering-intent": "auto"],
        deprecated: DeprecatedAttrs(unsafe: ["name"]),
        contentGroups: ["descriptive"]
    ),
    "cursor": ElemConfig(
        attrsGroups: ["core", "conditionalProcessing", "xlink"],
        attrs: ["externalResourcesRequired", "x", "y"],
        defaults: ["x": "0", "y": "0"],
        contentGroups: ["descriptive"]
    ),
    "defs": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "style", "transform"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "desc": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["class", "style"]
    ),
    "ellipse": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "cx", "cy", "externalResourcesRequired", "rx", "ry", "style", "transform"],
        defaults: ["cx": "0", "cy": "0"],
        contentGroups: ["animation", "descriptive"]
    ),
    "feBlend": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in", "in2", "mode"],
        defaults: ["mode": "normal"],
        content: ["animate", "set"]
    ),
    "feColorMatrix": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in", "type", "values"],
        defaults: ["type": "matrix"],
        content: ["animate", "set"]
    ),
    "feComponentTransfer": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in"],
        content: ["feFuncA", "feFuncB", "feFuncG", "feFuncR"]
    ),
    "feComposite": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "in", "in2", "k1", "k2", "k3", "k4", "operator", "style"],
        defaults: ["operator": "over", "k1": "0", "k2": "0", "k3": "0", "k4": "0"],
        content: ["animate", "set"]
    ),
    "feConvolveMatrix": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "in", "kernelMatrix", "order", "style", "bias", "divisor", "edgeMode", "targetX", "targetY", "kernelUnitLength", "preserveAlpha"],
        defaults: ["order": "3", "bias": "0", "edgeMode": "duplicate", "preserveAlpha": "false"],
        content: ["animate", "set"]
    ),
    "feDiffuseLighting": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "diffuseConstant", "in", "kernelUnitLength", "style", "surfaceScale"],
        defaults: ["surfaceScale": "1", "diffuseConstant": "1"],
        contentGroups: ["descriptive"],
        content: ["feDistantLight", "fePointLight", "feSpotLight"]
    ),
    "feDisplacementMap": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "in", "in2", "scale", "style", "xChannelSelector", "yChannelSelector"],
        defaults: ["scale": "0", "xChannelSelector": "A", "yChannelSelector": "A"],
        content: ["animate", "set"]
    ),
    "feDistantLight": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["azimuth", "elevation"],
        defaults: ["azimuth": "0", "elevation": "0"],
        content: ["animate", "set"]
    ),
    "feFlood": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style"],
        content: ["animate", "animateColor", "set"]
    ),
    "feFuncA": ElemConfig(
        attrsGroups: ["core", "transferFunction"],
        content: ["set", "animate"]
    ),
    "feFuncB": ElemConfig(
        attrsGroups: ["core", "transferFunction"],
        content: ["set", "animate"]
    ),
    "feFuncG": ElemConfig(
        attrsGroups: ["core", "transferFunction"],
        content: ["set", "animate"]
    ),
    "feFuncR": ElemConfig(
        attrsGroups: ["core", "transferFunction"],
        content: ["set", "animate"]
    ),
    "feGaussianBlur": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in", "stdDeviation"],
        defaults: ["stdDeviation": "0"],
        content: ["set", "animate"]
    ),
    "feImage": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive", "xlink"],
        attrs: ["class", "externalResourcesRequired", "href", "preserveAspectRatio", "style", "xlink:href"],
        defaults: ["preserveAspectRatio": "xMidYMid meet"],
        content: ["animate", "animateTransform", "set"]
    ),
    "feMerge": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style"],
        content: ["feMergeNode"]
    ),
    "feMergeNode": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["in"],
        content: ["animate", "set"]
    ),
    "feMorphology": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in", "operator", "radius"],
        defaults: ["operator": "erode", "radius": "0"],
        content: ["animate", "set"]
    ),
    "feOffset": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in", "dx", "dy"],
        defaults: ["dx": "0", "dy": "0"],
        content: ["animate", "set"]
    ),
    "fePointLight": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["x", "y", "z"],
        defaults: ["x": "0", "y": "0", "z": "0"],
        content: ["animate", "set"]
    ),
    "feSpecularLighting": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "in", "kernelUnitLength", "specularConstant", "specularExponent", "style", "surfaceScale"],
        defaults: ["surfaceScale": "1", "specularConstant": "1", "specularExponent": "1"],
        contentGroups: ["descriptive", "lightSource"]
    ),
    "feSpotLight": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["limitingConeAngle", "pointsAtX", "pointsAtY", "pointsAtZ", "specularExponent", "x", "y", "z"],
        defaults: ["x": "0", "y": "0", "z": "0", "pointsAtX": "0", "pointsAtY": "0", "pointsAtZ": "0", "specularExponent": "1"],
        content: ["animate", "set"]
    ),
    "feTile": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["class", "style", "in"],
        content: ["animate", "set"]
    ),
    "feTurbulence": ElemConfig(
        attrsGroups: ["core", "presentation", "filterPrimitive"],
        attrs: ["baseFrequency", "class", "numOctaves", "seed", "stitchTiles", "style", "type"],
        defaults: ["baseFrequency": "0", "numOctaves": "1", "seed": "0", "stitchTiles": "noStitch", "type": "turbulence"],
        content: ["animate", "set"]
    ),
    "filter": ElemConfig(
        attrsGroups: ["core", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "filterRes", "filterUnits", "height", "href", "primitiveUnits", "style", "width", "x", "xlink:href", "y"],
        defaults: ["primitiveUnits": "userSpaceOnUse", "x": "-10%", "y": "-10%", "width": "120%", "height": "120%"],
        deprecated: DeprecatedAttrs(unsafe: ["filterRes"]),
        contentGroups: ["descriptive", "filterPrimitive"],
        content: ["animate", "set"]
    ),
    "font": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "externalResourcesRequired", "horiz-adv-x", "horiz-origin-x", "horiz-origin-y", "style", "vert-adv-y", "vert-origin-x", "vert-origin-y"],
        defaults: ["horiz-origin-x": "0", "horiz-origin-y": "0"],
        deprecated: DeprecatedAttrs(unsafe: ["horiz-origin-x", "horiz-origin-y", "vert-adv-y", "vert-origin-x", "vert-origin-y"]),
        contentGroups: ["descriptive"],
        content: ["font-face", "glyph", "hkern", "missing-glyph", "vkern"]
    ),
    "font-face": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["font-family", "font-style", "font-variant", "font-weight", "font-stretch", "font-size", "unicode-range", "units-per-em", "panose-1", "stemv", "stemh", "slope", "cap-height", "x-height", "accent-height", "ascent", "descent", "widths", "bbox", "ideographic", "alphabetic", "mathematical", "hanging", "v-ideographic", "v-alphabetic", "v-mathematical", "v-hanging", "underline-position", "underline-thickness", "strikethrough-position", "strikethrough-thickness", "overline-position", "overline-thickness"],
        defaults: ["font-style": "all", "font-variant": "normal", "font-weight": "all", "font-stretch": "normal", "unicode-range": "U+0-10FFFF", "units-per-em": "1000", "panose-1": "0 0 0 0 0 0 0 0 0 0", "slope": "0"],
        deprecated: DeprecatedAttrs(unsafe: ["accent-height", "alphabetic", "ascent", "bbox", "cap-height", "descent", "hanging", "ideographic", "mathematical", "panose-1", "slope", "stemh", "stemv", "unicode-range", "units-per-em", "v-alphabetic", "v-hanging", "v-ideographic", "v-mathematical", "widths", "x-height"]),
        contentGroups: ["descriptive"],
        content: ["font-face-src"]
    ),
    "font-face-format": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["string"],
        deprecated: DeprecatedAttrs(unsafe: ["string"])
    ),
    "font-face-name": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["name"],
        deprecated: DeprecatedAttrs(unsafe: ["name"])
    ),
    "font-face-src": ElemConfig(
        attrsGroups: ["core"],
        content: ["font-face-name", "font-face-uri"]
    ),
    "font-face-uri": ElemConfig(
        attrsGroups: ["core", "xlink"],
        attrs: ["href", "xlink:href"],
        content: ["font-face-format"]
    ),
    "foreignObject": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "height", "style", "transform", "width", "x", "y"],
        defaults: ["x": "0", "y": "0"]
    ),
    "g": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "style", "transform"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "glyph": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["arabic-form", "class", "d", "glyph-name", "horiz-adv-x", "lang", "orientation", "style", "unicode", "vert-adv-y", "vert-origin-x", "vert-origin-y"],
        defaults: ["arabic-form": "initial"],
        deprecated: DeprecatedAttrs(unsafe: ["arabic-form", "glyph-name", "horiz-adv-x", "orientation", "unicode", "vert-adv-y", "vert-origin-x", "vert-origin-y"]),
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "glyphRef": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "d", "horiz-adv-x", "style", "vert-adv-y", "vert-origin-x", "vert-origin-y"],
        deprecated: DeprecatedAttrs(unsafe: ["horiz-adv-x", "vert-adv-y", "vert-origin-x", "vert-origin-y"]),
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "hatch": ElemConfig(
        attrsGroups: ["core", "presentation", "xlink"],
        attrs: ["class", "hatchContentUnits", "hatchUnits", "pitch", "rotate", "style", "transform", "x", "y"],
        defaults: ["hatchUnits": "objectBoundingBox", "hatchContentUnits": "userSpaceOnUse", "x": "0", "y": "0", "pitch": "0", "rotate": "0"],
        contentGroups: ["animation", "descriptive"],
        content: ["hatchPath"]
    ),
    "hatchPath": ElemConfig(
        attrsGroups: ["core", "presentation", "xlink"],
        attrs: ["class", "style", "d", "offset"],
        defaults: ["offset": "0"],
        contentGroups: ["animation", "descriptive"]
    ),
    "hkern": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["u1", "g1", "u2", "g2", "k"],
        deprecated: DeprecatedAttrs(unsafe: ["g1", "g2", "k", "u1", "u2"])
    ),
    "image": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "height", "href", "preserveAspectRatio", "style", "transform", "width", "x", "xlink:href", "y"],
        defaults: ["x": "0", "y": "0", "preserveAspectRatio": "xMidYMid meet"],
        contentGroups: ["animation", "descriptive"]
    ),
    "line": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "style", "transform", "x1", "x2", "y1", "y2"],
        defaults: ["x1": "0", "y1": "0", "x2": "0", "y2": "0"],
        contentGroups: ["animation", "descriptive"]
    ),
    "linearGradient": ElemConfig(
        attrsGroups: ["core", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "gradientTransform", "gradientUnits", "href", "spreadMethod", "style", "x1", "x2", "xlink:href", "y1", "y2"],
        defaults: ["x1": "0", "y1": "0", "x2": "100%", "y2": "0", "spreadMethod": "pad"],
        contentGroups: ["descriptive"],
        content: ["animate", "animateTransform", "set", "stop"]
    ),
    "marker": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "externalResourcesRequired", "markerHeight", "markerUnits", "markerWidth", "orient", "preserveAspectRatio", "refX", "refY", "style", "viewBox"],
        defaults: ["markerUnits": "strokeWidth", "refX": "0", "refY": "0", "markerWidth": "3", "markerHeight": "3"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "mask": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "presentation"],
        attrs: ["class", "externalResourcesRequired", "height", "mask-type", "maskContentUnits", "maskUnits", "style", "width", "x", "y"],
        defaults: ["maskUnits": "objectBoundingBox", "maskContentUnits": "userSpaceOnUse", "x": "-10%", "y": "-10%", "width": "120%", "height": "120%"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "metadata": ElemConfig(
        attrsGroups: ["core"]
    ),
    "missing-glyph": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "d", "horiz-adv-x", "style", "vert-adv-y", "vert-origin-x", "vert-origin-y"],
        deprecated: DeprecatedAttrs(unsafe: ["horiz-adv-x", "vert-adv-y", "vert-origin-x", "vert-origin-y"]),
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "mpath": ElemConfig(
        attrsGroups: ["core", "xlink"],
        attrs: ["externalResourcesRequired", "href", "xlink:href"],
        contentGroups: ["descriptive"]
    ),
    "path": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "d", "externalResourcesRequired", "pathLength", "style", "transform"],
        contentGroups: ["animation", "descriptive"]
    ),
    "pattern": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "height", "href", "patternContentUnits", "patternTransform", "patternUnits", "preserveAspectRatio", "style", "viewBox", "width", "x", "xlink:href", "y"],
        defaults: ["patternUnits": "objectBoundingBox", "patternContentUnits": "userSpaceOnUse", "x": "0", "y": "0", "width": "0", "height": "0", "preserveAspectRatio": "xMidYMid meet"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "polygon": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "points", "style", "transform"],
        contentGroups: ["animation", "descriptive"]
    ),
    "polyline": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "points", "style", "transform"],
        contentGroups: ["animation", "descriptive"]
    ),
    "radialGradient": ElemConfig(
        attrsGroups: ["core", "presentation", "xlink"],
        attrs: ["class", "cx", "cy", "externalResourcesRequired", "fr", "fx", "fy", "gradientTransform", "gradientUnits", "href", "r", "spreadMethod", "style", "xlink:href"],
        defaults: ["gradientUnits": "objectBoundingBox", "cx": "50%", "cy": "50%", "r": "50%"],
        contentGroups: ["descriptive"],
        content: ["animate", "animateTransform", "set", "stop"]
    ),
    "meshGradient": ElemConfig(
        attrsGroups: ["core", "presentation", "xlink"],
        attrs: ["class", "style", "x", "y", "gradientUnits", "transform"],
        contentGroups: ["descriptive", "paintServer", "animation"],
        content: ["meshRow"]
    ),
    "meshRow": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "style"],
        contentGroups: ["descriptive"],
        content: ["meshPatch"]
    ),
    "meshPatch": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "style"],
        contentGroups: ["descriptive"],
        content: ["stop"]
    ),
    "rect": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "height", "rx", "ry", "style", "transform", "width", "x", "y"],
        defaults: ["x": "0", "y": "0"],
        contentGroups: ["animation", "descriptive"]
    ),
    "script": ElemConfig(
        attrsGroups: ["core", "xlink"],
        attrs: ["externalResourcesRequired", "type", "href", "xlink:href"]
    ),
    "set": ElemConfig(
        attrsGroups: ["animation", "animationAttributeTarget", "animationTiming", "conditionalProcessing", "core", "xlink"],
        attrs: ["externalResourcesRequired", "to"],
        contentGroups: ["descriptive"]
    ),
    "solidColor": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "style"],
        contentGroups: ["paintServer"]
    ),
    "stop": ElemConfig(
        attrsGroups: ["core", "presentation"],
        attrs: ["class", "style", "offset", "path"],
        content: ["animate", "animateColor", "set"]
    ),
    "style": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["type", "media", "title"],
        defaults: ["type": "text/css"]
    ),
    "svg": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "documentEvent", "graphicalEvent", "presentation"],
        attrs: ["baseProfile", "class", "contentScriptType", "contentStyleType", "height", "preserveAspectRatio", "style", "version", "viewBox", "width", "x", "y", "zoomAndPan"],
        defaults: ["x": "0", "y": "0", "width": "100%", "height": "100%", "preserveAspectRatio": "xMidYMid meet", "zoomAndPan": "magnify", "version": "1.1", "baseProfile": "none", "contentScriptType": "application/ecmascript", "contentStyleType": "text/css"],
        deprecated: DeprecatedAttrs(safe: ["version"], unsafe: ["baseProfile", "contentScriptType", "contentStyleType", "zoomAndPan"]),
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "switch": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "style", "transform"],
        contentGroups: ["animation", "descriptive", "shape"],
        content: ["a", "foreignObject", "g", "image", "svg", "switch", "text", "use"]
    ),
    "symbol": ElemConfig(
        attrsGroups: ["core", "graphicalEvent", "presentation"],
        attrs: ["class", "externalResourcesRequired", "preserveAspectRatio", "refX", "refY", "style", "viewBox"],
        defaults: ["refX": "0", "refY": "0"],
        contentGroups: ["animation", "descriptive", "paintServer", "shape", "structural"],
        content: ["a", "altGlyphDef", "clipPath", "color-profile", "cursor", "filter", "font-face", "font", "foreignObject", "image", "marker", "mask", "pattern", "script", "style", "switch", "text", "view"]
    ),
    "text": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "dx", "dy", "externalResourcesRequired", "lengthAdjust", "rotate", "style", "textLength", "transform", "x", "y"],
        defaults: ["x": "0", "y": "0", "lengthAdjust": "spacing"],
        contentGroups: ["animation", "descriptive", "textContentChild"],
        content: ["a"]
    ),
    "textPath": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation", "xlink"],
        attrs: ["class", "d", "externalResourcesRequired", "href", "method", "spacing", "startOffset", "style", "xlink:href"],
        defaults: ["startOffset": "0", "method": "align", "spacing": "exact"],
        contentGroups: ["descriptive"],
        content: ["a", "altGlyph", "animate", "animateColor", "set", "tref", "tspan"]
    ),
    "title": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["class", "style"]
    ),
    "tref": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "href", "style", "xlink:href"],
        contentGroups: ["descriptive"],
        content: ["animate", "animateColor", "set"]
    ),
    "tspan": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation"],
        attrs: ["class", "dx", "dy", "externalResourcesRequired", "lengthAdjust", "rotate", "style", "textLength", "x", "y"],
        contentGroups: ["descriptive"],
        content: ["a", "altGlyph", "animate", "animateColor", "set", "tref", "tspan"]
    ),
    "use": ElemConfig(
        attrsGroups: ["conditionalProcessing", "core", "graphicalEvent", "presentation", "xlink"],
        attrs: ["class", "externalResourcesRequired", "height", "href", "style", "transform", "width", "x", "xlink:href", "y"],
        defaults: ["x": "0", "y": "0"],
        contentGroups: ["animation", "descriptive"]
    ),
    "view": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["externalResourcesRequired", "preserveAspectRatio", "viewBox", "viewTarget", "zoomAndPan"],
        deprecated: DeprecatedAttrs(unsafe: ["viewTarget", "zoomAndPan"]),
        contentGroups: ["descriptive"]
    ),
    "vkern": ElemConfig(
        attrsGroups: ["core"],
        attrs: ["u1", "g1", "u2", "g2", "k"],
        deprecated: DeprecatedAttrs(unsafe: ["g1", "g2", "k", "u1", "u2"])
    ),
]
