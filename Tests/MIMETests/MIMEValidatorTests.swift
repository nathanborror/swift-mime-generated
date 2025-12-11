import Testing

@testable import MIME

@Test func testBasicSinglePartValidation() async throws {
    let mimeString = """
        From: sender@example.com
        Content-Type: text/plain

        Hello, World!
        """

    let validator = MIMEValidator()
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testBasicMultipartValidation() async throws {
    let mimeString = """
        From: sender@example.com
        Content-Type: multipart/mixed; boundary="boundary123"

        --boundary123
        Content-Type: text/plain

        Hello, World!
        --boundary123
        Content-Type: text/html

        <p>Hello, World!</p>
        --boundary123--
        """

    let validator = MIMEValidator()
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testValidationWithRequiredHeaders() async throws {
    let mimeString = """
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: 7bit

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testValidationFailsWithMissingRequiredHeader() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .partMissingHeader(let partIndex, let header) = result.errors[0] {
        #expect(partIndex == 0)
        #expect(header.lowercased() == "content-transfer-encoding")
    } else {
        Issue.record("Expected partMissingHeader error")
    }
}

@Test func testValidationWithRecommendedHeaders() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type"],
        recommendedHeaders: ["Content-Transfer-Encoding"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
    #expect(result.warnings.count == 1)
    #expect(result.warnings[0].contains("Content-Transfer-Encoding"))
}

@Test func testValidationWithExpectedValues() async throws {
    let mimeString = """
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: 7bit

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type"],
        expectedValues: ["Content-Transfer-Encoding": "7bit"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testValidationFailsWithWrongExpectedValue() async throws {
    let mimeString = """
        Content-Type: text/plain
        Content-Transfer-Encoding: base64

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        expectedValues: ["Content-Transfer-Encoding": "7bit"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .partInvalidHeaderValue(let partIndex, let header, let expected, let actual) =
        result.errors[0]
    {
        #expect(partIndex == 0)
        #expect(header.lowercased() == "content-transfer-encoding")
        #expect(expected == "7bit")
        #expect(actual == "base64")
    } else {
        Issue.record("Expected partInvalidHeaderValue error")
    }
}

@Test func testValidationWithCustomValidator() async throws {
    let mimeString = """
        Content-Type: text/plain; charset=utf-8
        X-Custom-Header: required-value

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        customValidator: { headers in
            guard let customHeader = headers["X-Custom-Header"],
                customHeader == "required-value"
            else {
                return [.custom("X-Custom-Header must be 'required-value'")]
            }
            return []
        }
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testValidationFailsWithCustomValidator() async throws {
    let mimeString = """
        Content-Type: text/plain
        X-Custom-Header: wrong-value

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        customValidator: { headers in
            guard let customHeader = headers["X-Custom-Header"],
                customHeader == "required-value"
            else {
                return [.custom("X-Custom-Header must be 'required-value'")]
            }
            return []
        }
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .custom(let message) = result.errors[0] {
        #expect(message.contains("X-Custom-Header"))
    } else {
        Issue.record("Expected custom error")
    }
}

@Test func testValidationRequiresMimeVersion() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let validator = MIMEValidator(requireMimeVersion: true)
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .missingRequiredHeader(let header) = result.errors[0] {
        #expect(header == "MIME-Version")
    } else {
        Issue.record("Expected missingRequiredHeader error")
    }
}

@Test func testValidationWithMimeVersion() async throws {
    let mimeString = """
        MIME-Version: 1.0
        Content-Type: text/plain

        Test content
        """

    let validator = MIMEValidator(requireMimeVersion: true)
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testMultipartMissingBoundaryStrict() async throws {
    let mimeString = """
        Content-Type: multipart/mixed

        Some content
        """

    let validator = MIMEValidator(strictMultipart: true)
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .missingBoundary = result.errors[0] {
        // Expected
    } else {
        Issue.record("Expected missingBoundary error")
    }
}

@Test func testMultipartMissingBoundaryNonStrict() async throws {
    let mimeString = """
        Content-Type: multipart/mixed

        Some content
        """

    let validator = MIMEValidator(strictMultipart: false)
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.warnings.count == 1)
    #expect(result.warnings[0].contains("boundary"))
}

@Test func testMultipartEmptyPartsStrict() async throws {
    let mimeString = """
        Content-Type: multipart/mixed; boundary="boundary123"

        """

    let validator = MIMEValidator(strictMultipart: true)
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(!result.errors.isEmpty)
}

@Test func testValidationWithDefaultExpectations() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let validator = MIMEValidator.withDefaults()
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
}

@Test func testValidationOfIndividualPart() async throws {
    let mimeString = """
        Content-Type: multipart/mixed; boundary="boundary123"

        --boundary123
        Content-Type: text/plain; charset=utf-8
        Content-Transfer-Encoding: 7bit

        Test content
        --boundary123--
        """

    let message = try MIMEDecoder().decode(mimeString)

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = validator.validatePart(message.parts[0], index: 0)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testValidationOfPartWithMissingHeader() async throws {
    let mimeString = """
        Content-Type: multipart/mixed; boundary="boundary123"

        --boundary123
        Content-Type: text/plain

        Test content
        --boundary123--
        """

    let message = try MIMEDecoder().decode(mimeString)

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = validator.validatePart(message.parts[0], index: 0)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .partMissingHeader(let partIndex, let header) = result.errors[0] {
        #expect(partIndex == 0)
        #expect(header.lowercased() == "content-transfer-encoding")
    } else {
        Issue.record("Expected partMissingHeader error")
    }
}

@Test func testMultipartValidationValidatesAllParts() async throws {
    let mimeString = """
        Content-Type: multipart/mixed; boundary="boundary123"

        --boundary123
        Content-Type: text/plain
        Content-Transfer-Encoding: 7bit

        First part
        --boundary123
        Content-Type: text/html

        Second part (missing header)
        --boundary123--
        """

    let textExpectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
    )

    let htmlExpectation = MIMEHeaderExpectation(
        contentType: "text/html",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
    )

    let validator = MIMEValidator(expectations: [textExpectation, htmlExpectation])
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .partMissingHeader(let partIndex, let header) = result.errors[0] {
        #expect(partIndex == 1)
        #expect(header.lowercased() == "content-transfer-encoding")
    } else {
        Issue.record("Expected partMissingHeader error for second part")
    }
}

@Test func testValidationResultDescription() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"],
        recommendedHeaders: ["Content-Disposition"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)

    let description = result.description
    #expect(description.contains("✗"))
    #expect(description.contains("Content-Transfer-Encoding"))
    #expect(description.contains("Content-Disposition"))
}

@Test func testValidationSuccessDescription() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let validator = MIMEValidator()
    let result = try validator.validate(mimeString)

    #expect(result.isValid)

    let description = result.description
    #expect(description.contains("✓"))
    #expect(description.contains("passed"))
}

@Test func testHeaderExpectationCaseInsensitivity() async throws {
    let mimeString = """
        content-type: text/plain
        CONTENT-TRANSFER-ENCODING: 7bit

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "TEXT/PLAIN",
        requiredHeaders: ["Content-Type", "CONTENT-TRANSFER-ENCODING"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testMultipleContentTypeExpectations() async throws {
    let mimeString = """
        Content-Type: multipart/alternative; boundary="boundary123"

        --boundary123
        Content-Type: text/plain; charset=utf-8

        Plain text version
        --boundary123
        Content-Type: text/html; charset=utf-8

        <p>HTML version</p>
        --boundary123--
        """

    let plainExpectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        requiredHeaders: ["Content-Type"]
    )

    let htmlExpectation = MIMEHeaderExpectation(
        contentType: "text/html",
        requiredHeaders: ["Content-Type"]
    )

    let validator = MIMEValidator(expectations: [plainExpectation, htmlExpectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}

@Test func testValidationWithPartInvalidHeaderValue() async throws {
    let mimeString = """
        Content-Type: multipart/mixed; boundary="boundary123"

        --boundary123
        Content-Type: text/plain
        Content-Transfer-Encoding: base64

        Test content
        --boundary123--
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        expectedValues: ["Content-Transfer-Encoding": "7bit"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .partInvalidHeaderValue(let partIndex, let header, let expected, let actual) =
        result.errors[0]
    {
        #expect(partIndex == 0)
        #expect(header.lowercased() == "content-transfer-encoding")
        #expect(expected == "7bit")
        #expect(actual == "base64")
    } else {
        Issue.record("Expected partInvalidHeaderValue error")
    }
}

@Test func testPresetExpectationsTextPlain() async throws {
    let mimeString = """
        Content-Type: text/plain

        Test content
        """

    let validator = MIMEValidator(expectations: [.textPlain])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
}

@Test func testPresetExpectationsTextHtml() async throws {
    let mimeString = """
        Content-Type: text/html

        <p>Test content</p>
        """

    let validator = MIMEValidator(expectations: [.textHtml])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
}

@Test func testPresetExpectationsApplicationJson() async throws {
    let mimeString = """
        Content-Type: application/json

        {"key": "value"}
        """

    let validator = MIMEValidator(expectations: [.applicationJson])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
}

@Test func testPresetExpectationsMultipartMixed() async throws {
    let mimeString = """
        Content-Type: multipart/mixed; boundary="boundary123"

        --boundary123
        Content-Type: text/plain

        Test content
        --boundary123--
        """

    let validator = MIMEValidator(expectations: [.multipartMixed])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
}

@Test func testValidationResultSummary() async throws {
    let successResult = MIMEValidationResult.success()
    #expect(successResult.summary.contains("✓"))
    #expect(successResult.summary.contains("passed"))

    let successWithWarnings = MIMEValidationResult.success(warnings: ["Warning 1", "Warning 2"])
    #expect(successWithWarnings.summary.contains("2 warning"))

    let failureResult = MIMEValidationResult.failure(errors: [.custom("Error")])
    #expect(failureResult.summary.contains("✗"))
    #expect(failureResult.summary.contains("failed"))
    #expect(failureResult.summary.contains("1 error"))
}

@Test func testMissingContentTypeHeader() async throws {
    let mimeString = """
        From: sender@example.com

        Test content
        """

    let validator = MIMEValidator()
    let result = try validator.validate(mimeString)

    #expect(!result.isValid)
    #expect(result.errors.count == 1)

    if case .invalidContentType(let message) = result.errors[0] {
        #expect(message.contains("missing"))
    } else {
        Issue.record("Expected invalidContentType error")
    }
}

@Test func testExpectedValueContainsCheck() async throws {
    let mimeString = """
        Content-Type: text/plain; charset=utf-8; format=flowed

        Test content
        """

    let expectation = MIMEHeaderExpectation(
        contentType: "text/plain",
        expectedValues: ["Content-Type": "charset=utf-8"]
    )

    let validator = MIMEValidator(expectations: [expectation])
    let result = try validator.validate(mimeString)

    #expect(result.isValid)
    #expect(result.errors.isEmpty)
}
