// OptimizeOptions.swift
// Configuration types for SVG optimization
// okooo5km(十里)

/// Options for SVG stringification (JS2SVG equivalent)
public struct StringifyOptions: Sendable {
    /// Number of spaces for indentation when pretty printing
    public var indent: Int
    /// Whether to format output with indentation and newlines
    public var pretty: Bool
    /// Whether to use short self-closing tags (e.g. <path/>)
    public var useShortTags: Bool
    /// End of line character(s)
    public var eol: EndOfLine
    /// Whether to add a final newline at end of file
    public var finalNewline: Bool

    /// End of line style
    public enum EndOfLine: Sendable {
        case lf
        case crlf

        public var string: String {
            switch self {
            case .lf: return "\n"
            case .crlf: return "\r\n"
            }
        }
    }

    public init(
        indent: Int = 4,
        pretty: Bool = false,
        useShortTags: Bool = true,
        eol: EndOfLine = .lf,
        finalNewline: Bool = false
    ) {
        self.indent = indent
        self.pretty = pretty
        self.useShortTags = useShortTags
        self.eol = eol
        self.finalNewline = finalNewline
    }
}

/// Data URI encoding format
public enum DataURIFormat: Sendable {
    case base64
    case enc
    case unenc
}

/// Configuration for a single plugin
public struct PluginConfig: Sendable {
    /// Plugin name identifier
    public let name: String
    /// Whether the plugin is enabled
    public var enabled: Bool
    /// Plugin-specific parameters
    public var params: [String: String]

    public init(name: String, enabled: Bool = true, params: [String: String] = [:]) {
        self.name = name
        self.enabled = enabled
        self.params = params
    }
}

/// Top-level options for the optimize function
public struct OptimizeOptions {
    /// File path for the SVG (used in plugin info)
    public var path: String?
    /// Whether to run multiple optimization passes
    public var multipass: Bool
    /// Data URI encoding format (if input is a data URI)
    public var dataURI: DataURIFormat?
    /// SVG stringification options
    public var js2svg: StringifyOptions
    /// List of plugins to apply
    public var plugins: [PluginConfig]
    /// Default float precision for plugins (nil means plugin default)
    public var floatPrecision: Int?
    /// Registry of available plugins (name -> resolved plugin)
    public var pluginRegistry: [String: ResolvedPlugin]

    public init(
        path: String? = nil,
        multipass: Bool = false,
        dataURI: DataURIFormat? = nil,
        js2svg: StringifyOptions = .init(),
        plugins: [PluginConfig] = [],
        floatPrecision: Int? = nil,
        pluginRegistry: [String: ResolvedPlugin] = [:]
    ) {
        self.path = path
        self.multipass = multipass
        self.dataURI = dataURI
        self.js2svg = js2svg
        self.plugins = plugins
        self.floatPrecision = floatPrecision
        self.pluginRegistry = pluginRegistry
    }
}

/// Result of an SVG optimization
public struct OptimizeResult: Sendable {
    /// The optimized SVG string
    public let data: String

    public init(data: String) {
        self.data = data
    }
}
