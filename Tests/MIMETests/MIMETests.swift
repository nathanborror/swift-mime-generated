import Foundation
import Testing

@testable import MIME

// MARK: Decoding

@Test("Decoding text/plain")
func decodingTextPlain() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Subject: Simple Text Message
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        Content-Type: text/plain; charset="utf-8"

        This is a simple text message without multipart.
        It should be treated as a single part.
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headerAttributes("Content-Type").value == "text/plain")
    #expect(message.parts[0].headerAttributes("Content-Type")["charset"] == "utf-8")
    #expect(message.parts[0].body.contains("This is a simple text message"))
}

@Test("Decoding text/html")
func decodingTextHTML() async throws {
    let mimeContent = """
        From: sender@example.com
        Content-Type: text/html

        <html>
        <body>
        <h1>Hello World</h1>
        <p>This is an HTML message.</p>
        </body>
        </html>
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headers["Content-Type"] == "text/html")
    #expect(message.parts[0].body.contains("<h1>Hello World</h1>"))
    #expect(message.parts[0].body.contains("<p>This is an HTML message.</p>"))
}

@Test("Decoding application/json")
func decodingApplicationJSON() async throws {
    let mimeContent = """
        From: api@example.com
        Content-Type: application/json

        {
            "name": "John Doe",
            "email": "john@example.com",
            "active": true
        }
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headers["Content-Type"] == "application/json")
    #expect(message.parts[0].body.contains("\"name\": \"John Doe\""))
    #expect(message.parts[0].body.contains("\"active\": true"))
}

@Test("Decoding missing content-type")
func decodingMissingContentType() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Subject: Message without Content-Type

        This message has no Content-Type header.
        It should still parse as a single part.
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headers["Content-Type"] == nil)
    #expect(message.parts[0].body.contains("This message has no Content-Type header"))
}

@Test("Decoding round-trip")
func decodingRoundTrip() async throws {
    let original = """
        From: original@example.com
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Original content
        --test--
        """

    // Parse
    var message = try MIMEDecoder().decode(original)
    #expect(message.parts[0].headers[0].key == "From")

    // Edit
    message.parts[0].headers["From"] = "updated@example.com"
    message.parts[1].body = "Updated content"

    // Encode
    let encoded = MIMEEncoder().encode(message)

    // Parse again
    let reparsed = try MIMEDecoder().decode(encoded)

    // Verify
    #expect(reparsed.parts[0].headers["From"] == "updated@example.com")
    #expect(reparsed.parts[0].headers[0].key == "From")
    #expect(reparsed.parts[0].headers[1].key == "Content-Type")
    #expect(reparsed.parts[1].body == "Updated content")
}

@Test("Decoding data")
func decodingData() async throws {
    let mimeContent = """
        From: Test User <test@example.com>
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Hello from Data!
        --test
        Content-Type: text/html

        <p>HTML from Data</p>
        --test--
        """

    guard let data = mimeContent.data(using: .utf8) else {
        Issue.record("Failed to create test data")
        return
    }

    let message = try MIMEDecoder().decode(data)

    #expect(message.parts[0].headers["From"] == "Test User <test@example.com>")
    #expect(message.parts.count == 3)
    #expect(message.parts[1].body == "Hello from Data!")
    #expect(message.parts[2].body == "<p>HTML from Data</p>")
}

@Test("Decoding invalid UTF-8")
func decodingInvalidUTF8Data() async throws {
    // Create invalid UTF-8 data
    let invalidData = Data([0xFF, 0xFE, 0xFD])

    #expect(throws: MIMEError.invalidUTF8) {
        try MIMEDecoder().decode(invalidData)
    }
}

@Test("Decoding empty headers")
func decodingEmptyHeaders() async throws {
    let mimeContent = """

        This is just body content with no headers.
        """

    #expect(throws: MIMEError.noHeaders) {
        try MIMEDecoder().decode(mimeContent)
    }
}

@Test("Decoding empty content")
func decodingEmptyContent() async throws {
    let mimeContent = ""

    #expect(throws: MIMEError.noHeaders) {
        try MIMEDecoder().decode(mimeContent)
    }
}

// MARK: Encoding

@Test("Encoding text/plain")
func encodingTextPlain() async throws {
    let mimeContent = """
        From: sender@example.com
        Content-Type: text/plain

        Hello, World!
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let encoded = MIMEEncoder().encode(message)
    let encodedString = String(data: encoded, encoding: .utf8) ?? ""

    #expect(encodedString.contains("From: sender@example.com"))
    #expect(encodedString.contains("Content-Type: text/plain"))
    #expect(encodedString.contains("Hello, World!"))
}

@Test("Encoding multipart/mixed")
func encodingMultipart() async throws {
    let mimeContent = """
        From: sender@example.com
        Content-Type: multipart/mixed; boundary="simple"

        --simple
        Content-Type: text/plain

        Hello, World!
        --simple
        Content-Type: text/html

        <h1>Hello</h1>
        --simple--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let encoded = MIMEEncoder().encode(message)
    let encodedString = String(data: encoded, encoding: .utf8) ?? ""

    #expect(encodedString.contains("From: sender@example.com"))
    #expect(encodedString.contains("Content-Type: multipart/mixed; boundary=\"simple\""))
    #expect(encodedString.contains("--simple"))
    #expect(encodedString.contains("text/plain"))
    #expect(encodedString.contains("Hello, World!"))
    #expect(encodedString.contains("text/html"))
    #expect(encodedString.contains("<h1>Hello</h1>"))
    #expect(encodedString.contains("--simple--"))
}

@Test("Encoding part")
func encodingPart() async throws {
    var headers = MIMEHeaders()
    headers["Content-Type"] = "text/plain"
    headers["X-Custom"] = "value"

    let part = MIMEPart(headers: headers, body: "Test content")
    let encoded = MIMEEncoder().encode(part)
    let encodedString = String(data: encoded, encoding: .utf8) ?? ""

    #expect(encodedString.contains("Content-Type: text/plain"))
    #expect(encodedString.contains("X-Custom: value"))
    #expect(encodedString.contains("Test content"))
}

// MARK: Parts

@Test("Part body editing")
func partBodyEditing() async throws {
    let mimeContent = """
        Content-Type: text/plain

        Original content
        """

    var message = try MIMEDecoder().decode(mimeContent)

    // Edit body
    message.parts[0].body = "Updated content"
    #expect(message.parts[0].body == "Updated content")
}

@Test("Part header editing")
func partHeaderEditing() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Part 1
        --test--
        """

    var message = try MIMEDecoder().decode(mimeContent)

    // Edit part headers
    message.parts[0].headers["Content-Type"] = "text/html"
    message.parts[0].headers["X-Custom"] = "value"

    #expect(message.parts[0].headers["Content-Type"] == "text/html")
    #expect(message.parts[0].headers["X-Custom"] == "value")
}

@Test("Parts adding and removing")
func partsAddingAndRemoving() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Part 1
        --test--
        """

    var message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 2)

    // Add a new part
    var newHeaders = MIMEHeaders()
    newHeaders["Content-Type"] = "text/html"
    let newPart = MIMEPart(headers: newHeaders, body: "<p>New part</p>")
    message.parts.append(newPart)

    #expect(message.parts.count == 3)
    #expect(message.parts[2].body == "<p>New part</p>")

    // Remove a part
    message.parts.remove(at: 0)

    #expect(message.parts.count == 2)
    #expect(message.parts[1].body == "<p>New part</p>")
}

// MARK: Multipart

@Test("Multipart decoding")
func multipartDecoding() async throws {
    let content = """
        From: Test User <test@example.com>
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="simple"

        --simple
        Content-Type: text/plain

        Hello, World!
        --simple
        Content-Type: text/html

        <h1>Hello, World!</h1>
        --simple--
        """

    let message = try MIMEDecoder().decode(content)

    #expect(message.parts.count == 3)
    #expect(message.parts[0].headers["From"] == "Test User <test@example.com>")
    #expect(message.parts[0].headers["MIME-Version"] == "1.0")

    #expect(message.parts[1].headers["Content-Type"] == "text/plain")
    #expect(message.parts[1].body == "Hello, World!")

    #expect(message.parts[2].headers["Content-Type"] == "text/html")
    #expect(message.parts[2].body == "<h1>Hello, World!</h1>")
}

@Test("Multipart with multiple boundaries")
func multipartMultipleBoundaries() async throws {
    let content = """
        From: Test User <test@example.com>
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="outer-boundary"

        --outer-boundary
        Content-Type: multipart/alternative; boundary="alternative-boundary"

        --alternative-boundary
        Content-Type: text/plain; charset="utf-8"

        Hello, World!

        This is the plain text version of the email.

        --alternative-boundary
        Content-Type: multipart/related; boundary="related-boundary"

        --related-boundary
        Content-Type: text/html; charset="utf-8"

        <h1>Hello, World!</h1>
        <p>This is the HTML version with an image:</p>
        <img src="cid:image001" alt="Logo">

        --related-boundary
        Content-Type: image/png; name="logo.png"
        Content-Transfer-Encoding: base64
        Content-ID: <image001>

        iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==

        --related-boundary--

        --alternative-boundary--

        --outer-boundary
        Content-Type: application/pdf; name="document.pdf"
        Content-Transfer-Encoding: base64
        Content-Disposition: attachment; filename="document.pdf"

        JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2cvUGFnZXMgMiAwIFI+PgplbmRvYmoKMiAwIG9iago8PC9UeXBlL1BhZ2VzL0tpZHNbMyAwIFJdL0NvdW50IDE+PgplbmRvYmoKMyAwIG9iago8PC9UeXBlL1BhZ2UvUGFyZW50IDIgMCBSPj4KZW5kb2JqCnhyZWYKMCA0CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAxNSAwMDAwMCBuIAowMDAwMDAwMDYwIDAwMDAwIG4gCjAwMDAwMDAxMDkgMDAwMDAgbiAKdHJhaWxlcgo8PC9TaXplIDQvUm9vdCAxIDAgUj4+CnN0YXJ0eHJlZgoxNTMKJSVFT0Y=

        --outer-boundary--
        """

    let message = try MIMEDecoder().decode(content)

    // Verify top-level structure
    #expect(message.parts.count == 3)  // envelope + 2 parts (multipart/alternative + pdf)

    // First part is the envelope with headers
    let envelope = message.parts[0]
    #expect(envelope.headers["From"] == "Test User <test@example.com>")
    #expect(envelope.headers["Content-Type"]?.contains("multipart/mixed") == true)

    // Second part should be multipart/alternative with nested parts
    let alternativePart = message.parts[1]
    #expect(alternativePart.headers["Content-Type"]?.contains("multipart/alternative") == true)
    #expect(alternativePart.parts.count == 2)  // text/plain + multipart/related

    // Verify nested text/plain part
    let plainPart = alternativePart.parts[0]
    #expect(plainPart.headers["Content-Type"]?.contains("text/plain") == true)
    #expect(plainPart.body.contains("Hello, World!"))
    #expect(plainPart.body.contains("plain text version"))
    #expect(plainPart.parts.isEmpty)  // No nested parts

    // Verify nested multipart/related part
    let relatedPart = alternativePart.parts[1]
    #expect(relatedPart.headers["Content-Type"]?.contains("multipart/related") == true)
    #expect(relatedPart.parts.count == 2)  // text/html + image/png

    // Verify deeply nested HTML part
    let htmlPart = relatedPart.parts[0]
    #expect(htmlPart.headers["Content-Type"]?.contains("text/html") == true)
    #expect(htmlPart.body.contains("<h1>Hello, World!</h1>"))
    #expect(htmlPart.body.contains("<img src=\"cid:image001\""))
    #expect(htmlPart.parts.isEmpty)  // No nested parts

    // Verify deeply nested image part
    let imagePart = relatedPart.parts[1]
    #expect(imagePart.headers["Content-Type"]?.contains("image/png") == true)
    #expect(imagePart.headers["Content-ID"] == "<image001>")
    #expect(imagePart.body.contains("iVBORw0KGgo"))
    #expect(imagePart.parts.isEmpty)  // No nested parts

    // Verify PDF attachment at top level
    let pdfPart = message.parts[2]
    #expect(pdfPart.headers["Content-Type"]?.contains("application/pdf") == true)
    #expect(pdfPart.headers["Content-Disposition"]?.contains("attachment") == true)
    #expect(pdfPart.body.contains("JVBERi0"))
    #expect(pdfPart.parts.isEmpty)  // No nested parts

    // Test recursive search functions
    let allPlainParts = message.parts(withHeader: "Content-Type", value: "text/plain")
    #expect(allPlainParts.count == 1)
    #expect(allPlainParts[0].body.contains("plain text version"))

    let allHtmlParts = message.parts(withHeader: "Content-Type", value: "text/html")
    #expect(allHtmlParts.count == 1)
    #expect(allHtmlParts[0].body.contains("<h1>Hello, World!</h1>"))

    // Test firstPart recursive search
    if let foundPlainPart = message.firstPart(withHeader: "Content-Type", value: "text/plain") {
        #expect(foundPlainPart.body.contains("plain text version"))
    } else {
        Issue.record("Should find text/plain part")
    }

    if let foundHtmlPart = message.firstPart(withHeader: "Content-Type", value: "text/html") {
        #expect(foundHtmlPart.body.contains("<h1>Hello, World!</h1>"))
    } else {
        Issue.record("Should find text/html part")
    }
}

@Test("Multipart bookmark example")
func multipartBookmarkExample() async throws {
    let bookmarkContent = """
        From: Nathan Borror <zV6nZFTyrypSgXo1mxC02yg6PKeXv8gWpKWa1/AzAPw=>
        Date: Wed, 15 Oct 2025 18:42:00 -0700
        MIME-Version: 1.0
        Content-Type: multipart/bookmark; boundary="bookmark"

        --bookmark
        Content-Type: text/book-info
        Title: Why Greatness Cannot Be Planned
        Subtitle: The Myth of the Objective
        Authors: Kenneth O. Stanley, Joel Lehman
        ISBN-13: 978-3319155234
        Published: 18 May 2015
        Language: en
        Pages: 135

        --bookmark
        Content-Type: text/quote; charset="utf-8"
        Page: 10
        Date: Thu, 29 May 2025 16:20:00 -0700

        "Sometimes the best way to achieve something great is to stop trying to achieve a particular great thing. In other words, greatness is possible if you are willing to stop demanding what that greatness should be. While it seems like discussing objectives leads to one paradox after another, this idea really should make sense. Aren't the greatest moments and epiphanies in life so often unexpected and unplanned? Serendipity can play an outsized role in life. There's a reason for this pattern. Even though serendipity is often portrayed as a happy accident, maybe it's not always so accidental after all. In fact, as we'll show, there's a lot we can do to attract serendipity, aside from simply betting on random luck."

        --bookmark
        Content-Type: text/note; charset="utf-8"
        Page: 10
        Date: Thu, 29 May 2025 16:20:00 -0700

        This book is turning out to be very cathartic. It's also preaching to the choir so I probably won't finish it!

        --bookmark
        Content-Type: text/progress
        Page: 65
        Date: Wed, 13 Oct 2025 18:42:00 -0700

        --bookmark
        Content-Type: text/review; charset="utf-8"
        Date: Wed, 15 Oct 2025 18:42:00 -0700
        Rating: 4.5
        Spoilers: false

        I enoyed this book!
        --bookmark--
        """

    let message = try MIMEDecoder().decode(bookmarkContent)

    // Test main headers
    #expect(
        message.parts[0].headers["From"]
            == "Nathan Borror <zV6nZFTyrypSgXo1mxC02yg6PKeXv8gWpKWa1/AzAPw=>")
    #expect(message.parts[0].headers["Date"] == "Wed, 15 Oct 2025 18:42:00 -0700")
    #expect(message.parts[0].headers["MIME-Version"] == "1.0")

    // Test parts count
    #expect(message.parts.count == 6)

    // Test book-info part
    let bookInfo = message.parts[1]
    #expect(bookInfo.headers["Content-Type"] == "text/book-info")
    #expect(bookInfo.headers["Title"] == "Why Greatness Cannot Be Planned")
    #expect(bookInfo.headers["Subtitle"] == "The Myth of the Objective")
    #expect(bookInfo.headers["Authors"] == "Kenneth O. Stanley, Joel Lehman")
    #expect(bookInfo.headers["ISBN-13"] == "978-3319155234")
    #expect(bookInfo.headers["Published"] == "18 May 2015")
    #expect(bookInfo.headers["Language"] == "en")
    #expect(bookInfo.headers["Pages"] == "135")

    // Test quote part
    let quote = message.parts[2]
    #expect(quote.headerAttributes("Content-Type").value == "text/quote")
    #expect(quote.headers["Page"] == "10")
    #expect(quote.headers["Date"] == "Thu, 29 May 2025 16:20:00 -0700")
    #expect(quote.body.contains("Sometimes the best way to achieve something great"))

    // Test note part
    let note = message.parts[3]
    #expect(note.headerAttributes("Content-Type").value == "text/note")
    #expect(note.headers["Page"] == "10")
    #expect(note.body.contains("very cathartic"))

    // Test progress part
    let progress = message.parts[4]
    #expect(progress.headers["Content-Type"] == "text/progress")
    #expect(progress.headers["Page"] == "65")
    #expect(progress.body.isEmpty)

    // Test review part
    let review = message.parts[5]
    #expect(review.headerAttributes("Content-Type").value == "text/review")
    #expect(review.headers["Rating"] == "4.5")
    #expect(review.headers["Spoilers"] == "false")
    #expect(review.body.contains("I enoyed this book!"))
}

@Test("Multipart content-Type filtering")
func multipartContentTypeFiltering() async throws {
    let mimeContent = """
        From: Test <test@example.com>
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Plain text 1
        --test
        Content-Type: text/html

        <p>HTML</p>
        --test
        Content-Type: text/plain

        Plain text 2
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let plainParts = message.parts(withHeader: "Content-Type", value: "text/plain")
    #expect(plainParts.count == 2)
    #expect(plainParts[0].body == "Plain text 1")
    #expect(plainParts[1].body == "Plain text 2")

    let htmlPart = message.firstPart(withHeader: "Content-Type", value: "text/html")
    #expect(htmlPart != nil)
    #expect(htmlPart?.body == "<p>HTML</p>")
}

@Test("Multipart without boundary")
func multipartWithoutBoundaryTreatedAsSinglePart() async throws {
    let mimeContent = """
        From: Test <test@example.com>
        Content-Type: multipart/mixed

        --test
        Content-Type: text/plain

        This is treated as a single part
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Without a boundary parameter, even multipart/* is treated as a single part
    #expect(message.parts.count == 1)
    #expect(message.parts[0].body.contains("This is treated as a single part"))
}

@Test("Multipart with empty parts")
func multipartEmptyParts() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="empty"

        --empty
        Content-Type: text/plain

        --empty
        Content-Type: text/html

        --empty--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    #expect(message.parts.count == 3)
    #expect(message.parts[1].body.isEmpty)
    #expect(message.parts[2].body.isEmpty)
}

@Test("Multipart body decoding")
func multipartBodyDecoding() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain; charset="utf-8"

        Hello, 世界!
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let part = message.parts[1]

    #expect(part.decodedBody == "Hello, 世界!")
    #expect(part.body == part.decodedBody)
}

@Test("Multipart part checking")
func multipartPartChecking() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Plain text
        --test
        Content-Type: text/html

        <p>HTML</p>
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.hasPart(withHeader: "Content-Type", value: "text/plain"))
    #expect(message.hasPart(withHeader: "Content-Type", value: "text/html"))
    #expect(message.hasPart(withHeader: "Content-Type", value: "application/json") == false)
    #expect(message.hasPart(withHeader: "Content-Type", value: "TEXT/PLAIN"))  // Case insensitive
}

// MARK: Multipart Nested

@Test("Multipart nested round-trip")
func multipartNestedRoundTrip() async throws {
    // Create a nested multipart structure programmatically
    var envelopeHeaders = MIMEHeaders()
    envelopeHeaders["From"] = "test@example.com"
    envelopeHeaders["Content-Type"] = "multipart/mixed; boundary=\"outer\""

    // Create nested multipart/alternative part
    var alternativeHeaders = MIMEHeaders()
    alternativeHeaders["Content-Type"] = "multipart/alternative; boundary=\"inner\""

    var plainHeaders = MIMEHeaders()
    plainHeaders["Content-Type"] = "text/plain"
    let plainPart = MIMEPart(headers: plainHeaders, body: "Plain text version", parts: [])

    var htmlHeaders = MIMEHeaders()
    htmlHeaders["Content-Type"] = "text/html"
    let htmlPart = MIMEPart(headers: htmlHeaders, body: "<p>HTML version</p>", parts: [])

    let alternativePart = MIMEPart(
        headers: alternativeHeaders, body: "", parts: [plainPart, htmlPart])

    // Create attachment part
    var attachmentHeaders = MIMEHeaders()
    attachmentHeaders["Content-Type"] = "application/pdf"
    attachmentHeaders["Content-Disposition"] = "attachment; filename=\"doc.pdf\""
    let attachmentPart = MIMEPart(headers: attachmentHeaders, body: "PDF content here", parts: [])

    let envelope = MIMEPart(headers: envelopeHeaders, body: "", parts: [])
    let message = MIMEMessage([envelope, alternativePart, attachmentPart])

    // Encode the message
    let encoder = MIMEEncoder()
    let encoded = encoder.encode(message)

    // Decode it back
    let decoder = MIMEDecoder()
    let decoded = try decoder.decode(encoded)

    // Verify structure is preserved
    #expect(decoded.parts.count == 3)  // envelope + alternative + attachment

    // Check envelope
    #expect(decoded.parts[0].headers["From"] == "test@example.com")

    // Check nested multipart/alternative
    let decodedAlternative = decoded.parts[1]
    #expect(decodedAlternative.headers["Content-Type"]?.contains("multipart/alternative") == true)
    #expect(decodedAlternative.parts.count == 2)

    // Check nested plain text
    let decodedPlain = decodedAlternative.parts[0]
    #expect(decodedPlain.headers["Content-Type"]?.contains("text/plain") == true)
    #expect(decodedPlain.body == "Plain text version")
    #expect(decodedPlain.parts.isEmpty)

    // Check nested HTML
    let decodedHtml = decodedAlternative.parts[1]
    #expect(decodedHtml.headers["Content-Type"]?.contains("text/html") == true)
    #expect(decodedHtml.body == "<p>HTML version</p>")
    #expect(decodedHtml.parts.isEmpty)

    // Check attachment
    let decodedAttachment = decoded.parts[2]
    #expect(decodedAttachment.headers["Content-Type"]?.contains("application/pdf") == true)
    #expect(decodedAttachment.body == "PDF content here")
    #expect(decodedAttachment.parts.isEmpty)

    // Test recursive search still works
    #expect(decoded.firstPart(withHeader: "Content-Type", value: "text/plain")?.body == "Plain text version")
    #expect(decoded.firstPart(withHeader: "Content-Type", value: "text/html")?.body == "<p>HTML version</p>")
}

@Test("Multipart nested programmatic creation")
func multipartNestedProgrammaticCreation() async throws {
    // Create a complex 3-level nested structure programmatically

    // Level 3: Create multipart/related with HTML and image
    var relatedHeaders = MIMEHeaders()
    relatedHeaders["Content-Type"] = "multipart/related; boundary=\"related-123\""

    var htmlHeaders = MIMEHeaders()
    htmlHeaders["Content-Type"] = "text/html; charset=utf-8"
    let htmlPart = MIMEPart(
        headers: htmlHeaders,
        body: "<html><body><img src=\"cid:logo\"></body></html>",
        parts: []
    )

    var imageHeaders = MIMEHeaders()
    imageHeaders["Content-Type"] = "image/png"
    imageHeaders["Content-ID"] = "<logo>"
    let imagePart = MIMEPart(headers: imageHeaders, body: "base64imagedata", parts: [])

    let relatedPart = MIMEPart(
        headers: relatedHeaders,
        body: "",
        parts: [htmlPart, imagePart]
    )

    // Level 2: Create multipart/alternative with plain text and multipart/related
    var altHeaders = MIMEHeaders()
    altHeaders["Content-Type"] = "multipart/alternative; boundary=\"alt-456\""

    var plainHeaders = MIMEHeaders()
    plainHeaders["Content-Type"] = "text/plain"
    let plainPart = MIMEPart(headers: plainHeaders, body: "Plain text fallback", parts: [])

    let altPart = MIMEPart(
        headers: altHeaders,
        body: "",
        parts: [plainPart, relatedPart]
    )

    // Level 1: Create multipart/mixed with alternative and attachment
    var mixedHeaders = MIMEHeaders()
    mixedHeaders["From"] = "sender@example.com"
    mixedHeaders["Content-Type"] = "multipart/mixed; boundary=\"mixed-789\""

    var attachHeaders = MIMEHeaders()
    attachHeaders["Content-Type"] = "application/zip"
    attachHeaders["Content-Disposition"] = "attachment; filename=\"archive.zip\""
    let attachPart = MIMEPart(headers: attachHeaders, body: "zipdata", parts: [])

    let envelope = MIMEPart(headers: mixedHeaders, body: "", parts: [])
    let message = MIMEMessage([envelope, altPart, attachPart])

    // Verify structure
    #expect(message.parts.count == 3)

    // Verify alternative part has 2 nested parts
    let decodedAlt = message.parts[1]
    #expect(decodedAlt.parts.count == 2)
    #expect(decodedAlt.parts[0].headers["Content-Type"]?.contains("text/plain") == true)
    #expect(decodedAlt.parts[1].headers["Content-Type"]?.contains("multipart/related") == true)

    // Verify related part has 2 nested parts (HTML and image)
    let decodedRelated = decodedAlt.parts[1]
    #expect(decodedRelated.parts.count == 2)
    #expect(decodedRelated.parts[0].headers["Content-Type"]?.contains("text/html") == true)
    #expect(decodedRelated.parts[0].body.contains("<img src=\"cid:logo\">"))
    #expect(decodedRelated.parts[1].headers["Content-Type"]?.contains("image/png") == true)
    #expect(decodedRelated.parts[1].headers["Content-ID"] == "<logo>")

    // Verify attachment
    #expect(message.parts[2].headers["Content-Type"]?.contains("application/zip") == true)

    // Test recursive search finds deeply nested parts
    #expect(message.firstPart(withHeader: "Content-Type", value: "text/plain")?.body == "Plain text fallback")
    #expect(
        message.firstPart(withHeader: "Content-Type", value: "text/html")?.body.contains("<img src=\"cid:logo\">")
            == true)
    #expect(message.firstPart(withHeader: "Content-Type", value: "image/png")?.body == "base64imagedata")

    // Test that all parts of each type are found
    #expect(message.parts(withHeader: "Content-Type", value: "text/plain").count == 1)
    #expect(message.parts(withHeader: "Content-Type", value: "text/html").count == 1)
    #expect(message.parts(withHeader: "Content-Type", value: "image/png").count == 1)

    // Encode and decode to verify round-trip
    let encoder = MIMEEncoder()
    let encoded = encoder.encode(message)
    let decoder = MIMEDecoder()
    let decoded = try decoder.decode(encoded)

    // Verify decoded structure matches original
    #expect(
        decoded.firstPart(withHeader: "Content-Type", value: "text/html")?.body.contains("<img src=\"cid:logo\">")
            == true)
    #expect(decoded.firstPart(withHeader: "Content-Type", value: "image/png")?.headers["Content-ID"] == "<logo>")
}

