import Foundation

// MARK: - MIME Message

/// Represents a complete MIME message with headers and parts.
///
/// Use `MIMEDecoder().decode(_:)` to create a `MIMEMessage` from a string:
///
/// ```swift
/// let message = try MIMEDecoder().decode(mimeString)
/// print(message.from)
/// for part in message.parts {
///     print(part.contentType)
/// }
/// ```
public struct MIMEMessage: Sendable {
    public var headers: MIMEHeaders
    public var parts: [MIMEPart]

    public init(headers: MIMEHeaders, parts: [MIMEPart]) {
        self.headers = headers
        self.parts = parts
    }

    /// The "Date" header value parsed as a Date
    public var date: Date? {
        guard let dateString = headers["Date"] else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString)
    }

    /// The "MIME-Version" header value
    public var mimeVersion: String? {
        headers["MIME-Version"]
    }

    /// The primary content type value (e.g., "multipart/mixed", "text/plain")
    public var contentType: String? {
        guard let value = headers["Content-Type"] else { return nil }
        let attributes = MIMEHeaderAttributes.parse(value)
        return attributes.value.isEmpty ? nil : attributes.value
    }

    /// All attributes from the Content-Type header.
    ///
    /// Returns a parsed representation of the Content-Type header including
    /// the primary media type and all parameters (like boundary, charset, etc.).
    ///
    /// ```swift
    /// let message = try MIMEDecoder().decode(mimeString)
    /// let attrs = message.contentTypeAttributes
    /// print(attrs.value)         // "multipart/mixed"
    /// print(attrs["boundary"])   // "simple"
    /// print(attrs["charset"])    // "utf-8"
    /// ```
    public var contentTypeAttributes: MIMEHeaderAttributes {
        MIMEHeaderAttributes.parse(headers["Content-Type"])
    }

    /// Parse attributes from any header value.
    ///
    /// Use this to extract attributes from any header that follows the
    /// `value; param=value` format.
    ///
    /// ```swift
    /// let message = try MIMEDecoder().decode(mimeString)
    /// let disposition = message.headerAttributes("Content-Disposition")
    /// print(disposition.value)         // "inline"
    /// print(disposition["filename"])   // "image.png"
    /// ```
    ///
    /// - Parameter headerName: The name of the header to parse
    /// - Returns: Parsed attributes with primary value and parameters
    public func headerAttributes(_ headerName: String) -> MIMEHeaderAttributes {
        MIMEHeaderAttributes.parse(headers[headerName])
    }

    /// The body content for non-multipart messages.
    ///
    /// For non-multipart messages (those without a boundary parameter),
    /// this returns the body content directly. For multipart messages,
    /// this returns nil and you should access individual parts instead.
    ///
    /// ```swift
    /// let message = try MIMEDecoder().decode(simpleMessage)
    /// if let body = message.body {
    ///     print(body)  // Direct access to body content
    /// }
    /// ```
    public var body: String? {
        guard parts.count == 1 else { return nil }
        return parts[0].body
    }

    /// Encodes the MIME message to a string representation.
    ///
    /// For multipart messages, this generates a properly formatted multipart message
    /// with boundaries. For non-multipart messages, it generates a simple message
    /// with headers and body.
    ///
    /// ```swift
    /// var message = try MIMEDecoder().decode(mimeString)
    /// message.headers["From"] = "new@example.com"
    /// let encoded = message.encode()
    /// ```
    ///
    /// - Returns: The MIME message as data
    public func encode() -> Data {
        return MIMEEncoder().encode(self)
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
/// Each part has its own headers and body content. Use the convenience
/// properties to access common header values:
///
/// ```swift
/// let part = message.parts[0]
/// print(part.contentType)  // e.g., "text/plain"
/// print(part.body)          // The actual content
/// print(part.charset)       // e.g., "utf-8"
/// ```
public struct MIMEPart: Sendable, Identifiable {
    public let id: UUID
    public var headers: MIMEHeaders
    public var body: String

    public init(id: UUID = UUID(), headers: MIMEHeaders, body: String) {
        self.id = id
        self.headers = headers
        self.body = body
    }

    /// The "Date" header value parsed as a Date
    public var date: Date? {
        guard let dateString = headers["Date"] else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: dateString)
    }

    /// The content type of this part (e.g., "text/plain", "text/html")
    public var contentType: String? {
        guard let value = headers["Content-Type"] else { return nil }
        let attributes = MIMEHeaderAttributes.parse(value)
        return attributes.value.isEmpty ? nil : attributes.value
    }

    /// The charset specified in the Content-Type header (e.g., "utf-8")
    public var charset: String? {
        contentTypeAttributes["charset"]
    }

    /// All attributes from the Content-Type header.
    ///
    /// Returns a parsed representation of the Content-Type header including
    /// the primary media type and all parameters.
    ///
    /// ```swift
    /// let part = message.parts[0]
    /// let attrs = part.contentTypeAttributes
    /// print(attrs.value)         // "text/plain"
    /// print(attrs["charset"])    // "utf-8"
    /// print(attrs["format"])     // "flowed"
    /// ```
    public var contentTypeAttributes: MIMEHeaderAttributes {
        MIMEHeaderAttributes.parse(headers["Content-Type"])
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

    /// Encodes the MIME part to a string representation.
    ///
    /// This generates the headers and body content for this part.
    ///
    /// ```swift
    /// var part = message.parts[0]
    /// part.body = "New content"
    /// let encoded = part.encode()
    /// ```
    ///
    /// - Returns: The MIME part as data
    public func encode() -> Data {
        return MIMEEncoder().encode(self)
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
public struct MIMEHeaders: Sendable, Equatable {
    private var storage: [(key: String, originalKey: String, value: String)] = []

    public init() {}

    public init(_ dictionary: [String: String]) {
        for (key, value) in dictionary {
            storage.append((key: key.lowercased(), originalKey: key, value: value))
        }
    }

    /// Access header values by name (case-insensitive).
    ///
    /// Getting a value returns the first occurrence. Setting a value replaces
    /// all existing headers with that name. To add multiple headers with the
    /// same name, use `add(_:value:)` instead.
    public subscript(key: String) -> String? {
        get {
            let lowercasedKey = key.lowercased()
            return storage.first(where: { $0.key == lowercasedKey })?.value
        }
        set {
            let lowercasedKey = key.lowercased()
            if let newValue = newValue {
                // Remove all existing headers with this name
                storage.removeAll(where: { $0.key == lowercasedKey })
                // Add the new header
                storage.append((key: lowercasedKey, originalKey: key, value: newValue))
            } else {
                // Remove all headers with this name
                storage.removeAll(where: { $0.key == lowercasedKey })
            }
        }
    }

    public var keys: [String] {
        storage.map { $0.originalKey }
    }

    public var values: [String] {
        storage.map { $0.value }
    }

    public var count: Int {
        storage.count
    }

    public func contains(_ key: String) -> Bool {
        let lowercasedKey = key.lowercased()
        return storage.contains(where: { $0.key == lowercasedKey })
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
        let lowercasedKey = key.lowercased()
        return storage.filter { $0.key == lowercasedKey }.map { $0.value }
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
        let lowercasedKey = key.lowercased()
        storage.append((key: lowercasedKey, originalKey: key, value: value))
    }

    /// Removes all headers with the given name.
    ///
    /// Header names are case-insensitive.
    ///
    /// - Parameter key: The header name to remove
    public mutating func removeAll(_ key: String) {
        let lowercasedKey = key.lowercased()
        storage.removeAll(where: { $0.key == lowercasedKey })
    }

    public static func == (lhs: MIMEHeaders, rhs: MIMEHeaders) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        return zip(lhs.storage, rhs.storage).allSatisfy { lhsElement, rhsElement in
            lhsElement.key == rhsElement.key && lhsElement.originalKey == rhsElement.originalKey
                && lhsElement.value == rhsElement.value
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
            // Multipart message - parse parts
            let parts = try parseParts(bodyContent, boundary: boundary)
            return MIMEMessage(headers: headers, parts: parts)
        } else {
            // Non-multipart message - treat entire body as single part
            let part = MIMEPart(headers: headers, body: bodyContent)
            return MIMEMessage(headers: headers, parts: [part])
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

    /// Parse multipart body into individual parts
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

            let part = MIMEPart(headers: partHeaders, body: partBody)
            parts.append(part)
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

    /// Encode a MIME message to Data.
    ///
    /// - Parameter message: The MIME message to encode
    /// - Returns: The encoded message as Data
    public func encode(_ message: MIMEMessage) -> Data {
        var result = ""

        // Encode headers
        for (key, value) in message.headers {
            result += "\(key): \(value)\n"
        }

        // Extract boundary if present
        if let boundary = extractBoundary(from: message.headers["Content-Type"]) {
            // Multipart message
            result += "\n"

            for part in message.parts {
                result += "--\(boundary)\n"
                result += String(data: encode(part), encoding: .utf8) ?? ""
            }

            result += "--\(boundary)--\n"
        } else {
            // Non-multipart message
            result += "\n"
            if message.parts.count == 1 {
                result += message.parts[0].body
            }
        }

        return result.data(using: .utf8) ?? Data()
    }

    /// Encode a MIME part to Data.
    ///
    /// - Parameter part: The MIME part to encode
    /// - Returns: The encoded part as Data
    public func encode(_ part: MIMEPart) -> Data {
        var result = ""

        // Encode headers
        for (key, value) in part.headers {
            result += "\(key): \(value)\n"
        }

        // Empty line between headers and body
        result += "\n"

        // Body
        result += part.body
        result += "\n"

        return result.data(using: .utf8) ?? Data()
    }

    /// Extract boundary from Content-Type header
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
    /// Find all parts with a specific content type.
    ///
    /// ```swift
    /// let plainParts = message.parts(withContentType: "text/plain")
    /// ```
    ///
    /// - Parameter contentType: The content type to search for (case-insensitive)
    /// - Returns: An array of matching parts
    public func parts(withContentType contentType: String) -> [MIMEPart] {
        parts.filter { part in
            part.contentType?.lowercased() == contentType.lowercased()
        }
    }

    /// Find the first part with a specific content type.
    ///
    /// ```swift
    /// if let htmlPart = message.firstPart(withContentType: "text/html") {
    ///     print(htmlPart.body)
    /// }
    /// ```
    ///
    /// - Parameter contentType: The content type to search for (case-insensitive)
    /// - Returns: The first matching part, or nil if not found
    public func firstPart(withContentType contentType: String) -> MIMEPart? {
        parts.first { part in
            part.contentType?.lowercased() == contentType.lowercased()
        }
    }

    /// Returns true if the message contains any parts with the specified content type.
    ///
    /// - Parameter contentType: The content type to check for (case-insensitive)
    /// - Returns: True if at least one part has the specified content type
    public func hasPart(withContentType contentType: String) -> Bool {
        firstPart(withContentType: contentType) != nil
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
    public typealias Index = Array<(key: String, originalKey: String, value: String)>.Index
    public typealias Element = (key: String, value: String)

    public var startIndex: Index { storage.startIndex }
    public var endIndex: Index { storage.endIndex }

    public subscript(position: Index) -> Element {
        let item = storage[position]
        return (key: item.originalKey, value: item.value)
    }

    public func index(after i: Index) -> Index {
        storage.index(after: i)
    }
}

extension MIMEHeaders: CustomStringConvertible {
    public var description: String {
        storage.map { "\($0.originalKey): \($0.value)" }.joined(separator: "\n")
    }
}
