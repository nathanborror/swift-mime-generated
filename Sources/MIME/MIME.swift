import Foundation

// MARK: - MIME Message

/// Represents a complete MIME message with headers and parts.
///
/// Use `MIMEDecoder().decode(_:)` to create a `MIMEMessage` from a string:
///
/// ```swift
/// let message = try MIMEDecoder().decode(mimeString)
/// for part in message.parts {
///     print(part.headers["Content-Type"])
/// }
/// ```
public struct MIMEMessage: Sendable {
    public var parts: [MIMEPart]

    public init(_ parts: [MIMEPart]) {
        self.parts = parts
    }
}

// MARK: - MIME Header Attributes

/// Represents parsed attributes from a header value.
///
/// Many MIME headers contain a primary value followed by semicolon-separated
/// attributes (e.g., `Content-Type: text/plain; charset=utf-8; format=flowed`).
///
/// ```swift
/// let contentType = headers["Content-Type"]
/// let attributes = MIMEHeaderAttributes.parse(contentType)
/// print(attributes.value)              // "text/plain"
/// print(attributes["charset"])         // "utf-8"
/// print(attributes["format"])          // "flowed"
/// print(attributes.all)                // ["charset": "utf-8", "format": "flowed"]
/// ```
public struct MIMEHeaderAttributes: Sendable, Equatable {
    /// The primary value before any attributes
    public let value: String

    /// Dictionary of all parsed attributes
    public let all: [String: String]

    /// Initialize with a primary value and attributes
    public init(value: String, attributes: [String: String] = [:]) {
        self.value = value
        self.all = attributes
    }

    /// Parse a header value into its primary value and attributes.
    ///
    /// Handles quoted and unquoted attribute values, and normalizes
    /// attribute names to lowercase for case-insensitive access.
    ///
    /// ```swift
    /// let attrs = MIMEHeaderAttributes.parse("text/plain; charset=\"utf-8\"; format=flowed")
    /// print(attrs.value)        // "text/plain"
    /// print(attrs["charset"])   // "utf-8"
    /// print(attrs["format"])    // "flowed"
    /// ```
    ///
    /// - Parameter headerValue: The complete header value to parse
    /// - Returns: Parsed attributes with the primary value and attribute dictionary
    public static func parse(_ headerValue: String?) -> MIMEHeaderAttributes {
        guard let headerValue = headerValue else {
            return MIMEHeaderAttributes(value: "", attributes: [:])
        }

        let components = headerValue.components(separatedBy: ";")
        guard !components.isEmpty else {
            return MIMEHeaderAttributes(value: "", attributes: [:])
        }

        // First component is the primary value
        let primaryValue = components[0].trimmingCharacters(in: .whitespaces)

        // Remaining components are attributes
        var attributes: [String: String] = [:]
        for component in components.dropFirst() {
            let trimmed = component.trimmingCharacters(in: .whitespaces)

            // Split on first '=' only
            guard let equalIndex = trimmed.firstIndex(of: "=") else { continue }

            let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                .lowercased()
            var value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(
                in: .whitespaces)

            // Remove quotes if present
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }

            attributes[key] = value
        }

        return MIMEHeaderAttributes(value: primaryValue, attributes: attributes)
    }

    /// Access an attribute by name (case-insensitive).
    ///
    /// ```swift
    /// let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")
    /// print(attrs["charset"])   // "utf-8"
    /// print(attrs["CHARSET"])   // "utf-8"
    /// ```
    public subscript(key: String) -> String? {
        all[key.lowercased()]
    }
}

// MARK: - MIME Part

/// Represents a single part within a MIME message.
///
/// Each part has its own headers and body content. Parts can be nested to support
/// multipart MIME types within multipart messages (tree structure).
///
/// ```swift
/// let part = message.parts[0]
/// print(part.headers["Content-Type"])  // e.g., "text/plain"
/// print(part.body)          // The actual content
///
/// // For nested multipart
/// if !part.parts.isEmpty {
///     for nestedPart in part.parts {
///         print(nestedPart.body)
///     }
/// }
/// ```
public struct MIMEPart: Sendable, Identifiable {
    public let id: UUID
    public var headers: MIMEHeaders

    /// Nested parts for multipart MIME types. Empty for non-multipart parts.
    public var parts: [MIMEPart]

    /// The body content for non-multipart parts, or empty string for multipart parts with nested parts.
    public var body: String {
        get {
            if !parts.isEmpty {
                return ""
            }
            return _body
        }
        set {
            _body = newValue
        }
    }

    private var _body: String

    public init(id: UUID = UUID(), headers: MIMEHeaders, body: String, parts: [MIMEPart] = []) {
        self.id = id
        self.headers = headers
        self._body = body
        self.parts = parts
    }

    /// Parse attributes from any header value.
    ///
    /// Use this to extract attributes from any header that follows the
    /// `value; param=value` format.
    ///
    /// ```swift
    /// let part = message.parts[0]
    /// let disposition = part.headerAttributes("Content-Disposition")
    /// print(disposition.value)         // "attachment"
    /// print(disposition["filename"])   // "document.pdf"
    /// ```
    ///
    /// - Parameter headerName: The name of the header to parse
    /// - Returns: Parsed attributes with primary value and parameters
    public func headerAttributes(_ headerName: String) -> MIMEHeaderAttributes {
        MIMEHeaderAttributes.parse(headers[headerName])
    }

    /// Returns the body decoded according to the charset specified in headers.
    /// Currently returns the body as-is; future versions may support encoding conversion.
    public var decodedBody: String {
        body
    }

}

// MARK: - MIME Headers

/// Represents MIME headers as a case-insensitive collection.
///
/// Header names are case-insensitive following RFC 2822. The subscript accessor
/// returns the first value when multiple headers with the same name exist, and
/// setting a value replaces all existing headers with that name.
///
/// For headers that can appear multiple times (like `Received`), use `values(for:)`
/// to retrieve all values and `add(_:value:)` to append without replacing.
///
/// ```swift
/// var headers = MIMEHeaders()
/// headers["Content-Type"] = "text/plain"
/// print(headers["content-type"])  // "text/plain"
/// print(headers["CONTENT-TYPE"])  // "text/plain"
///
/// // Working with multiple values
/// headers.add("Received", value: "from server1.example.com")
/// headers.add("Received", value: "from server2.example.com")
/// let allReceived = headers.values(for: "Received")  // Both values
/// ```
/// Represents a single MIME header with its key and value.
///
/// This struct is `Identifiable` for use in SwiftUI `ForEach` loops,
/// allowing headers to be iterated in the order they appear in the message.
///
/// ```swift
/// ForEach(message.headers.ordered) { header in
///     Text("\(header.key): \(header.value)")
/// }
/// ```
public struct MIMEHeader: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var key: String
    public var value: String

    public init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}

public struct MIMEHeaders: Sendable, Equatable {
    public var storage: [MIMEHeader] = []

    public init() {}

    public init(_ dictionary: [String: String]) {
        for (key, value) in dictionary {
            storage.append(.init(key: key, value: value))
        }
    }

    /// Access header values by name (case-insensitive).
    ///
    /// Getting a value returns the first occurrence. Setting a value replaces
    /// all existing headers with that name. To add multiple headers with the
    /// same name, use `add(_:value:)` instead.
    public subscript(key: String) -> String? {
        get {
            storage.first(where: { $0.key == key })?.value
        }
        set {
            guard let newValue else {
                storage.removeAll { $0.key == key }
                return
            }

            // Find the first occurrence (or append if none)
            let firstIndex = storage.firstIndex { $0.key == key }
            if let i = firstIndex {
                storage[i] = .init(key: key, value: newValue)
            } else {
                storage.append(.init(key: key, value: newValue))
                return
            }

            // Remove any later duplicates (iterate backwards to keep indices valid)
            var i = storage.count - 1
            while i > firstIndex! {
                if storage[i].key == key { storage.remove(at: i) }
                i -= 1
            }
        }
    }

    /// Returns all values for the given header key.
    ///
    /// This method is useful when a header can appear multiple times (e.g., `Received` headers).
    /// Header names are case-insensitive.
    ///
    /// ```swift
    /// let received = headers.values(for: "Received")
    /// // Returns all Received header values in order
    /// ```
    ///
    /// - Parameter key: The header name to look up (case-insensitive)
    /// - Returns: An array of all values for the given key, in the order they appear
    public func values(for key: String) -> [String] {
        storage.filter { $0.key == key }.map { $0.value }
    }

    /// Adds a header without replacing existing headers with the same name.
    ///
    /// This method allows multiple headers with the same name to coexist,
    /// which is required by RFC 2822 for headers like `Received`.
    ///
    /// ```swift
    /// headers.add("Received", value: "from server1.example.com")
    /// headers.add("Received", value: "from server2.example.com")
    /// // Both headers are preserved
    /// ```
    ///
    /// - Parameters:
    ///   - key: The header name
    ///   - value: The header value to add
    public mutating func add(_ key: String, value: String) {
        storage.append(.init(key: key, value: value))
    }

    /// Removes all headers with the given name.
    ///
    /// Header names are case-insensitive.
    ///
    /// - Parameter key: The header name to remove
    public mutating func removeAll(_ key: String) {
        storage.removeAll(where: { $0.key == key })
    }

    public static func == (lhs: MIMEHeaders, rhs: MIMEHeaders) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        return zip(lhs.storage, rhs.storage).allSatisfy { lhsElement, rhsElement in
            lhsElement.key == rhsElement.key && lhsElement.value == rhsElement.value
            // Note: We don't compare IDs because headers are equal if their keys and values match
        }
    }
}

// MARK: - MIME Parser

/// Parses MIME messages according to RFC 2045 and RFC 2046.
///
/// Supports both multipart messages (with boundaries) and non-multipart messages
/// (like text/plain, text/html, application/json, etc.).
///
/// Example usage for multipart:
///
/// ```swift
/// let mimeString = """
///     From: sender@example.com
///     Content-Type: multipart/mixed; boundary="boundary"
///
///     --boundary
///     Content-Type: text/plain
///
///     Hello, World!
///     --boundary--
///     """
///
/// let message = try MIMEDecoder().decode(mimeString)
/// print(message.parts.count)  // 1
/// ```
///
/// Example usage for non-multipart:
///
/// ```swift
/// let simpleMessage = """
///     From: sender@example.com
///     Content-Type: text/plain
///
///     Hello, World!
///     """
///
/// let message = try MIMEDecoder().decode(simpleMessage)
/// print(message.parts.count)  // 1
/// print(message.parts[0].body)  // "Hello, World!"
/// ```
public struct MIMEDecoder {

    public init() {}

    /// Decode a MIME message from Data.
    ///
    /// Converts the Data to a UTF-8 string and parses it as a MIME message.
    /// Supports both multipart messages (with boundaries) and non-multipart messages.
    /// Non-multipart messages are treated as a single part containing the entire body.
    ///
    /// - Parameter data: The MIME message content as Data
    /// - Returns: A decoded `MIMEMessage` with headers and parts
    /// - Throws: `MIMEError.invalidUTF8` if the data cannot be decoded as UTF-8, or other parsing errors
    public func decode(_ data: Data) throws -> MIMEMessage {
        guard let content = String(data: data, encoding: .utf8) else {
            throw MIMEError.invalidUTF8
        }

        return try parseString(content)
    }

    /// Decode a MIME message from a string.
    ///
    /// Convenience method that converts the string to UTF-8 data and parses it.
    /// Supports both multipart messages (with boundaries) and non-multipart messages.
    /// Non-multipart messages are treated as a single part containing the entire body.
    ///
    /// - Parameter content: The MIME message content as a string
    /// - Returns: A decoded `MIMEMessage` with headers and parts
    /// - Throws: Decoding errors if the MIME format is invalid
    public func decode(_ content: String) throws -> MIMEMessage {
        guard let data = content.data(using: .utf8) else {
            throw MIMEError.invalidUTF8
        }
        return try decode(data)
    }

    /// Internal method to parse MIME message from a string.
    private func parseString(_ content: String) throws -> MIMEMessage {
        let lines = content.components(separatedBy: .newlines)

        // Parse top-level headers
        var headerLines: [String] = []
        var currentLine = 0

        while currentLine < lines.count {
            let line = lines[currentLine]

            // Empty line marks end of headers
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                currentLine += 1
                break
            }

            headerLines.append(line)
            currentLine += 1
        }

        let headers = parseHeaders(headerLines)

        // Check if headers are present
        if headers.isEmpty {
            throw MIMEError.noHeaders
        }

        // Get remaining content
        let bodyContent = lines[currentLine...].joined(separator: "\n")

        // Extract boundary from Content-Type header
        if let boundary = extractBoundary(from: headers["Content-Type"]) {
            let part = MIMEPart(headers: headers, body: "")

            // Multipart message - parse parts
            let parts = try parseParts(bodyContent, boundary: boundary)
            return MIMEMessage([part] + parts)
        } else {
            // Non-multipart message - treat entire body as single part
            let part = MIMEPart(headers: headers, body: bodyContent)
            return MIMEMessage([part])
        }
    }

    /// Extract boundary from Content-Type header
    private func extractBoundary(from contentType: String?) -> String? {
        let attributes = MIMEHeaderAttributes.parse(contentType)
        return attributes["boundary"]
    }

    /// Parse headers from lines
    private func parseHeaders(_ lines: [String]) -> MIMEHeaders {
        var headers = MIMEHeaders()
        var currentKey: String?
        var currentValue: String = ""

        for line in lines {
            // Check if this is a continuation line (starts with whitespace)
            if line.first?.isWhitespace == true {
                // Continuation of previous header
                currentValue += " " + line.trimmingCharacters(in: .whitespaces)
            } else {
                // Save previous header if exists
                if let key = currentKey {
                    headers.add(key, value: currentValue.trimmingCharacters(in: .whitespaces))
                }

                // Parse new header
                if let colonIndex = line.firstIndex(of: ":") {
                    currentKey = String(line[..<colonIndex])
                    currentValue = String(line[line.index(after: colonIndex)...])
                } else {
                    currentKey = nil
                    currentValue = ""
                }
            }
        }

        // Save last header
        if let key = currentKey {
            headers.add(key, value: currentValue.trimmingCharacters(in: .whitespaces))
        }

        return headers
    }

    /// Parse multipart body into individual parts (recursively handles nested multipart)
    private func parseParts(_ body: String, boundary: String) throws -> [MIMEPart] {
        var parts: [MIMEPart] = []

        let startBoundary = "--" + boundary

        // Split by start boundary
        let sections = body.components(separatedBy: startBoundary)

        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty sections or end boundary markers
            if trimmed.isEmpty || trimmed.hasPrefix("--") {
                continue
            }

            // Parse this part
            let lines = section.components(separatedBy: .newlines)
            var headerLines: [String] = []
            var currentIndex = 0

            // Skip leading empty lines
            while currentIndex < lines.count
                && lines[currentIndex].trimmingCharacters(in: .whitespaces).isEmpty
            {
                currentIndex += 1
            }

            // Collect header lines until we hit an empty line
            while currentIndex < lines.count {
                let line = lines[currentIndex]
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Found the separator between headers and body
                    currentIndex += 1
                    break
                }
                headerLines.append(line)
                currentIndex += 1
            }

            let partHeaders = parseHeaders(headerLines)

            // Get body (everything after the empty line separator)
            var bodyLines: [String] = []
            while currentIndex < lines.count {
                bodyLines.append(lines[currentIndex])
                currentIndex += 1
            }

            // Remove trailing empty lines and boundary markers
            while let last = bodyLines.last {
                let trimmedLast = last.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedLast.isEmpty || trimmedLast.hasPrefix("--") {
                    bodyLines.removeLast()
                } else {
                    break
                }
            }

            let partBody = bodyLines.joined(separator: "\n")

            // Check if this part itself is multipart (nested multipart)
            if let nestedBoundary = extractBoundary(from: partHeaders["Content-Type"]) {
                // Recursively parse nested parts
                let nestedParts = try parseParts(partBody, boundary: nestedBoundary)
                let part = MIMEPart(headers: partHeaders, body: "", parts: nestedParts)
                parts.append(part)
            } else {
                // Regular non-multipart part
                let part = MIMEPart(headers: partHeaders, body: partBody, parts: [])
                parts.append(part)
            }
        }

        return parts
    }
}

// MARK: - MIME Encoder

/// Encodes MIME messages to data.
///
/// The encoder supports both multipart messages (with boundaries) and
/// non-multipart messages.
///
/// Example:
/// ```swift
/// let encoder = MIMEEncoder()
/// let data = encoder.encode(message)
/// ```
public struct MIMEEncoder {

    public init() {}

    public func encode(_ message: MIMEMessage) -> Data {
        guard !message.parts.isEmpty else {
            return Data()
        }

        // If single part (non-multipart), encode it directly
        if message.parts.count == 1 {
            return encode(message.parts[0])
        }

        // Multipart message - first part contains envelope headers
        let envelope = message.parts[0]
        let contentParts = Array(message.parts.dropFirst())

        // Extract boundary from Content-Type
        guard let boundary = extractBoundary(from: envelope.headers["Content-Type"]) else {
            // No boundary found, encode as non-multipart
            return encode(envelope)
        }

        var result = ""

        // Encode envelope headers
        result += encodeHeaders(envelope.headers)
        result += "\n"

        // Encode each part with boundary
        for part in contentParts {
            result += "--\(boundary)\n"
            result += encodePart(part)
        }

        // End boundary
        result += "--\(boundary)--\n"

        return result.data(using: .utf8) ?? Data()
    }

    public func encode(_ part: MIMEPart) -> Data {
        let result = encodePart(part)
        return result.data(using: .utf8) ?? Data()
    }

    private func encodePart(_ part: MIMEPart) -> String {
        var result = ""
        result += encodeHeaders(part.headers)
        result += "\n"

        // Check if this part has nested parts (nested multipart)
        if !part.parts.isEmpty {
            // This is a multipart part with nested parts
            guard let boundary = extractBoundary(from: part.headers["Content-Type"]) else {
                // No boundary found, just use body
                result += part.body
                result += "\n"
                return result
            }

            // Encode nested parts with their own boundary
            for nestedPart in part.parts {
                result += "--\(boundary)\n"
                result += encodePart(nestedPart)
            }

            // End boundary for nested multipart
            result += "--\(boundary)--\n"
        } else {
            // Regular part with body content
            result += part.body
            result += "\n"
        }

        return result
    }

    private func encodeHeaders(_ headers: MIMEHeaders) -> String {
        var result = ""
        for header in headers.storage {
            result += "\(header.key): \(header.value)\n"
        }
        return result
    }

    private func extractBoundary(from contentType: String?) -> String? {
        let attributes = MIMEHeaderAttributes.parse(contentType)
        return attributes["boundary"]
    }
}

// MARK: - MIME Error

/// Errors that can occur during MIME parsing
public enum MIMEError: Error, CustomStringConvertible {
    /// No boundary parameter found in the Content-Type header (deprecated - no longer thrown)
    case noBoundary
    /// The MIME message format is invalid
    case invalidFormat
    /// The character encoding is invalid or unsupported
    case invalidEncoding
    /// The data cannot be decoded as UTF-8
    case invalidUTF8
    /// The MIME message has no headers
    case noHeaders

    public var description: String {
        switch self {
        case .noBoundary:
            return "No boundary found in Content-Type header"
        case .invalidFormat:
            return "Invalid MIME format"
        case .invalidEncoding:
            return "Invalid character encoding"
        case .invalidUTF8:
            return "Data cannot be decoded as UTF-8"
        case .noHeaders:
            return "MIME message has no headers"
        }
    }
}

// MARK: - Convenience Extensions

extension MIMEMessage {
    /// Find all parts with a specific header value.
    /// Searches recursively through nested parts.
    ///
    /// ```swift
    /// let plainParts = message.parts(withHeader: "Content-Type", value: "text/plain")
    /// ```
    ///
    /// - Parameter withHeader: The header name to search for (case-sensitive)
    /// - Parameter value: The header value to search for (case-insensitive)
    /// - Returns: An array of matching parts
    public func parts(withHeader key: String, value: String) -> [MIMEPart] {
        func findRecursive(_ parts: [MIMEPart]) -> [MIMEPart] {
            var result: [MIMEPart] = []
            for part in parts {
                if part.headers[key]?.lowercased().contains(value.lowercased()) == true {
                    result.append(part)
                }
                if !part.parts.isEmpty { // Recursively search nested parts
                    result.append(contentsOf: findRecursive(part.parts))
                }
            }
            return result
        }
        return findRecursive(parts)
    }

    /// Find the first part with a specific header value.
    /// Returns the first part with the specified header value, searching recursively through nested parts.
    ///
    /// ```swift
    /// if let textPart = message.firstPart(withHeader: "Content-Type", value: "text/plain") {
    ///     print(textPart.body)
    /// }
    /// ```
    ///
    /// - Parameter withHeader: The header name to match (case-sensitive)
    /// - Parameter value: The header value to match (case-insensitive)
    /// - Returns: The first matching part, or nil if not found
    public func firstPart(withHeader key: String, value: String) -> MIMEPart? {
        func findRecursive(_ parts: [MIMEPart]) -> MIMEPart? {
            for part in parts {
                if part.headers[key]?.lowercased().contains(value.lowercased()) == true {
                    return part
                }
                if !part.parts.isEmpty { // Recursively search nested parts
                    if let found = findRecursive(part.parts) {
                        return found
                    }
                }
            }
            return nil
        }
        return findRecursive(parts)
    }

    /// Returns true if the message contains any parts with the specified header value.
    ///
    /// - Parameter withHeader: The header name to check for (case-sensitive)
    /// - Parameter value: The header value to check for (case-insensitive)
    /// - Returns: True if at least one part has the specified content type
    public func hasPart(withHeader key: String, value: String) -> Bool {
        firstPart(withHeader: key, value: value) != nil
    }

    /// Find all parts with a specific header attribute value.
    /// Searches recursively through nested parts.
    ///
    /// ```swift
    /// let fooParts = message.parts(withHeader: "Content-Disposition", attribute: "name", value: "foo")
    /// ```
    ///
    /// - Parameter withHeader: The header name to search for (case-sensitive)
    /// - Parameter attribute: The attribute name to search for (case-sensitive)
    /// - Parameter value: The attribute value to match for (case-sensitive)
    /// - Returns: An array of matching parts
    public func parts(withHeader header: String, attribute: String, value: String) -> [MIMEPart] {
        func findRecursive(_ parts: [MIMEPart]) -> [MIMEPart] {
            var result: [MIMEPart] = []
            for part in parts {
                let header = part.headerAttributes(header)
                if header[attribute] == value {
                    result.append(part)
                }
                if !part.parts.isEmpty { // Recursively search nested parts
                    result.append(contentsOf: findRecursive(part.parts))
                }
            }
            return result
        }
        return findRecursive(parts)
    }

    /// Find the first part with a specific header attribute value.
    /// Returns the first part with the specified header attribute value, searching recursively.
    ///
    /// ```swift
    /// if let avatarPart = message.firstPart(withHeader: "Content-Disposition", attribute: "name", value: "foo") {
    ///     print(avatarPart.body)
    /// }
    /// ```
    ///
    /// - Parameter withHeader: The header name to search for (case-sensitive)
    /// - Parameter attribute: The attribute name to search for (case-sensitive)
    /// - Parameter value: The attribute value to match for (case-sensitive)
    /// - Returns: The first matching part, or nil if not found
    public func firstPart(withHeader header: String, attribute: String, value: String) -> MIMEPart? {
        func findRecursive(_ parts: [MIMEPart]) -> MIMEPart? {
            for part in parts {
                let header = part.headerAttributes(header)
                if header[attribute] == value {
                    return part
                }
                if !part.parts.isEmpty { // Recursively search nested parts
                    if let found = findRecursive(part.parts) {
                        return found
                    }
                }
            }
            return nil
        }
        return findRecursive(parts)
    }

    /// Returns true if the message contains any parts with the specified header attribute value.
    ///
    /// - Parameter withHeader: The header name to search for (case-sensitive)
    /// - Parameter attribute: The attribute name to search for (case-sensitive)
    /// - Parameter value: The attribute value to match for (case-sensitive)
    /// - Returns: True if at least one part has the specified content-disposition name
    public func hasPart(withHeader header: String, attribute: String, value: String) -> Bool {
        firstPart(withHeader: header, attribute: attribute, value: value) != nil
    }
}

extension MIMEHeaders: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, String)...) {
        self.init()
        for (key, value) in elements {
            self[key] = value
        }
    }
}

extension MIMEHeaders: Collection {
    public typealias Index = Array<MIMEHeader>.Index
    public typealias Element = MIMEHeader

    public var startIndex: Index { storage.startIndex }
    public var endIndex: Index { storage.endIndex }

    public subscript(position: Index) -> Element {
        let item = storage[position]
        return .init(id: item.id, key: item.key, value: item.value)
    }

    public func index(after i: Index) -> Index {
        storage.index(after: i)
    }
}

extension MIMEHeaders: RandomAccessCollection {}

extension MIMEHeaders: CustomStringConvertible {
    public var description: String {
        storage
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }
}
