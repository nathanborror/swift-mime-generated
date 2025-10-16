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

@Test func testMissingBoundaryThrowsError() async throws {
    let mimeContent = """
        From: Test <test@example.com>
        Content-Type: multipart/mixed

        --test
        Content-Type: text/plain

        This should fail
        --test--
        """

    #expect(throws: MIMEError.self) {
        try MIMEParser.parse(mimeContent)
    }
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
    #expect(message.date == "Mon, 01 Jan 2024 12:00:00 -0800")
    #expect(message.mimeVersion == "1.0")
    #expect(message.contentType != nil)
    #expect(message.contentType?.contains("multipart/mixed") == true)
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
