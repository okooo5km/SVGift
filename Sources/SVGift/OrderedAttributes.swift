// OrderedAttributes.swift
// Insertion-order-preserving string dictionary for XML attributes
// okooo5km(十里)

/// Sentinel value for attributes that should be serialized without a value
/// (e.g., `data-icon` instead of `data-icon=""`).
public let noValueAttrSentinel = "\u{FFFE}"

/// An ordered dictionary that preserves insertion order of XML attributes.
/// Provides O(1) lookup by key and O(n) ordered iteration.
public struct OrderedAttributes: Sendable {
    /// Storage as ordered key-value pairs
    private var pairs: [(key: String, value: String)] = []

    public init() {}

    public init(_ pairs: [(key: String, value: String)]) {
        for (key, value) in pairs {
            self[key] = value
        }
    }

    /// Initialize from a standard dictionary (sorted by key for determinism)
    public init(_ dict: [String: String]) {
        for key in dict.keys.sorted() {
            pairs.append((key: key, value: dict[key]!))
        }
    }

    /// Number of attributes
    public var count: Int { pairs.count }

    /// Whether the attributes collection is empty
    public var isEmpty: Bool { pairs.isEmpty }

    /// All keys in insertion order
    public var keys: [String] { pairs.map(\.key) }

    /// All values in insertion order
    public var values: [String] { pairs.map(\.value) }

    /// Get or set a value by key. Setting a new key appends it;
    /// setting nil removes it.
    public subscript(key: String) -> String? {
        get {
            pairs.first(where: { $0.key == key })?.value
        }
        set {
            if let newValue = newValue {
                if let index = pairs.firstIndex(where: { $0.key == key }) {
                    pairs[index] = (key: key, value: newValue)
                } else {
                    pairs.append((key: key, value: newValue))
                }
            } else {
                pairs.removeAll { $0.key == key }
            }
        }
    }

    /// Remove a key and return its value
    @discardableResult
    public mutating func removeValue(forKey key: String) -> String? {
        guard let index = pairs.firstIndex(where: { $0.key == key }) else {
            return nil
        }
        return pairs.remove(at: index).value
    }

    /// Remove all attributes
    public mutating func removeAll() {
        pairs.removeAll()
    }

    /// Iterate over key-value pairs in insertion order
    public func forEach(_ body: (String, String) throws -> Void) rethrows {
        for pair in pairs {
            try body(pair.key, pair.value)
        }
    }

    /// Check if a key exists
    public func contains(_ key: String) -> Bool {
        pairs.contains { $0.key == key }
    }
}

extension OrderedAttributes: Sequence {
    public func makeIterator() -> IndexingIterator<[(key: String, value: String)]> {
        pairs.makeIterator()
    }
}

extension OrderedAttributes: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        for (key, value) in elements {
            pairs.append((key: key, value: value))
        }
    }
}
