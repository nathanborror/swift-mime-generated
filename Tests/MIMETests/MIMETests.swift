import Foundation
import Testing

@testable import MIME

@Test func testBasicMultipartParsing() async throws {
    let mimeContent = """
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

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.headers["From"] == "Test User <test@example.com>")
    #expect(message.headers["MIME-Version"] == "1.0")
    #expect(message.parts.count == 2)

    let plainPart = message.parts[0]
    #expect(plainPart.contentType == "text/plain")
    #expect(plainPart.body == "Hello, World!")

    let htmlPart = message.parts[1]
    #expect(htmlPart.contentType == "text/html")
    #expect(htmlPart.body == "<h1>Hello, World!</h1>")
}

@Test func testBookmarkExample() async throws {
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

    let message = try MIMEParser.parse(bookmarkContent)

    // Test headers
    #expect(
        message.headers["From"] == "Nathan Borror <zV6nZFTyrypSgXo1mxC02yg6PKeXv8gWpKWa1/AzAPw=>")
    #expect(message.headers["Date"] == "Wed, 15 Oct 2025 18:42:00 -0700")
    #expect(message.headers["MIME-Version"] == "1.0")

    // Test parts count
    #expect(message.parts.count == 5)

    // Test book-info part
    let bookInfo = message.parts[0]
    #expect(bookInfo.contentType == "text/book-info")
    #expect(bookInfo.headers["Title"] == "Why Greatness Cannot Be Planned")
    #expect(bookInfo.headers["Subtitle"] == "The Myth of the Objective")
    #expect(bookInfo.headers["Authors"] == "Kenneth O. Stanley, Joel Lehman")
    #expect(bookInfo.headers["ISBN-13"] == "978-3319155234")
    #expect(bookInfo.headers["Published"] == "18 May 2015")
    #expect(bookInfo.headers["Language"] == "en")
    #expect(bookInfo.headers["Pages"] == "135")

    // Test quote part
    let quote = message.parts[1]
    #expect(quote.contentType == "text/quote")
    #expect(quote.headers["Page"] == "10")
    #expect(quote.headers["Date"] == "Thu, 29 May 2025 16:20:00 -0700")
    #expect(quote.body.contains("Sometimes the best way to achieve something great"))

    // Test note part
    let note = message.parts[2]
    #expect(note.contentType == "text/note")
    #expect(note.headers["Page"] == "10")
    #expect(note.body.contains("very cathartic"))

    // Test progress part
    let progress = message.parts[3]
    #expect(progress.contentType == "text/progress")
    #expect(progress.headers["Page"] == "65")
    #expect(progress.body.isEmpty)

    // Test review part
    let review = message.parts[4]
    #expect(review.contentType == "text/review")
    #expect(review.headers["Rating"] == "4.5")
    #expect(review.headers["Spoilers"] == "false")
    #expect(review.body.contains("I enoyed this book!"))
}

@Test func testHeaderCaseInsensitivity() async throws {
    var headers = MIMEHeaders()
    headers["Content-Type"] = "text/plain"

    #expect(headers["content-type"] == "text/plain")
    #expect(headers["CONTENT-TYPE"] == "text/plain")
    #expect(headers["Content-Type"] == "text/plain")
}

@Test func testContentTypeFiltering() async throws {
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

    let message = try MIMEParser.parse(mimeContent)

    let plainParts = message.parts(withContentType: "text/plain")
    #expect(plainParts.count == 2)
    #expect(plainParts[0].body == "Plain text 1")
    #expect(plainParts[1].body == "Plain text 2")

    let htmlPart = message.firstPart(withContentType: "text/html")
    #expect(htmlPart != nil)
    #expect(htmlPart?.body == "<p>HTML</p>")
}

@Test func testQuotedBoundary() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="quoted-boundary"

        --quoted-boundary
        Content-Type: text/plain

        Part 1
        --quoted-boundary
        Content-Type: text/plain

        Part 2
        --quoted-boundary--
        """

    let message = try MIMEParser.parse(mimeContent)
    #expect(message.parts.count == 2)
    #expect(message.parts[0].body == "Part 1")
    #expect(message.parts[1].body == "Part 2")
}

@Test func testMultipartWithoutBoundaryTreatedAsSinglePart() async throws {
    let mimeContent = """
        From: Test <test@example.com>
        Content-Type: multipart/mixed

        --test
        Content-Type: text/plain

        This is treated as a single part
        --test--
        """

    let message = try MIMEParser.parse(mimeContent)

    // Without a boundary parameter, even multipart/* is treated as a single part
    #expect(message.parts.count == 1)
    #expect(message.parts[0].body.contains("This is treated as a single part"))
}

@Test func testEmptyParts() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="empty"

        --empty
        Content-Type: text/plain

        --empty
        Content-Type: text/html

        --empty--
        """

    let message = try MIMEParser.parse(mimeContent)
    #expect(message.parts.count == 2)
    #expect(message.parts[0].body.isEmpty)
    #expect(message.parts[1].body.isEmpty)
}

@Test func testMultilineHeaders() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed;
         boundary="multiline"
        From: Very Long Name
         <very.long.email@example.com>

        --multiline
        Content-Type: text/plain

        Test
        --multiline--
        """

    let message = try MIMEParser.parse(mimeContent)
    #expect(message.headers["From"]?.contains("Very Long Name") == true)
    #expect(message.headers["From"]?.contains("very.long.email@example.com") == true)
    #expect(message.parts.count == 1)
}

@Test func testHeadersCollection() async throws {
    var headers = MIMEHeaders()
    headers["From"] = "test@example.com"
    headers["To"] = "recipient@example.com"
    headers["Subject"] = "Test"

    #expect(headers.count == 3)
    #expect(headers.contains("From"))
    #expect(headers.contains("from"))
    #expect(!headers.contains("Cc"))

    var foundKeys: Set<String> = []
    for (key, _) in headers {
        foundKeys.insert(key)
    }
    #expect(foundKeys.count == 3)
}

@Test func testMIMEHeadersDictionaryLiteral() async throws {
    let headers: MIMEHeaders = [
        "From": "test@example.com",
        "To": "recipient@example.com",
        "Subject": "Test Message",
    ]

    #expect(headers["From"] == "test@example.com")
    #expect(headers["to"] == "recipient@example.com")
    #expect(headers["SUBJECT"] == "Test Message")
}

@Test func testComplexContentType() async throws {
    let mimeContent = """
        Content-Type: multipart/alternative; boundary="boundary123"; charset="utf-8"

        --boundary123
        Content-Type: text/plain; charset="utf-8"

        Plain text
        --boundary123
        Content-Type: text/html; charset="utf-8"

        <p>HTML</p>
        --boundary123--
        """

    let message = try MIMEParser.parse(mimeContent)
    #expect(message.parts.count == 2)

    let plainPart = message.parts[0]
    #expect(plainPart.contentType == "text/plain")

    let htmlPart = message.parts[1]
    #expect(htmlPart.contentType == "text/html")
}

@Test func testConvenienceHeaderAccessors() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Subject: Test Message
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        MIME-Version: 1.0
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Test content
        --test--
        """

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.headers["From"] == "sender@example.com")
    #expect(message.headers["To"] == "recipient@example.com")
    #expect(message.headers["Subject"] == "Test Message")
    #expect(message.date?.ISO8601Format() == "2024-01-01T20:00:00Z")
    #expect(message.mimeVersion == "1.0")
    #expect(message.contentType != nil)
    #expect(message.contentType?.contains("multipart/mixed") == true)
}

@Test func testMIMEVersionOptional() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Subject: Test Without MIME-Version
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        This message has no MIME-Version header
        --test
        Content-Type: text/html

        <p>Still works!</p>
        --test--
        """

    let message = try MIMEParser.parse(mimeContent)

    // Verify MIME-Version is not present
    #expect(message.mimeVersion == nil)
    #expect(message.headers["MIME-Version"] == nil)

    // Verify message parses correctly without MIME-Version
    #expect(message.headers["From"] == "sender@example.com")
    #expect(message.headers["Subject"] == "Test Without MIME-Version")
    #expect(message.parts.count == 2)
    #expect(message.parts[0].contentType == "text/plain")
    #expect(message.parts[1].contentType == "text/html")
}

@Test func testCharsetExtraction() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain; charset="utf-8"

        Plain text
        --test
        Content-Type: text/html; charset=iso-8859-1

        <p>HTML</p>
        --test
        Content-Type: application/json

        {"key": "value"}
        --test--
        """

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.parts[0].charset == "utf-8")
    #expect(message.parts[1].charset == "iso-8859-1")
    #expect(message.parts[2].charset == nil)
}

@Test func testHasPartMethod() async throws {
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

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.hasPart(withContentType: "text/plain"))
    #expect(message.hasPart(withContentType: "text/html"))
    #expect(!message.hasPart(withContentType: "application/json"))
    #expect(message.hasPart(withContentType: "TEXT/PLAIN"))  // Case insensitive
}

@Test func testDecodedBody() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain; charset="utf-8"

        Hello, 世界!
        --test--
        """

    let message = try MIMEParser.parse(mimeContent)
    let part = message.parts[0]

    #expect(part.decodedBody == "Hello, 世界!")
    #expect(part.body == part.decodedBody)
}

@Test func testNonMultipartTextPlain() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Subject: Simple Text Message
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        Content-Type: text/plain; charset="utf-8"

        This is a simple text message without multipart.
        It should be treated as a single part.
        """

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].contentType == "text/plain")
    #expect(message.parts[0].charset == "utf-8")
    #expect(message.parts[0].body.contains("This is a simple text message"))
}

@Test func testNonMultipartTextHtml() async throws {
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

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].contentType == "text/html")
    #expect(message.parts[0].body.contains("<h1>Hello World</h1>"))
    #expect(message.parts[0].body.contains("<p>This is an HTML message.</p>"))
}

@Test func testNonMultipartApplicationJson() async throws {
    let mimeContent = """
        From: api@example.com
        Content-Type: application/json

        {
            "name": "John Doe",
            "email": "john@example.com",
            "active": true
        }
        """

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].contentType == "application/json")
    #expect(message.parts[0].body.contains("\"name\": \"John Doe\""))
    #expect(message.parts[0].body.contains("\"active\": true"))
}

@Test func testNonMultipartNoContentType() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Subject: Message without Content-Type

        This message has no Content-Type header.
        It should still parse as a single part.
        """

    let message = try MIMEParser.parse(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].contentType == nil)
    #expect(message.parts[0].body.contains("This message has no Content-Type header"))
}

@Test func testBodyPropertyForNonMultipartMessages() async throws {
    // Test non-multipart message returns body
    let simpleMessage = """
        From: sender@example.com
        Content-Type: text/plain

        Hello, World!
        This is a simple message.
        """

    let message = try MIMEParser.parse(simpleMessage)

    #expect(message.body != nil)
    #expect(message.body?.contains("Hello, World!") == true)
    #expect(message.body?.contains("This is a simple message.") == true)

    // Test multipart message returns nil
    let multipartMessage = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Part 1
        --test
        Content-Type: text/html

        Part 2
        --test--
        """

    let multipart = try MIMEParser.parse(multipartMessage)

    #expect(multipart.body == nil)
    #expect(multipart.parts.count == 2)
}

@Test func testEditingMessageHeaders() async throws {
    let mimeContent = """
        From: original@example.com
        Subject: Original Subject
        Content-Type: text/plain

        Original content
        """

    var message = try MIMEParser.parse(mimeContent)

    // Edit headers
    message.headers["From"] = "updated@example.com"
    message.headers["Subject"] = "Updated Subject"
    message.headers["X-Custom-Header"] = "Custom Value"

    #expect(message.headers["From"] == "updated@example.com")
    #expect(message.headers["Subject"] == "Updated Subject")
    #expect(message.headers["X-Custom-Header"] == "Custom Value")
}

@Test func testEditingPartBody() async throws {
    let mimeContent = """
        Content-Type: text/plain

        Original content
        """

    var message = try MIMEParser.parse(mimeContent)

    // Edit body
    message.parts[0].body = "Updated content"

    #expect(message.parts[0].body == "Updated content")
    #expect(message.body == "Updated content")
}

@Test func testEditingPartHeaders() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Part 1
        --test--
        """

    var message = try MIMEParser.parse(mimeContent)

    // Edit part headers
    message.parts[0].headers["Content-Type"] = "text/html"
    message.parts[0].headers["X-Custom"] = "value"

    #expect(message.parts[0].headers["Content-Type"] == "text/html")
    #expect(message.parts[0].headers["X-Custom"] == "value")
}

@Test func testEncodingNonMultipartMessage() async throws {
    let mimeContent = """
        From: sender@example.com
        Content-Type: text/plain

        Hello, World!
        """

    let message = try MIMEParser.parse(mimeContent)
    let encoded = message.encode()

    #expect(encoded.contains("From: sender@example.com"))
    #expect(encoded.contains("Content-Type: text/plain"))
    #expect(encoded.contains("Hello, World!"))
}

@Test func testEncodingMultipartMessage() async throws {
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

    let message = try MIMEParser.parse(mimeContent)
    let encoded = message.encode()

    #expect(encoded.contains("From: sender@example.com"))
    #expect(encoded.contains("Content-Type: multipart/mixed; boundary=\"simple\""))
    #expect(encoded.contains("--simple"))
    #expect(encoded.contains("text/plain"))
    #expect(encoded.contains("Hello, World!"))
    #expect(encoded.contains("text/html"))
    #expect(encoded.contains("<h1>Hello</h1>"))
    #expect(encoded.contains("--simple--"))
}

@Test func testEncodingPart() async throws {
    var headers = MIMEHeaders()
    headers["Content-Type"] = "text/plain"
    headers["X-Custom"] = "value"

    let part = MIMEPart(headers: headers, body: "Test content")
    let encoded = part.encode()

    #expect(encoded.contains("Content-Type: text/plain"))
    #expect(encoded.contains("X-Custom: value"))
    #expect(encoded.contains("Test content"))
}

@Test func testRoundTripParseEditEncode() async throws {
    let original = """
        From: original@example.com
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Original content
        --test--
        """

    // Parse
    var message = try MIMEParser.parse(original)

    // Edit
    message.headers["From"] = "updated@example.com"
    message.parts[0].body = "Updated content"

    // Encode
    let encoded = message.encode()

    // Parse again
    let reparsed = try MIMEParser.parse(encoded)

    // Verify
    #expect(reparsed.headers["From"] == "updated@example.com")
    #expect(reparsed.parts[0].body == "Updated content")
}

@Test func testAddingAndRemovingParts() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain

        Part 1
        --test--
        """

    var message = try MIMEParser.parse(mimeContent)

    #expect(message.parts.count == 1)

    // Add a new part
    var newHeaders = MIMEHeaders()
    newHeaders["Content-Type"] = "text/html"
    let newPart = MIMEPart(headers: newHeaders, body: "<p>New part</p>")
    message.parts.append(newPart)

    #expect(message.parts.count == 2)
    #expect(message.parts[1].body == "<p>New part</p>")

    // Remove a part
    message.parts.remove(at: 0)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].body == "<p>New part</p>")
}

@Test func testParsingFromData() async throws {
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

    let message = try MIMEParser.parse(data)

    #expect(message.headers["From"] == "Test User <test@example.com>")
    #expect(message.parts.count == 2)
    #expect(message.parts[0].body == "Hello from Data!")
    #expect(message.parts[1].body == "<p>HTML from Data</p>")
}

@Test func testParsingFromInvalidUTF8Data() async throws {
    // Create invalid UTF-8 data
    let invalidData = Data([0xFF, 0xFE, 0xFD])

    #expect(throws: MIMEError.invalidUTF8) {
        try MIMEParser.parse(invalidData)
    }
}

@Test func testParsingWithNoHeaders() async throws {
    // Content with no headers, just a body
    let mimeContent = """

        This is just body content with no headers.
        """

    #expect(throws: MIMEError.noHeaders) {
        try MIMEParser.parse(mimeContent)
    }
}

@Test func testParsingWithEmptyContent() async throws {
    // Completely empty content
    let mimeContent = ""

    #expect(throws: MIMEError.noHeaders) {
        try MIMEParser.parse(mimeContent)
    }
}
