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
    public let headers: MIMEHeaders
    public let parts: [MIMEPart]

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
    public let headers: MIMEHeaders
    public let body: String

    public init(id: UUID = UUID(), headers: MIMEHeaders, body: String) {
        self.id = id
        self.headers = headers
        self.body = body
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
public struct MIMEHeaders: Sendable {
    private var storage: [String: String] = [:]

    public init() {}

    public init(_ dictionary: [String: String]) {
        for (key, value) in dictionary {
            storage[key.lowercased()] = value
        }
    }

    public subscript(key: String) -> String? {
        get { storage[key.lowercased()] }
        set { storage[key.lowercased()] = newValue }
    }

    public var keys: Dictionary<String, String>.Keys {
        storage.keys
    }

    public var values: Dictionary<String, String>.Values {
        storage.values
    }

    public var count: Int {
        storage.count
    }

    public func contains(_ key: String) -> Bool {
        storage[key.lowercased()] != nil
    }
}

// MARK: - MIME Parser

/// Parses MIME multipart messages according to RFC 2045 and RFC 2046.
///
/// Example usage:
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
/// print(message.from)  // "sender@example.com"
/// print(message.parts.count)  // 1
/// ```
public enum MIMEParser {

    /// Parse a MIME multipart message from a string.
    ///
    /// - Parameter content: The MIME message content as a string
    /// - Returns: A parsed `MIMEMessage` with headers and parts
    /// - Throws: `MIMEError.noBoundary` if no boundary is found in Content-Type header
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

        // Extract boundary from Content-Type header
        guard let boundary = extractBoundary(from: headers["Content-Type"]) else {
            throw MIMEError.noBoundary
        }

        // Get remaining content
        let bodyContent = lines[currentLine...].joined(separator: "\n")

        // Parse parts
        let parts = try parseParts(bodyContent, boundary: boundary)

        return MIMEMessage(headers: headers, parts: parts)
    }

    /// Extract boundary from Content-Type header
    private static func extractBoundary(from contentType: String?) -> String? {
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
    /// No boundary parameter found in the Content-Type header
    case noBoundary
    /// The MIME message format is invalid
    case invalidFormat
    /// The character encoding is invalid or unsupported
    case invalidEncoding

    public var description: String {
        switch self {
        case .noBoundary:
            return "No boundary found in Content-Type header"
        case .invalidFormat:
            return "Invalid MIME format"
        case .invalidEncoding:
            return "Invalid character encoding"
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
    public typealias Index = Dictionary<String, String>.Index
    public typealias Element = Dictionary<String, String>.Element

    public var startIndex: Index { storage.startIndex }
    public var endIndex: Index { storage.endIndex }

    public subscript(position: Index) -> Element {
        storage[position]
    }

    public func index(after i: Index) -> Index {
        storage.index(after: i)
    }
}

extension MIMEHeaders: CustomStringConvertible {
    public var description: String {
        storage.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}
