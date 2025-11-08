import Foundation

// MARK: - MIME Validation Error

/// Errors that can occur during MIME validation
public enum MIMEValidationError: Error, CustomStringConvertible, Sendable {
    /// A required header is missing
    case missingRequiredHeader(String)
    /// A header value doesn't match expected format
    case invalidHeaderValue(header: String, expected: String, actual: String?)
    /// Content-Type header is missing or invalid
    case invalidContentType(String)
    /// Multipart message is missing boundary parameter
    case missingBoundary
    /// Multipart message has no parts
    case emptyMultipart
    /// Part index is out of bounds
    case invalidPartIndex(Int)
    /// A part is missing required headers
    case partMissingHeader(partIndex: Int, header: String)
    /// A part has an invalid header value
    case partInvalidHeaderValue(partIndex: Int, header: String, expected: String, actual: String?)
    /// Custom validation error
    case custom(String)

    public var description: String {
        switch self {
        case .missingRequiredHeader(let header):
            return "Missing required header: \(header)"
        case .invalidHeaderValue(let header, let expected, let actual):
            return
                "Invalid header value for '\(header)': expected \(expected), got \(actual ?? "nil")"
        case .invalidContentType(let message):
            return "Invalid Content-Type: \(message)"
        case .missingBoundary:
            return "Multipart message missing boundary parameter in Content-Type"
        case .emptyMultipart:
            return "Multipart message contains no parts"
        case .invalidPartIndex(let index):
            return "Invalid part index: \(index)"
        case .partMissingHeader(let partIndex, let header):
            return "Part \(partIndex) missing required header: \(header)"
        case .partInvalidHeaderValue(let partIndex, let header, let expected, let actual):
            return
                "Part \(partIndex) has invalid header value for '\(header)': expected \(expected), got \(actual ?? "nil")"
        case .custom(let message):
            return message
        }
    }
}

// MARK: - MIME Validation Result

/// The result of a MIME validation operation
public struct MIMEValidationResult: Sendable {
    /// Whether the validation passed
    public let isValid: Bool
    /// List of validation errors (empty if valid)
    public let errors: [MIMEValidationError]
    /// List of validation warnings (non-fatal issues)
    public let warnings: [String]

    public init(isValid: Bool, errors: [MIMEValidationError] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }

    /// Create a successful validation result
    public static func success(warnings: [String] = []) -> MIMEValidationResult {
        MIMEValidationResult(isValid: true, errors: [], warnings: warnings)
    }

    /// Create a failed validation result
    public static func failure(errors: [MIMEValidationError], warnings: [String] = [])
        -> MIMEValidationResult
    {
        MIMEValidationResult(isValid: false, errors: errors, warnings: warnings)
    }

    /// A human-readable summary of the validation result
    public var summary: String {
        if isValid {
            var result = "✓ Validation passed"
            if !warnings.isEmpty {
                result += " with \(warnings.count) warning(s)"
            }
            return result
        } else {
            return "✗ Validation failed with \(errors.count) error(s)"
        }
    }
}

// MARK: - MIME Header Expectation

/// Defines header expectations for a specific content type
public struct MIMEHeaderExpectation: Sendable {
    /// The content type this expectation applies to (e.g., "text/plain")
    public let contentType: String
    /// Headers that must be present (lowercase for comparison)
    public let requiredHeaders: Set<String>
    /// Headers that should be present (warnings if missing, lowercase for comparison)
    public let recommendedHeaders: Set<String>
    /// Expected values for specific headers (case-insensitive keys)
    public let expectedValues: [String: String]
    /// Custom validation function
    public let customValidator: (@Sendable (MIMEHeaders) -> [MIMEValidationError])?
    /// Original case mapping for display (lowercase -> original case)
    private let originalCase: [String: String]

    public init(
        contentType: String,
        requiredHeaders: Set<String> = [],
        recommendedHeaders: Set<String> = [],
        expectedValues: [String: String] = [:],
        customValidator: (@Sendable (MIMEHeaders) -> [MIMEValidationError])? = nil
    ) {
        self.contentType = contentType.lowercased()
        self.requiredHeaders = Set(requiredHeaders.map { $0.lowercased() })
        self.recommendedHeaders = Set(recommendedHeaders.map { $0.lowercased() })
        self.expectedValues = expectedValues.reduce(into: [:]) { result, pair in
            result[pair.key.lowercased()] = pair.value
        }
        self.customValidator = customValidator

        // Build mapping from lowercase to original case
        var caseMap: [String: String] = [:]
        for header in requiredHeaders {
            caseMap[header.lowercased()] = header
        }
        for header in recommendedHeaders {
            caseMap[header.lowercased()] = header
        }
        for key in expectedValues.keys {
            caseMap[key.lowercased()] = key
        }
        self.originalCase = caseMap
    }

    /// Get the original case for a header name (or return lowercase if not found)
    func originalCaseName(_ lowercaseHeader: String) -> String {
        originalCase[lowercaseHeader] ?? lowercaseHeader
    }

    /// Common expectation for text/plain content
    public static let textPlain = MIMEHeaderExpectation(
        contentType: "text/plain",
        recommendedHeaders: ["Content-Type"]
    )

    /// Common expectation for text/html content
    public static let textHtml = MIMEHeaderExpectation(
        contentType: "text/html",
        recommendedHeaders: ["Content-Type"]
    )

    /// Common expectation for application/json content
    public static let applicationJson = MIMEHeaderExpectation(
        contentType: "application/json",
        recommendedHeaders: ["Content-Type"]
    )

    /// Common expectation for multipart/mixed content
    public static let multipartMixed = MIMEHeaderExpectation(
        contentType: "multipart/mixed",
        requiredHeaders: ["Content-Type"]
    )

    /// Common expectation for multipart/alternative content
    public static let multipartAlternative = MIMEHeaderExpectation(
        contentType: "multipart/alternative",
        requiredHeaders: ["Content-Type"]
    )
}

// MARK: - MIME Validator

/// Validates MIME messages according to RFC 2045/2046 and custom rules
public struct MIMEValidator: Sendable {
    /// Header expectations by content type
    private let expectations: [String: MIMEHeaderExpectation]
    /// Whether to validate MIME-Version header is present
    public let requireMimeVersion: Bool
    /// Whether to perform strict multipart validation
    public let strictMultipart: Bool

    public init(
        expectations: [MIMEHeaderExpectation] = [],
        requireMimeVersion: Bool = false,
        strictMultipart: Bool = true
    ) {
        self.expectations = expectations.reduce(into: [:]) { result, expectation in
            result[expectation.contentType] = expectation
        }
        self.requireMimeVersion = requireMimeVersion
        self.strictMultipart = strictMultipart
    }

    /// Create a validator with default expectations for common content types
    public static func withDefaults(
        requireMimeVersion: Bool = false,
        strictMultipart: Bool = true
    ) -> MIMEValidator {
        MIMEValidator(
            expectations: [
                .textPlain,
                .textHtml,
                .applicationJson,
                .multipartMixed,
                .multipartAlternative,
            ],
            requireMimeVersion: requireMimeVersion,
            strictMultipart: strictMultipart
        )
    }

    /// Validate a MIME message
    public func validate(_ message: MIMEMessage) -> MIMEValidationResult {
        var errors: [MIMEValidationError] = []
        var warnings: [String] = []

        // Validate MIME-Version if required
        if requireMimeVersion {
            if message.mimeVersion == nil {
                errors.append(.missingRequiredHeader("MIME-Version"))
            }
        }

        // Validate Content-Type header
        guard let contentType = message.contentType else {
            errors.append(.invalidContentType("Content-Type header is missing"))
            return .failure(errors: errors, warnings: warnings)
        }

        // Extract the main content type (without parameters)
        let mainContentType =
            contentType.components(separatedBy: ";")
            .first?
            .trimmingCharacters(in: .whitespaces)
            .lowercased() ?? ""

        // Check if it's multipart
        let isMultipart = mainContentType.hasPrefix("multipart/")

        if isMultipart {
            // Validate multipart message
            validateMultipart(
                message, contentType: mainContentType, errors: &errors, warnings: &warnings)

            // Apply content-type specific expectations to top-level headers for multipart
            if let expectation = expectations[mainContentType] {
                validateExpectations(
                    expectation,
                    headers: message.headers,
                    errors: &errors,
                    warnings: &warnings
                )
            }
        } else {
            // Validate single-part message
            // For single-part messages, the part validation will cover the headers
            // since the parser creates a part with the same headers as the message
            validateSinglePart(
                message, contentType: mainContentType, errors: &errors, warnings: &warnings)
        }

        return errors.isEmpty
            ? .success(warnings: warnings)
            : .failure(errors: errors, warnings: warnings)
    }

    /// Validate a MIME message from a string
    public func validate(_ content: String) throws -> MIMEValidationResult {
        let message = try MIMEParser.parse(content)
        return validate(message)
    }

    /// Validate a specific part of a message
    public func validatePart(
        _ part: MIMEPart,
        index: Int = 0
    ) -> MIMEValidationResult {
        var errors: [MIMEValidationError] = []
        var warnings: [String] = []

        guard let contentType = part.contentType?.lowercased() else {
            errors.append(.partMissingHeader(partIndex: index, header: "Content-Type"))
            return .failure(errors: errors, warnings: warnings)
        }

        // Apply content-type specific expectations
        if let expectation = expectations[contentType] {
            validatePartExpectations(
                expectation,
                part: part,
                index: index,
                errors: &errors,
                warnings: &warnings
            )
        }

        return errors.isEmpty
            ? .success(warnings: warnings)
            : .failure(errors: errors, warnings: warnings)
    }

    // MARK: - Private Validation Methods

    private func validateMultipart(
        _ message: MIMEMessage,
        contentType: String,
        errors: inout [MIMEValidationError],
        warnings: inout [String]
    ) {
        // Check for boundary
        guard let contentTypeHeader = message.contentType,
            contentTypeHeader.lowercased().contains("boundary=")
        else {
            if strictMultipart {
                errors.append(.missingBoundary)
            } else {
                warnings.append("Multipart message should have boundary parameter")
            }
            return
        }

        // Check parts exist
        if message.parts.isEmpty {
            if strictMultipart {
                errors.append(.emptyMultipart)
            } else {
                warnings.append("Multipart message contains no parts")
            }
            return
        }

        // Validate each part
        for (index, part) in message.parts.enumerated() {
            let partResult = validatePart(part, index: index)
            errors.append(contentsOf: partResult.errors)
            warnings.append(contentsOf: partResult.warnings)
        }
    }

    private func validateSinglePart(
        _ message: MIMEMessage,
        contentType: String,
        errors: inout [MIMEValidationError],
        warnings: inout [String]
    ) {
        // For single-part messages, we expect exactly one part
        if message.parts.count != 1 {
            warnings.append("Single-part message has \(message.parts.count) parts (expected 1)")
        }

        // Validate the part if it exists
        if let part = message.parts.first {
            let partResult = validatePart(part, index: 0)
            errors.append(contentsOf: partResult.errors)
            warnings.append(contentsOf: partResult.warnings)
        }
    }

    private func validateExpectations(
        _ expectation: MIMEHeaderExpectation,
        headers: MIMEHeaders,
        errors: inout [MIMEValidationError],
        warnings: inout [String]
    ) {
        // Check required headers
        for requiredHeader in expectation.requiredHeaders {
            if !headers.contains(requiredHeader) {
                let originalName = expectation.originalCaseName(requiredHeader)
                errors.append(.missingRequiredHeader(originalName))
            }
        }

        // Check recommended headers
        for recommendedHeader in expectation.recommendedHeaders {
            if !headers.contains(recommendedHeader) {
                let originalName = expectation.originalCaseName(recommendedHeader)
                warnings.append("Recommended header '\(originalName)' is missing")
            }
        }

        // Check expected values
        for (header, expectedValue) in expectation.expectedValues {
            let originalName = expectation.originalCaseName(header)
            if let actualValue = headers[header] {
                let normalizedActual = actualValue.trimmingCharacters(in: .whitespaces)
                let normalizedExpected = expectedValue.trimmingCharacters(in: .whitespaces)

                if !normalizedActual.lowercased().contains(normalizedExpected.lowercased()) {
                    errors.append(
                        .invalidHeaderValue(
                            header: originalName,
                            expected: expectedValue,
                            actual: actualValue
                        ))
                }
            } else {
                errors.append(
                    .invalidHeaderValue(
                        header: originalName,
                        expected: expectedValue,
                        actual: nil
                    ))
            }
        }

        // Run custom validator if present
        if let customValidator = expectation.customValidator {
            errors.append(contentsOf: customValidator(headers))
        }
    }

    private func validatePartExpectations(
        _ expectation: MIMEHeaderExpectation,
        part: MIMEPart,
        index: Int,
        errors: inout [MIMEValidationError],
        warnings: inout [String]
    ) {
        // Check required headers
        for requiredHeader in expectation.requiredHeaders {
            if !part.headers.contains(requiredHeader) {
                let originalName = expectation.originalCaseName(requiredHeader)
                errors.append(.partMissingHeader(partIndex: index, header: originalName))
            }
        }

        // Check recommended headers
        for recommendedHeader in expectation.recommendedHeaders {
            if !part.headers.contains(recommendedHeader) {
                let originalName = expectation.originalCaseName(recommendedHeader)
                warnings.append(
                    "Part \(index): Recommended header '\(originalName)' is missing")
            }
        }

        // Check expected values
        for (header, expectedValue) in expectation.expectedValues {
            let originalName = expectation.originalCaseName(header)
            if let actualValue = part.headers[header] {
                let normalizedActual = actualValue.trimmingCharacters(in: .whitespaces)
                let normalizedExpected = expectedValue.trimmingCharacters(in: .whitespaces)

                if !normalizedActual.lowercased().contains(normalizedExpected.lowercased()) {
                    errors.append(
                        .partInvalidHeaderValue(
                            partIndex: index,
                            header: originalName,
                            expected: expectedValue,
                            actual: actualValue
                        ))
                }
            } else {
                errors.append(
                    .partInvalidHeaderValue(
                        partIndex: index,
                        header: originalName,
                        expected: expectedValue,
                        actual: nil
                    ))
            }
        }

        // Run custom validator if present
        if let customValidator = expectation.customValidator {
            let customErrors = customValidator(part.headers)
            errors.append(contentsOf: customErrors)
        }
    }
}

// MARK: - Convenience Extensions

extension MIMEValidationResult: CustomStringConvertible {
    public var description: String {
        var result = summary

        if !errors.isEmpty {
            result += "\n\nErrors:"
            for error in errors {
                result += "\n  • \(error.description)"
            }
        }

        if !warnings.isEmpty {
            result += "\n\nWarnings:"
            for warning in warnings {
                result += "\n  • \(warning)"
            }
        }

        return result
    }
}
