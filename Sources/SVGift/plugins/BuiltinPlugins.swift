// BuiltinPlugins.swift
// Registry of all built-in SVGO plugins
// okooo5km(十里)

/// Registry of all built-in plugins, keyed by plugin name.
///
/// Use this registry with `OptimizeOptions.pluginRegistry` to make
/// plugins available for resolution during optimization.
nonisolated(unsafe) public let builtinPluginRegistry: [String: ResolvedPlugin] = {
    let plugins: [ResolvedPlugin] = [
        // Wave 0
        makeRemoveDoctypePlugin(),
        makeRemoveXMLProcInstPlugin(),
        makeRemoveCommentsPlugin(),
        makeRemoveMetadataPlugin(),
        makeRemoveTitlePlugin(),
        makeRemoveDescPlugin(),
        makeRemoveXMLNSPlugin(),
        // Wave 1
        makeCleanupAttrsPlugin(),
        makeRemoveEmptyAttrsPlugin(),
        makeRemoveDimensionsPlugin(),
        makeRemoveUnusedNSPlugin(),
        makeSortAttrsPlugin(),
        makeSortDefsChildrenPlugin(),
        // Wave 2
        makeMergeStylesPlugin(),
        makeConvertStyleToAttrsPlugin(),
        makeRemoveAttributesBySelectorPlugin(),
        makeInlineStylesPlugin(),
        makeMinifyStylesPlugin(),
        // Wave 3
        makeConvertEllipseToCirclePlugin(),
        makeConvertColorsPlugin(),
        makeConvertShapeToPathPlugin(),
        makeCleanupNumericValuesPlugin(),
        makeCleanupListOfValuesPlugin(),
        // Wave 4
        makeReusePathsPlugin(),
        makeRemoveHiddenElemsPlugin(),
        makeConvertTransformPlugin(),
        makeRemoveOffCanvasPathsPlugin(),
        makeMergePathsPlugin(),
        makeConvertPathDataPlugin(),
        // Wave 5a - preset-default completions
        makeRemoveEditorsNSDataPlugin(),
        makeRemoveEmptyTextPlugin(),
        makeRemoveUselessDefsPlugin(),
        makeRemoveDeprecatedAttrsPlugin(),
        makeRemoveUselessStrokeAndFillPlugin(),
        makeRemoveEmptyContainersPlugin(),
        makeCollapseGroupsPlugin(),
        // Wave 5b - high-risk preset-default
        makeRemoveUnknownsAndDefaultsPlugin(),
        makeCleanupIdsPlugin(),
        // Wave 6 - non-preset-default
        makeRemoveAttrsPlugin(),
        makeRemoveElementsByAttrPlugin(),
        makeRemoveScriptsPlugin(),
        makeRemoveStyleElementPlugin(),
        makeRemoveRasterImagesPlugin(),
        makeRemoveViewBoxPlugin(),
        makeRemoveXlinkPlugin(),
        makeAddAttributesToSVGElementPlugin(),
        makeAddClassesToSVGElementPlugin(),
        makeConvertOneStopGradientsPlugin(),
        makeRemoveNonInheritableGroupAttrsPlugin(),
        makeCleanupEnableBackgroundPlugin(),
        makeMoveGroupAttrsToElemsPlugin(),
        makeMoveElemsAttrsToGroupPlugin(),
        makePrefixIdsPlugin(),
    ]
    var registry: [String: ResolvedPlugin] = [:]
    for plugin in plugins {
        registry[plugin.name] = plugin
    }
    return registry
}()

/// Default preset containing the standard set of optimization plugins.
///
/// Corresponds to SVGO's `preset-default` plugin list (34 plugins in SVGO execution order).
public let presetDefaultPlugins: [PluginConfig] = [
    PluginConfig(name: "removeDoctype"),
    PluginConfig(name: "removeXMLProcInst"),
    PluginConfig(name: "removeComments"),
    PluginConfig(name: "removeDeprecatedAttrs"),
    PluginConfig(name: "removeMetadata"),
    PluginConfig(name: "removeEditorsNSData"),
    PluginConfig(name: "cleanupAttrs"),
    PluginConfig(name: "mergeStyles"),
    PluginConfig(name: "inlineStyles"),
    PluginConfig(name: "minifyStyles"),
    PluginConfig(name: "cleanupIds"),
    PluginConfig(name: "removeUselessDefs"),
    PluginConfig(name: "cleanupNumericValues"),
    PluginConfig(name: "convertColors"),
    PluginConfig(name: "removeUnknownsAndDefaults"),
    PluginConfig(name: "removeNonInheritableGroupAttrs"),
    PluginConfig(name: "removeUselessStrokeAndFill"),
    PluginConfig(name: "cleanupEnableBackground"),
    PluginConfig(name: "removeHiddenElems"),
    PluginConfig(name: "removeEmptyText"),
    PluginConfig(name: "convertShapeToPath"),
    PluginConfig(name: "convertEllipseToCircle"),
    PluginConfig(name: "moveElemsAttrsToGroup"),
    PluginConfig(name: "moveGroupAttrsToElems"),
    PluginConfig(name: "collapseGroups"),
    PluginConfig(name: "convertPathData"),
    PluginConfig(name: "convertTransform"),
    PluginConfig(name: "removeEmptyAttrs"),
    PluginConfig(name: "removeEmptyContainers"),
    PluginConfig(name: "mergePaths"),
    PluginConfig(name: "removeUnusedNS"),
    PluginConfig(name: "sortAttrs"),
    PluginConfig(name: "sortDefsChildren"),
    PluginConfig(name: "removeDesc"),
]
