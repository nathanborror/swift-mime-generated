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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.headers["From"] == "Test User <test@example.com>")
    #expect(message.headers["MIME-Version"] == "1.0")
    #expect(message.parts.count == 2)

    let plainPart = message.parts[0]
    #expect(plainPart.headers["Content-Type"] == "text/plain")
    #expect(plainPart.body == "Hello, World!")

    let htmlPart = message.parts[1]
    #expect(htmlPart.headers["Content-Type"] == "text/html")
    #expect(htmlPart.body == "<h1>Hello, World!</h1>")
}

@Test func testHeaderOrderPreserved() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Date: Mon, 01 Jan 2024 12:00:00 -0800
        Subject: Test Message
        MIME-Version: 1.0
        Content-Type: text/plain

        Body content
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let keys = message.headers.keys
    #expect(keys.count == 6)
    #expect(keys[0] == "From")
    #expect(keys[1] == "To")
    #expect(keys[2] == "Date")
    #expect(keys[3] == "Subject")
    #expect(keys[4] == "MIME-Version")
    #expect(keys[5] == "Content-Type")
}

@Test func testEncodingMaintainsHeaderOrder() async throws {
    var headers = MIMEHeaders()
    headers["From"] = "sender@example.com"
    headers["To"] = "recipient@example.com"
    headers["Date"] = "Mon, 01 Jan 2024 12:00:00 -0800"
    headers["Subject"] = "Test Message"
    headers["MIME-Version"] = "1.0"
    headers["Content-Type"] = "text/plain"

    let message = MIMEMessage(headers: headers, parts: [])
    let encoded = MIMEEncoder().encode(message)
    let reparsed = try MIMEDecoder().decode(encoded)

    let keys = reparsed.headers.keys
    #expect(keys.count == 6)
    #expect(keys[0] == "From")
    #expect(keys[1] == "To")
    #expect(keys[2] == "Date")
    #expect(keys[3] == "Subject")
    #expect(keys[4] == "MIME-Version")
    #expect(keys[5] == "Content-Type")
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

    let message = try MIMEDecoder().decode(bookmarkContent)

    // Test headers
    #expect(
        message.headers["From"] == "Nathan Borror <zV6nZFTyrypSgXo1mxC02yg6PKeXv8gWpKWa1/AzAPw=>")
    #expect(message.headers["Date"] == "Wed, 15 Oct 2025 18:42:00 -0700")
    #expect(message.headers["MIME-Version"] == "1.0")

    // Test parts count
    #expect(message.parts.count == 5)

    // Test book-info part
    let bookInfo = message.parts[0]
    #expect(bookInfo.headers["Content-Type"] == "text/book-info")
    #expect(bookInfo.headers["Title"] == "Why Greatness Cannot Be Planned")
    #expect(bookInfo.headers["Subtitle"] == "The Myth of the Objective")
    #expect(bookInfo.headers["Authors"] == "Kenneth O. Stanley, Joel Lehman")
    #expect(bookInfo.headers["ISBN-13"] == "978-3319155234")
    #expect(bookInfo.headers["Published"] == "18 May 2015")
    #expect(bookInfo.headers["Language"] == "en")
    #expect(bookInfo.headers["Pages"] == "135")

    // Test quote part
    let quote = message.parts[1]
    #expect(quote.headerAttributes("Content-Type").value == "text/quote")
    #expect(quote.headers["Page"] == "10")
    #expect(quote.headers["Date"] == "Thu, 29 May 2025 16:20:00 -0700")
    #expect(quote.body.contains("Sometimes the best way to achieve something great"))

    // Test note part
    let note = message.parts[2]
    #expect(note.headerAttributes("Content-Type").value == "text/note")
    #expect(note.headers["Page"] == "10")
    #expect(note.body.contains("very cathartic"))

    // Test progress part
    let progress = message.parts[3]
    #expect(progress.headers["Content-Type"] == "text/progress")
    #expect(progress.headers["Page"] == "65")
    #expect(progress.body.isEmpty)

    // Test review part
    let review = message.parts[4]
    #expect(review.headerAttributes("Content-Type").value == "text/review")
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

    let message = try MIMEDecoder().decode(mimeContent)

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

    let message = try MIMEDecoder().decode(mimeContent)
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

    let message = try MIMEDecoder().decode(mimeContent)

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

    let message = try MIMEDecoder().decode(mimeContent)
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

    let message = try MIMEDecoder().decode(mimeContent)
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

    let message = try MIMEDecoder().decode(mimeContent)
    #expect(message.parts.count == 2)

    let plainPart = message.parts[0]
    #expect(plainPart.headerAttributes("Content-Type").value == "text/plain")

    let htmlPart = message.parts[1]
    #expect(htmlPart.headerAttributes("Content-Type").value == "text/html")
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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.headers["From"] == "sender@example.com")
    #expect(message.headers["To"] == "recipient@example.com")
    #expect(message.headers["Subject"] == "Test Message")
    #expect(message.headers["Date"] == "Mon, 01 Jan 2024 12:00:00 -0800")
    #expect(message.headers["MIME-Version"] == "1.0")
    #expect(message.headers["Content-Type"] != nil)
    #expect(message.headers["Content-Type"]?.contains("multipart/mixed") == true)
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

    let message = try MIMEDecoder().decode(mimeContent)

    // Verify MIME-Version is not present
    #expect(message.headers["MIME-Version"] == nil)

    // Verify message parses correctly without MIME-Version
    #expect(message.headers["From"] == "sender@example.com")
    #expect(message.headers["Subject"] == "Test Without MIME-Version")
    #expect(message.parts.count == 2)
    #expect(message.parts[0].headers["Content-Type"] == "text/plain")
    #expect(message.parts[1].headers["Content-Type"] == "text/html")
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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts[0].headerAttributes("Content-Type")["charset"] == "utf-8")
    #expect(message.parts[1].headerAttributes("Content-Type")["charset"] == "iso-8859-1")
    #expect(message.parts[2].headerAttributes("Content-Type")["charset"] == nil)
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

    let message = try MIMEDecoder().decode(mimeContent)

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

    let message = try MIMEDecoder().decode(mimeContent)
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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headerAttributes("Content-Type").value == "text/plain")
    #expect(message.parts[0].headerAttributes("Content-Type")["charset"] == "utf-8")
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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headers["Content-Type"] == "text/html")
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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headers["Content-Type"] == "application/json")
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

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.parts.count == 1)
    #expect(message.parts[0].headers["Content-Type"] == nil)
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

    let message = try MIMEDecoder().decode(simpleMessage)

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

    let multipart = try MIMEDecoder().decode(multipartMessage)

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

    var message = try MIMEDecoder().decode(mimeContent)

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

    var message = try MIMEDecoder().decode(mimeContent)

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

    var message = try MIMEDecoder().decode(mimeContent)

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

    let message = try MIMEDecoder().decode(mimeContent)
    let encoded = MIMEEncoder().encode(message)
    let encodedString = String(data: encoded, encoding: .utf8) ?? ""

    #expect(encodedString.contains("From: sender@example.com"))
    #expect(encodedString.contains("Content-Type: text/plain"))
    #expect(encodedString.contains("Hello, World!"))
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

@Test func testEncodingPart() async throws {
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
    var message = try MIMEDecoder().decode(original)

    // Edit
    message.headers["From"] = "updated@example.com"
    message.parts[0].body = "Updated content"

    // Encode
    let encoded = MIMEEncoder().encode(message)

    // Parse again
    let reparsed = try MIMEDecoder().decode(encoded)

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

    var message = try MIMEDecoder().decode(mimeContent)

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

    let message = try MIMEDecoder().decode(data)

    #expect(message.headers["From"] == "Test User <test@example.com>")
    #expect(message.parts.count == 2)
    #expect(message.parts[0].body == "Hello from Data!")
    #expect(message.parts[1].body == "<p>HTML from Data</p>")
}

@Test func testParsingFromInvalidUTF8Data() async throws {
    // Create invalid UTF-8 data
    let invalidData = Data([0xFF, 0xFE, 0xFD])

    #expect(throws: MIMEError.invalidUTF8) {
        try MIMEDecoder().decode(invalidData)
    }
}

@Test func testParsingWithNoHeaders() async throws {
    // Content with no headers, just a body
    let mimeContent = """

        This is just body content with no headers.
        """

    #expect(throws: MIMEError.noHeaders) {
        try MIMEDecoder().decode(mimeContent)
    }
}

@Test func testParsingWithEmptyContent() async throws {
    // Completely empty content
    let mimeContent = ""

    #expect(throws: MIMEError.noHeaders) {
        try MIMEDecoder().decode(mimeContent)
    }
}

// MARK: - Duplicate Headers Tests

@Test func testDuplicateHeadersParsing() async throws {
    let mimeContent = """
        From: sender@example.com
        To: recipient@example.com
        Received: from server1.example.com by server2.example.com
        Received: from server2.example.com by server3.example.com
        Received: from server3.example.com by server4.example.com
        Subject: Test with duplicate headers
        Content-Type: text/plain

        Body content
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Subscript should return first value
    #expect(message.headers["Received"] == "from server1.example.com by server2.example.com")

    // values(for:) should return all values
    let receivedHeaders = message.headers.values(for: "Received")
    #expect(receivedHeaders.count == 3)
    #expect(receivedHeaders[0] == "from server1.example.com by server2.example.com")
    #expect(receivedHeaders[1] == "from server2.example.com by server3.example.com")
    #expect(receivedHeaders[2] == "from server3.example.com by server4.example.com")

    // Case-insensitive lookup
    let receivedLowercase = message.headers.values(for: "received")
    #expect(receivedLowercase.count == 3)
}

@Test func testAddingDuplicateHeaders() async throws {
    var headers = MIMEHeaders()
    headers["From"] = "sender@example.com"

    // Add multiple Received headers
    headers.add("Received", value: "from server1.example.com")
    headers.add("Received", value: "from server2.example.com")
    headers.add("Received", value: "from server3.example.com")

    #expect(headers.count == 4)  // From + 3 Received

    // Subscript returns first
    #expect(headers["Received"] == "from server1.example.com")

    // values(for:) returns all
    let allReceived = headers.values(for: "Received")
    #expect(allReceived.count == 3)
    #expect(allReceived[0] == "from server1.example.com")
    #expect(allReceived[1] == "from server2.example.com")
    #expect(allReceived[2] == "from server3.example.com")
}

@Test func testSubscriptReplacesAllDuplicates() async throws {
    var headers = MIMEHeaders()

    // Add multiple headers with same name
    headers.add("X-Custom", value: "value1")
    headers.add("X-Custom", value: "value2")
    headers.add("X-Custom", value: "value3")

    #expect(headers.values(for: "X-Custom").count == 3)

    // Setting via subscript should replace all
    headers["X-Custom"] = "single-value"

    let values = headers.values(for: "X-Custom")
    #expect(values.count == 1)
    #expect(values[0] == "single-value")
}

@Test func testRemoveAllDuplicates() async throws {
    var headers = MIMEHeaders()
    headers.add("X-Custom", value: "value1")
    headers.add("X-Custom", value: "value2")
    headers.add("From", value: "test@example.com")

    #expect(headers.count == 3)

    // Remove all X-Custom headers
    headers.removeAll("X-Custom")

    #expect(headers.count == 1)
    #expect(headers["From"] == "test@example.com")
    #expect(headers["X-Custom"] == nil)
    #expect(headers.values(for: "X-Custom").isEmpty)
}

@Test func testEncodingDuplicateHeaders() async throws {
    var headers = MIMEHeaders()
    headers["From"] = "sender@example.com"
    headers.add("Received", value: "from server1.example.com")
    headers.add("Received", value: "from server2.example.com")

    let part = MIMEPart(headers: headers, body: "Test content")
    let encoded = MIMEEncoder().encode(part)
    let encodedString = String(data: encoded, encoding: .utf8) ?? ""

    // Should contain both Received headers
    #expect(encodedString.contains("Received: from server1.example.com"))
    #expect(encodedString.contains("Received: from server2.example.com"))
    #expect(encodedString.contains("From: sender@example.com"))
}

@Test func testRoundTripWithDuplicateHeaders() async throws {
    let originalContent = """
        From: sender@example.com
        Received: from server1.example.com
        Received: from server2.example.com
        Received: from server3.example.com
        Subject: Test
        Content-Type: text/plain

        Body
        """

    let message = try MIMEDecoder().decode(originalContent)

    // Verify parsing
    #expect(message.headers.values(for: "Received").count == 3)

    // Encode back
    let encoded = MIMEEncoder().encode(message)

    // Parse again
    let reparsed = try MIMEDecoder().decode(encoded)

    // Verify all Received headers are preserved
    let receivedHeaders = reparsed.headers.values(for: "Received")
    #expect(receivedHeaders.count == 3)
    #expect(receivedHeaders[0] == "from server1.example.com")
    #expect(receivedHeaders[1] == "from server2.example.com")
    #expect(receivedHeaders[2] == "from server3.example.com")
}

@Test func testValuesForNonExistentHeader() async throws {
    let headers = MIMEHeaders()
    let values = headers.values(for: "NonExistent")
    #expect(values.isEmpty)
}

@Test func testDuplicateHeadersCaseInsensitive() async throws {
    var headers = MIMEHeaders()
    headers.add("Received", value: "value1")
    headers.add("RECEIVED", value: "value2")
    headers.add("received", value: "value3")

    // All should be stored as the same header
    let values = headers.values(for: "Received")
    #expect(values.count == 3)

    // Should work with any case
    #expect(headers.values(for: "RECEIVED").count == 3)
    #expect(headers.values(for: "received").count == 3)
}

@Test func testDuplicateHeadersInMultipartMessage() async throws {
    let mimeContent = """
        From: sender@example.com
        Received: from server1.example.com
        Received: from server2.example.com
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain
        X-Custom: custom1
        X-Custom: custom2

        Part 1
        --test
        Content-Type: text/html

        Part 2
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Check message-level duplicate headers
    #expect(message.headers.values(for: "Received").count == 2)

    // Check part-level duplicate headers
    #expect(message.parts[0].headers.values(for: "X-Custom").count == 2)
    #expect(message.parts[0].headers.values(for: "X-Custom")[0] == "custom1")
    #expect(message.parts[0].headers.values(for: "X-Custom")[1] == "custom2")
}

@Test func testSettingNilRemovesAllDuplicates() async throws {
    var headers = MIMEHeaders()
    headers.add("X-Custom", value: "value1")
    headers.add("X-Custom", value: "value2")
    headers.add("X-Custom", value: "value3")

    #expect(headers.values(for: "X-Custom").count == 3)

    // Setting nil should remove all
    headers["X-Custom"] = nil

    #expect(headers["X-Custom"] == nil)
    #expect(headers.values(for: "X-Custom").isEmpty)
    #expect(!headers.contains("X-Custom"))
}

// MARK: - MIMEHeaderAttributes Tests

@Test func testHeaderAttributesParsing() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs.all.count == 1)
}

@Test func testHeaderAttributesWithQuotedValues() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=\"utf-8\"")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
}

@Test func testHeaderAttributesMultipleParameters() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8; format=flowed; delsp=yes")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["format"] == "flowed")
    #expect(attrs["delsp"] == "yes")
    #expect(attrs.all.count == 3)
}

@Test func testHeaderAttributesCaseInsensitive() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")

    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["CHARSET"] == "utf-8")
    #expect(attrs["Charset"] == "utf-8")
}

@Test func testHeaderAttributesWithBoundary() async throws {
    let attrs = MIMEHeaderAttributes.parse("multipart/mixed; boundary=\"simple-boundary\"")

    #expect(attrs.value == "multipart/mixed")
    #expect(attrs["boundary"] == "simple-boundary")
}

@Test func testHeaderAttributesEmptyValue() async throws {
    let attrs = MIMEHeaderAttributes.parse(nil)

    #expect(attrs.value == "")
    #expect(attrs.all.isEmpty)
}

@Test func testHeaderAttributesNoParameters() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain")

    #expect(attrs.value == "text/plain")
    #expect(attrs.all.isEmpty)
}

@Test func testHeaderAttributesWithWhitespace() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain;  charset = \"utf-8\" ;  format = flowed ")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["format"] == "flowed")
}

@Test func testHeaderAttributesComplexContentType() async throws {
    let attrs = MIMEHeaderAttributes.parse(
        "multipart/alternative; boundary=\"boundary123\"; charset=\"utf-8\""
    )

    #expect(attrs.value == "multipart/alternative")
    #expect(attrs["boundary"] == "boundary123")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs.all.count == 2)
}

@Test func testContentTypeAttributesOnPart() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain; charset=utf-8; format=flowed

        Plain text
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let part = message.parts[0]
    let attrs = part.headerAttributes("Content-Type")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "utf-8")
    #expect(attrs["format"] == "flowed")
}

@Test func testContentTypeAttributesOnMessage() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"; charset="utf-8"

        --test
        Content-Type: text/plain

        Content
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let attrs = message.headerAttributes("Content-Type")

    #expect(attrs.value == "multipart/mixed")
    #expect(attrs["boundary"] == "test")
    #expect(attrs["charset"] == "utf-8")
}

@Test func testHeaderAttributesMethod() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain
        Content-Disposition: attachment; filename="document.pdf"; size=1024

        Content
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let part = message.parts[0]
    let disposition = part.headerAttributes("Content-Disposition")

    #expect(disposition.value == "attachment")
    #expect(disposition["filename"] == "document.pdf")
    #expect(disposition["size"] == "1024")
}

@Test func testHeaderAttributesMethodOnMessage() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"
        Content-Disposition: inline; filename="message.txt"

        --test
        Content-Type: text/plain

        Content
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)
    let disposition = message.headerAttributes("Content-Disposition")

    #expect(disposition.value == "inline")
    #expect(disposition["filename"] == "message.txt")
}

@Test func testHeaderAttributesWithSpecialCharacters() async throws {
    let attrs = MIMEHeaderAttributes.parse(
        "application/octet-stream; filename=\"file-name_2024.txt\""
    )

    #expect(attrs.value == "application/octet-stream")
    #expect(attrs["filename"] == "file-name_2024.txt")
}

@Test func testContentTypePropertyUsesAttributes() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"

        --test
        Content-Type: text/plain; charset=utf-8

        Content
        --test--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Message contentType should be just the media type
    #expect(message.headers["Content-Type"] == "multipart/mixed; boundary=\"test\"")

    // Part contentType should be just the media type
    #expect(message.parts[0].headerAttributes("Content-Type").value == "text/plain")

    // But charset should still be accessible
    #expect(message.parts[0].headerAttributes("Content-Type")["charset"] == "utf-8")
}

@Test func testHeaderAttributesEquality() async throws {
    let attrs1 = MIMEHeaderAttributes(value: "text/plain", attributes: ["charset": "utf-8"])
    let attrs2 = MIMEHeaderAttributes(value: "text/plain", attributes: ["charset": "utf-8"])
    let attrs3 = MIMEHeaderAttributes(value: "text/html", attributes: ["charset": "utf-8"])

    #expect(attrs1 == attrs2)
    #expect(attrs1 != attrs3)
}

@Test func testHeaderAttributesWithEmptyParameterValue() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=")

    #expect(attrs.value == "text/plain")
    #expect(attrs["charset"] == "")
}

@Test func testHeaderAttributesNonExistentParameter() async throws {
    let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8")

    #expect(attrs["nonexistent"] == nil)
}

@Test func testBoundaryExtractionUsesAttributes() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"; charset="utf-8"

        --test-boundary
        Content-Type: text/plain

        Part 1
        --test-boundary
        Content-Type: text/html

        Part 2
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Should successfully parse with the boundary
    #expect(message.parts.count == 2)
    #expect(message.parts[0].headers["Content-Type"] == "text/plain")
    #expect(message.parts[1].headers["Content-Type"] == "text/html")
}

@Test func testPartsWithContentDispositionName() async throws {
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
    #expect(
        fooParts[1].body.trimmingCharacters(in: .whitespacesAndNewlines) == "This is another foo")

    let barParts = message.parts(withContentDispositionName: "bar")
    #expect(barParts.count == 1)
    #expect(barParts[0].body.trimmingCharacters(in: .whitespacesAndNewlines) == "This is bar")

    let bazParts = message.parts(withContentDispositionName: "baz")
    #expect(bazParts.count == 0)
}

@Test func testFirstPartWithContentDispositionName() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: inline; name="foo"

        First foo
        --test-boundary
        Content-Type: text/html
        Content-Disposition: inline; name="bar"

        This is bar
        --test-boundary
        Content-Type: application/json
        Content-Disposition: attachment; name="foo"

        Second foo
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let fooPart = message.firstPart(withContentDispositionName: "foo")
    #expect(fooPart != nil)
    #expect(fooPart?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "First foo")

    let barPart = message.firstPart(withContentDispositionName: "bar")
    #expect(barPart != nil)
    #expect(barPart?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "This is bar")

    let bazPart = message.firstPart(withContentDispositionName: "baz")
    #expect(bazPart == nil)
}

@Test func testPartNamedConvenience() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: inline; name="document"

        Document content
        --test-boundary
        Content-Type: image/png
        Content-Disposition: inline; name="image"

        Image data
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let documentPart = message.part(named: "document")
    #expect(documentPart != nil)
    #expect(
        documentPart?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "Document content")

    let imagePart = message.part(named: "image")
    #expect(imagePart != nil)
    #expect(imagePart?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "Image data")

    let unknownPart = message.part(named: "unknown")
    #expect(unknownPart == nil)
}

@Test func testHasPartWithContentDispositionName() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: inline; name="present"

        Content here
        --test-boundary
        Content-Type: text/html

        No disposition header
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    #expect(message.hasPart(withContentDispositionName: "present") == true)
    #expect(message.hasPart(withContentDispositionName: "absent") == false)
}

@Test func testContentDispositionNameCaseSensitive() async throws {
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
    #expect(message.part(named: "MyFile") != nil)
    #expect(message.part(named: "myfile") == nil)
    #expect(message.part(named: "MYFILE") == nil)
}

@Test func testContentDispositionWithFilenameAndName() async throws {
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

    let textPart = message.part(named: "textfile")
    #expect(textPart != nil)
    #expect(textPart?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "Text content")

    // Part without name attribute should not match
    let imagePart = message.part(named: "photo.png")
    #expect(imagePart == nil)
}

@Test func testContentDispositionWithQuotedName() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain
        Content-Disposition: inline; name="my file.txt"

        Content with quoted name
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    let part = message.part(named: "my file.txt")
    #expect(part != nil)
    #expect(
        part?.body.trimmingCharacters(in: .whitespacesAndNewlines) == "Content with quoted name")
}

@Test func testPartsWithoutContentDisposition() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test-boundary"

        --test-boundary
        Content-Type: text/plain

        Part without disposition
        --test-boundary
        Content-Type: text/html
        Content-Disposition: inline

        Part with disposition but no name
        --test-boundary--
        """

    let message = try MIMEDecoder().decode(mimeContent)

    // Should not find any parts when searching for a name
    #expect(message.part(named: "anything") == nil)
    #expect(message.hasPart(withContentDispositionName: "anything") == false)
    #expect(message.parts(withContentDispositionName: "anything").count == 0)
}
