import Foundation
import Testing

@testable import MIME

@Test("Attributes decoding")
func attributeDecoding() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs.all.count == 1)
}

@Test("Attributes with quoted values")
func attributeWithQuotedValues() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=\"utf-8\"")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
}

@Test("Attributes with multiple")
func attributesMultipleParameters() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8; format=flowed; delsp=yes")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["format"] == "flowed")
    #expect(attrs["delsp"] == "yes")
    #expect(attrs.all.count == 3)
}

@Test("Attributes case insensitivity")
func attributesCaseInsensitivity() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")

    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["CHARSET"] == "utf-8")
    #expect(attrs["Charset"] == "utf-8")
}

@Test("Attributes missing")
func attributesMissing() async throws {
    var attrs = MIMEHeaderAttributes.parse(nil)
    #expect(attrs.value == "")
    #expect(attrs.all.isEmpty)

    attrs = MIMEHeaderAttributes.parse("text/plain")
    #expect(attrs.value == "text/plain")
    #expect(attrs.all.isEmpty)
}

@Test("Attributes with whitespace")
func attributesWithWhitespace() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain;  charset = \"utf-8\" ;  format = flowed ")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["format"] == "flowed")
}

@Test("Attributes multipart/mixed")
func attributesMultipart() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain; charset=utf-8; format=flowed

        Plain text
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts[0].headerAttributes("Content-Type").value == "multipart/mixed")
    #expect(message.parts[0].headerAttributes("Content-Type")["boundary"] == "test")
    #expect(message.parts[1].headerAttributes("Content-Type").value == "text/plain")
    #expect(message.parts[1].headerAttributes("Content-Type")["charset"] == "utf-8")
    #expect(message.parts[1].headerAttributes("Content-Type")["format"] == "flowed")
}

@Test("Attributes with special characters")
func attributesWithSpecialCharacters() async throws {
    let attrs = MIMEHeaderAttributes.parse(
        "application/octet-stream; filename=\"file-name_2024.txt\""
    )

    #expect(attrs.value == "application/octet-stream")
    #expect(attrs["filename"] == "file-name_2024.txt")
}

@Test("Attributes equality")
func attributesEquality() async throws {
    let attrs1 = MIMEHeaderAttributes(value: "text/plain", attributes: ["charset": "utf-8"])
    let attrs2 = MIMEHeaderAttributes(value: "text/plain", attributes: ["charset": "utf-8"])
    let attrs3 = MIMEHeaderAttributes(value: "text/html", attributes: ["charset": "utf-8"])

    #expect(attrs1 == attrs2)
    #expect(attrs1 != attrs3)
}

@Test("Attributes with empty parameter")
func attributesWithEmptyParameter() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "")
}

@Test("Attributes non-existent parameter")
func attributesNonExistentParameter() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")

    #expect(attrs["nonexistent"] == nil)
}

@Test("Content-Disposition name filtering")
func contentDispositionName() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: inline; name="foo"

        This is foo
        --test-boundary
        Content-Type: text/html
        Content-Disposition: inline; name="bar"

        This is bar
        --test-boundary
        Content-Type: application/json
        Content-Disposition: attachment; name="foo"

        This is another foo
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let fooParts = message.parts(withContentDispositionName: "foo")
    #expect(fooParts.count == 2)
    #expect(fooParts[0].body.trimmingCharacters(in: .whitespacesAndNewlines) == "This is foo")
    #expect(fooParts[1].body.trimmingCharacters(in: .whitespacesAndNewlines) == "This is another foo")

    let barParts = message.parts(withContentDispositionName: "bar")
    #expect(barParts.count == 1)
    #expect(barParts[0].body.trimmingCharacters(in: .whitespacesAndNewlines) == "This is bar")

    let bazParts = message.parts(withContentDispositionName: "baz")
    #expect(bazParts.count == 0)
}

@Test("Content-Disposition name case sensitivity")
func contentDispositionNameCaseSensitive() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: inline; name="MyFile"

        Content here
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Names should be case-sensitive
    #expect(message.firstPart(withContentDispositionName: "MyFile") != nil)
    #expect(message.firstPart(withContentDispositionName: "myfile") == nil)
    #expect(message.firstPart(withContentDispositionName: "MYFILE") == nil)
}

@Test("Content-Disposition filename and name")
func contentDispositionWithFilenameAndName() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: attachment; filename="file.txt"; name="textfile"

        Text content
        --test-boundary
        Content-Type: image/png
        Content-Disposition: inline; filename="photo.png"

        Image without name
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let textPart = message.firstPart(withContentDispositionName: "textfile")
    #expect(textPart != nil)
    #expect(textPart?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "Text content")

    // Part without name attribute should not match
    let imagePart = message.firstPart(withContentDispositionName: "photo.png")
    #expect(imagePart == nil)
}
