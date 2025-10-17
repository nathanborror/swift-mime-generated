# MIME

A Swift package for parsing MIME formatted multipart data. This library provides a clean, type-safe API for working with MIME messages, making it easy to extract headers, parts, and content from multipart messages.

## Features

- ✅ Parse MIME messages (both multipart and non-multipart) according to RFC 2045 and RFC 2046
- ✅ Optional MIME-Version header (not required for parsing)
- ✅ Case-insensitive header access
- ✅ Support for quoted and unquoted boundaries
- ✅ Automatic charset detection
- ✅ Type-safe API with `Sendable` support for Swift 6
- ✅ Convenient helper methods for common operations
- ✅ No external dependencies

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.2+

## Installation

Add this package to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-mime-generated.git", from: "1.0.0")
]
```

## Usage

### Multipart Message Example

```swift
import MIME

let mimeString = """
From: sender@example.com
Date: Mon, 01 Jan 2024 12:00:00 -0800
Content-Type: multipart/mixed; boundary="simple"

--simple
Content-Type: text/plain

Hello, World!
--simple
Content-Type: text/html

<h1>Hello, World!</h1>
--simple--
"""

let message = try MIMEParser.parse(mimeString)

// Access top-level headers
print(message.from)  // "sender@example.com"
print(message.date)  // "Mon, 01 Jan 2024 12:00:00 -0800"

// Access parts
print(message.parts.count)  // 2

for part in message.parts {
    print(part.contentType)  // "text/plain", "text/html"
    print(part.body)
}
```

### Non-Multipart Message Example

Non-multipart messages (like `text/plain`, `text/html`, `application/json`, etc.) are automatically treated as a single part:

```swift
let simpleMessage = """
From: sender@example.com
To: recipient@example.com
Subject: Simple Text Message
Content-Type: text/plain; charset="utf-8"

This is a simple text message without multipart formatting.
It will be parsed as a single part.
"""

let message = try MIMEParser.parse(simpleMessage)

print(message.parts.count)  // 1
print(message.parts[0].contentType)  // "text/plain"
print(message.parts[0].body)  // "This is a simple text message..."
```

### Finding Specific Parts

```swift
// Find all parts with a specific content type
let plainParts = message.parts(withContentType: "text/plain")

// Find the first part with a specific content type
if let htmlPart = message.firstPart(withContentType: "text/html") {
    print(htmlPart.body)
}

// Check if a message contains a specific content type
if message.hasPart(withContentType: "application/json") {
    print("Message contains JSON data")
}
```

### Accessing Headers

Headers are case-insensitive:

```swift
// All of these work (case-insensitive)
let contentType1 = message.headers["Content-Type"]
let contentType2 = message.headers["content-type"]
let contentType3 = message.headers["CONTENT-TYPE"]

// MIME-Version header is optional
let mimeVersion = message.mimeVersion  // May be nil
```

Part-specific headers:

```swift
let part = message.parts[0]
print(part.contentType)  // "text/plain"
print(part.charset)      // "utf-8"
print(part.headers["Custom-Header"])
```

### Complex Example

Here's a more complex example showing a bookmark tracking system:

```swift
let bookmarkData = """
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

"Sometimes the best way to achieve something great is to stop trying to achieve a particular great thing."

--bookmark
Content-Type: text/note; charset="utf-8"
Page: 10
Date: Thu, 29 May 2025 16:20:00 -0700

This book is turning out to be very cathartic!

--bookmark
Content-Type: text/progress
Page: 65
Date: Wed, 13 Oct 2025 18:42:00 -0700

--bookmark
Content-Type: text/review; charset="utf-8"
Date: Wed, 15 Oct 2025 18:42:00 -0700
Rating: 4.5
Spoilers: false

I enjoyed this book!
--bookmark--
"""

let message = try MIMEParser.parse(bookmarkData)

// Get book info
if let bookInfo = message.firstPart(withContentType: "text/book-info") {
    print(bookInfo.headers["Title"])     // "Why Greatness Cannot Be Planned"
    print(bookInfo.headers["Authors"])   // "Kenneth O. Stanley, Joel Lehman"
    print(bookInfo.headers["ISBN-13"])   // "978-3319155234"
}

// Get all quotes
let quotes = message.parts(withContentType: "text/quote")
for quote in quotes {
    print("Page \(quote.headers["Page"] ?? "?"): \(quote.body)")
}

// Get all notes
let notes = message.parts(withContentType: "text/note")
for note in notes {
    print(note.body)
}

// Get progress
if let progress = message.firstPart(withContentType: "text/progress") {
    print("Currently on page \(progress.headers["Page"] ?? "?")")
}

// Get review
if let review = message.firstPart(withContentType: "text/review") {
    print("Rating: \(review.headers["Rating"] ?? "N/A")")
    print("Review: \(review.body)")
}
```

## API Reference

### `MIMEParser`

The main entry point for parsing MIME messages. Supports both multipart messages (with boundaries) and non-multipart messages.

#### Methods

- `static func parse(_ content: String) throws -> MIMEMessage`
  - Parses a MIME message from a string
  - Multipart messages are parsed using the boundary specified in the Content-Type header
  - Non-multipart messages are treated as a single part containing the entire body

### `MIMEMessage`

Represents a complete MIME message with headers and parts.

#### Properties

- `headers: MIMEHeaders` - The top-level headers
- `parts: [MIMEPart]` - The individual parts of the message
- `from: String?` - The "From" header value
- `to: String?` - The "To" header value
- `subject: String?` - The "Subject" header value
- `date: String?` - The "Date" header value
- `mimeVersion: String?` - The "MIME-Version" header value (optional, may be nil)
- `contentType: String?` - The "Content-Type" header value

#### Methods

- `func parts(withContentType contentType: String) -> [MIMEPart]`
  - Returns all parts with a specific content type
- `func firstPart(withContentType contentType: String) -> MIMEPart?`
  - Returns the first part with a specific content type
- `func hasPart(withContentType contentType: String) -> Bool`
  - Returns true if any part has the specified content type

### `MIMEPart`

Represents a single part of a multipart MIME message.

#### Properties

- `headers: MIMEHeaders` - The headers for this part
- `body: String` - The body content
- `contentType: String?` - The content type (e.g., "text/plain")
- `charset: String?` - The charset (e.g., "utf-8")
- `decodedBody: String` - The decoded body content

### `MIMEHeaders`

A case-insensitive dictionary for MIME headers.

#### Methods

- `subscript(key: String) -> String?` - Access headers by name (case-insensitive)
- `func contains(_ key: String) -> Bool` - Check if a header exists
- Conforms to `Collection`, so you can iterate over headers

### `MIMEError`

Errors that can occur during parsing.

#### Cases

- `invalidFormat` - The MIME message format is invalid
- `invalidEncoding` - The character encoding is invalid or unsupported

## Testing

Run the test suite:

```bash
swift test
```

## License

[Your License Here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.