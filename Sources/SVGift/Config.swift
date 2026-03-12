// Config.swift
// JSON configuration file loading for svgo-swift
// okooo5km(十里)

import Foundation

/// Load optimization options from a JSON config file.
///
/// The config format mirrors SVGO's JSON config:
/// ```json
/// {
///   "multipass": true,
///   "floatPrecision": 3,
///   "js2svg": { "pretty": true, "indent": 2 },
///   "plugins": [
///     "removeDoctype",
///     { "name": "removeComments", "params": { "preservePatterns": "false" } },
///     { "name": "sortAttrs", "enabled": false }
///   ]
/// }
/// ```
///
/// Plugins can be specified as strings, objects, or a mix of both.
/// If no `plugins` key is provided, `presetDefaultPlugins` is used.
public func loadConfig(at path: String) throws -> OptimizeOptions {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw SVGOError.invalidInput("Config file is not a valid JSON object: \(path)")
    }

    var options = OptimizeOptions()
    options.pluginRegistry = builtinPluginRegistry

    // multipass
    if let multipass = json["multipass"] as? Bool {
        options.multipass = multipass
    }

    // floatPrecision
    if let fp = json["floatPrecision"] as? Int {
        options.floatPrecision = fp
    }

    // js2svg
    if let js2svg = json["js2svg"] as? [String: Any] {
        if let pretty = js2svg["pretty"] as? Bool {
            options.js2svg.pretty = pretty
        }
        if let indent = js2svg["indent"] as? Int {
            options.js2svg.indent = indent
        }
        if let useShortTags = js2svg["useShortTags"] as? Bool {
            options.js2svg.useShortTags = useShortTags
        }
        if let finalNewline = js2svg["finalNewline"] as? Bool {
            options.js2svg.finalNewline = finalNewline
        }
        if let eol = js2svg["eol"] as? String {
            switch eol {
            case "crlf": options.js2svg.eol = .crlf
            default: options.js2svg.eol = .lf
            }
        }
    }

    // plugins — supports both string array and object array formats:
    //   ["removeDoctype", "removeComments"]
    //   [{ "name": "removeComments", "params": { ... } }]
    //   mixed: ["removeDoctype", { "name": "removeComments", "params": { ... } }]
    if let pluginsRaw = json["plugins"] as? [Any] {
        var configs: [PluginConfig] = []
        for item in pluginsRaw {
            if let name = item as? String {
                // String shorthand: just a plugin name with defaults
                configs.append(PluginConfig(name: name))
            } else if let pluginObj = item as? [String: Any],
                      let name = pluginObj["name"] as? String {
                // Object format: { "name": "...", "enabled": ..., "params": { ... } }
                let enabled = pluginObj["enabled"] as? Bool ?? true
                var params: [String: String] = [:]
                if let paramsObj = pluginObj["params"] as? [String: Any] {
                    for (key, value) in paramsObj {
                        if let boolVal = value as? Bool {
                            params[key] = boolVal ? "true" : "false"
                        } else if let strVal = value as? String {
                            params[key] = strVal
                        } else if let numVal = value as? NSNumber {
                            params[key] = numVal.stringValue
                        } else if let subData = try? JSONSerialization.data(withJSONObject: value),
                                  let subStr = String(data: subData, encoding: .utf8) {
                            params[key] = subStr
                        }
                    }
                }
                configs.append(PluginConfig(name: name, enabled: enabled, params: params))
            }
        }
        options.plugins = configs
    } else {
        // Default to preset-default if no plugins specified
        options.plugins = presetDefaultPlugins
    }

    return options
}
