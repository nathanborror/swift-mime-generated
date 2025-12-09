import Foundation

// MARK: - MIME Message

/// Represents a complete MIME message with headers and parts.
///
/// Use `MIMEParser.parse(_:)` to create a `MIMEMessage` from a string:
///
/// ```swift
/// let message = try MIMEParser.parse(mimeString)
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

    /// The "Content-Type" header value
    public var contentType: String? {
        headers["Content-Type"]
    }

    /// The body content for non-multipart messages.
    ///
    /// For non-multipart messages (those without a boundary parameter),
    /// this returns the body content directly. For multipart messages,
    /// this returns nil and you should access individual parts instead.
    ///
    /// ```swift
    /// let message = try MIMEParser.parse(simpleMessage)
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
    /// var message = try MIMEParser.parse(mimeString)
    /// message.headers["From"] = "new@example.com"
    /// let encoded = message.encode()
    /// ```
    ///
    /// - Returns: The MIME message as a string
    public func encode() -> String {
        var result = ""

        // Encode headers
        for (key, value) in headers {
            result += "\(key): \(value)\n"
        }

        // Extract boundary if present
        if let boundary = MIMEParser.extractBoundary(from: headers["Content-Type"]) {
            // Multipart message
            result += "\n"

            for part in parts {
                result += "--\(boundary)\n"
                result += part.encode()
            }

            result += "--\(boundary)--\n"
        } else {
            // Non-multipart message
            result += "\n"
            if parts.count == 1 {
                result += parts[0].body
            }
        }

        return result
    }
}

// MARK: - MIME Part

/// Represents a single part of a multipart MIME message.
///
/// Each part contains its own headers and body content:
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
        headers["Content-Type"]?.components(separatedBy: ";").first?.trimmingCharacters(
            in: .whitespaces)
    }

    /// The charset specified in the Content-Type header (e.g., "utf-8")
    public var charset: String? {
        guard let contentType = headers["Content-Type"] else { return nil }
        let components = contentType.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("charset=") {
                var charsetValue = String(trimmed.dropFirst("charset=".count))
                // Remove quotes if present
                if charsetValue.hasPrefix("\"") && charsetValue.hasSuffix("\"") {
                    charsetValue = String(charsetValue.dropFirst().dropLast())
                }
                return charsetValue
            }
        }
        return nil
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
    /// - Returns: The MIME part as a string
    public func encode() -> String {
        var result = ""

        // Encode headers
        for (key, value) in headers {
            result += "\(key): \(value)\n"
        }

        // Empty line between headers and body
        result += "\n"

        // Body
        result += body
        result += "\n"

        return result
    }
}

// MARK: - MIME Headers

/// Represents MIME headers as a case-insensitive dictionary.
///
/// Header names are case-insensitive following RFC 2822:
///
/// ```swift
/// var headers = MIMEHeaders()
/// headers["Content-Type"] = "text/plain"
/// print(headers["content-type"])  // "text/plain"
/// print(headers["CONTENT-TYPE"])  // "text/plain"
/// ```
public struct MIMEHeaders: Sendable, Equatable {
    private var storage: [(key: String, originalKey: String, value: String)] = []

    public init() {}

    public init(_ dictionary: [String: String]) {
        for (key, value) in dictionary {
            storage.append((key: key.lowercased(), originalKey: key, value: value))
        }
    }

    public subscript(key: String) -> String? {
        get {
            let lowercasedKey = key.lowercased()
            return storage.first(where: { $0.key == lowercasedKey })?.value
        }
        set {
            let lowercasedKey = key.lowercased()
            if let newValue = newValue {
                if let index = storage.firstIndex(where: { $0.key == lowercasedKey }) {
                    // Update existing header, preserving original key casing
                    storage[index] = (
                        key: lowercasedKey, originalKey: storage[index].originalKey, value: newValue
                    )
                } else {
                    // Add new header
                    storage.append((key: lowercasedKey, originalKey: key, value: newValue))
                }
            } else {
                // Remove header
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
/// let message = try MIMEParser.parse(mimeString)
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
/// let message = try MIMEParser.parse(simpleMessage)
/// print(message.parts.count)  // 1
/// print(message.parts[0].body)  // "Hello, World!"
/// ```
public enum MIMEParser {

    /// Parse a MIME message from a string.
    ///
    /// Supports both multipart messages (with boundaries) and non-multipart messages.
    /// Non-multipart messages are treated as a single part containing the entire body.
    ///
    /// - Parameter content: The MIME message content as a string
    /// - Returns: A parsed `MIMEMessage` with headers and parts
    public static func parse(_ content: String) throws -> MIMEMessage {
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

    /// Parse a MIME message from Data.
    ///
    /// Converts the Data to a UTF-8 string and parses it as a MIME message.
    /// Supports both multipart messages (with boundaries) and non-multipart messages.
    ///
    /// - Parameter data: The MIME message content as Data
    /// - Returns: A parsed `MIMEMessage` with headers and parts
    /// - Throws: `MIMEError.invalidUTF8` if the data cannot be decoded as UTF-8, or other parsing errors
    public static func parse(_ data: Data) throws -> MIMEMessage {
        guard let content = String(data: data, encoding: .utf8) else {
            throw MIMEError.invalidUTF8
        }
        return try parse(content)
    }

    /// Extract boundary from Content-Type header
    static func extractBoundary(from contentType: String?) -> String? {
        guard let contentType = contentType else { return nil }

        // Look for boundary="value" or boundary=value
        let components = contentType.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("boundary=") {
                var boundaryValue = String(trimmed.dropFirst("boundary=".count))
                // Remove quotes if present
                if boundaryValue.hasPrefix("\"") && boundaryValue.hasSuffix("\"") {
                    boundaryValue = String(boundaryValue.dropFirst().dropLast())
                }
                return boundaryValue
            }
        }

        return nil
    }

    /// Parse headers from lines
    private static func parseHeaders(_ lines: [String]) -> MIMEHeaders {
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
                    headers[key] = currentValue.trimmingCharacters(in: .whitespaces)
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
            headers[key] = currentValue.trimmingCharacters(in: .whitespaces)
        }

        return headers
    }

    /// Parse multipart body into individual parts
    private static func parseParts(_ body: String, boundary: String) throws -> [MIMEPart] {
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
