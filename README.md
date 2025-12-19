# MIME

A Swift package for parsing MIME formatted multipart data. This library provides a clean, type-safe API for working with MIME messages, making it easy to extract headers, parts, and content from multipart messages.

## Features

- ✅ Parse MIME messages (both multipart and non-multipart) according to RFC 2045 and RFC 2046
- ✅ Nested multipart support (tree structure for complex MIME messages)
- ✅ Optional MIME-Version header (not required for parsing)
- ✅ Case-insensitive header access
- ✅ Full support for duplicate headers (e.g., multiple `Received` headers)
- ✅ Support for quoted and unquoted boundaries
- ✅ Automatic charset detection
- ✅ Generalized header attribute parsing (e.g., `charset`, `boundary`, `filename`)
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

let message = try MIMEDecoder().decode(mimeString)

// Access top-level headers
print(message.headers["From"])  // "sender@example.com"
print(message.headers["Date"])  // "Mon, 01 Jan 2024 12:00:00 -0800"

// Access parts
print(message.parts.count)  // 2

for part in message.parts {
    print(part.headers["Content-Type"])  // "text/plain", "text/html"
    print(part.body)
}
```

### Nested Multipart Message Example

MIME parts can contain nested multipart structures, creating a tree of content. This is commonly used in emails with both text and HTML versions plus attachments:

```swift
let nestedMimeString = """
From: sender@example.com
Content-Type: multipart/mixed; boundary="outer"

--outer
Content-Type: multipart/alternative; boundary="inner"

--inner
Content-Type: text/plain

Plain text version
--inner
Content-Type: text/html

<p>HTML version</p>
--inner--
--outer
Content-Type: application/pdf
Content-Disposition: attachment; filename="doc.pdf"

PDF content here
--outer--
"""

let message = try MIMEDecoder().decode(nestedMimeString)

// Access nested parts directly
let alternativePart = message.parts[1]
print(alternativePart.parts.count)  // 2 (plain and HTML)
print(alternativePart.parts[0].body)  // "Plain text version"
print(alternativePart.parts[1].body)  // "<p>HTML version</p>"

// Recursive search through nested parts
if let plainPart = message.firstPart(withContentType: "text/plain") {
    print(plainPart.body)  // "Plain text version"
}

if let htmlPart = message.firstPart(withContentType: "text/html") {
    print(htmlPart.body)  // "<p>HTML version</p>"
}

// Get all parts of a specific type (searches recursively)
let allTextParts = message.parts(withContentType: "text/plain")
```

You can also programmatically create nested multipart structures:

```swift
// Create nested multipart/alternative part
var alternativeHeaders = MIMEHeaders()
alternativeHeaders["Content-Type"] = "multipart/alternative; boundary=\"alt-boundary\""

var plainHeaders = MIMEHeaders()
plainHeaders["Content-Type"] = "text/plain"
let plainPart = MIMEPart(headers: plainHeaders, body: "Plain text", parts: [])

var htmlHeaders = MIMEHeaders()
htmlHeaders["Content-Type"] = "text/html"
let htmlPart = MIMEPart(headers: htmlHeaders, body: "<p>HTML</p>", parts: [])

// Nest the plain and HTML parts inside the alternative part
let alternativePart = MIMEPart(
    headers: alternativeHeaders,
    body: "",
    parts: [plainPart, htmlPart]
)

// Create top-level message with nested structure
var envelopeHeaders = MIMEHeaders()
envelopeHeaders["From"] = "sender@example.com"
envelopeHeaders["Content-Type"] = "multipart/mixed; boundary=\"outer\""

let envelope = MIMEPart(headers: envelopeHeaders, body: "", parts: [])
let message = MIMEMessage([envelope, alternativePart])

// Encode back to MIME format
let encoded = MIMEEncoder().encode(message)
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

let message = try MIMEDecoder().decode(simpleMessage)

// Convenient access to body for non-multipart messages
if let body = message.body {
    print(body)  // "This is a simple text message..."
}

// Or access via parts array
print(message.parts.count)  // 1
print(message.parts[0].headers["Content-Type"])  // "text/plain"
print(message.parts[0].body)  // "This is a simple text message..."
```

### Parsing from Data

The primary parsing method accepts `Data` objects. This is the recommended approach when working with network responses or file data:

```swift
// Parse from Data (primary method)
let data = mimeString.data(using: .utf8)!
let message = try MIMEDecoder().decode(data)

// The Data will be decoded as UTF-8
print(message.headers["From"])
print(message.parts.count)
```

You can also use the convenience method that accepts a `String` directly:

```swift
// Convenience method for String input
let message = try MIMEDecoder().decode(mimeString)
```

If the `Data` cannot be decoded as UTF-8, a `MIMEError.invalidUTF8` error will be thrown.

### Finding Specific Parts

#### By Content Type

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

#### By Content-Disposition Name

```swift
// Find all parts with a specific content-disposition name
let fooParts = message.parts(withContentDispositionName: "foo")

// Find the first part with a specific content-disposition name
if let fooPart = message.firstPart(withContentDispositionName: "foo") {
    print(fooPart.body)
}

// Convenience method: part(named:)
if let documentPart = message.part(named: "document") {
    print(documentPart.body)
}

// Check if a message contains a part with a specific name
if message.hasPart(withContentDispositionName: "image") {
    print("Message contains a part named 'image'")
}
```

### Editing and Encoding MIME Messages

MIME messages and parts have mutable properties, making them easy to edit. Once edited, you can encode them back to MIME format.

#### Editing Headers

```swift
var message = try MIMEDecoder().decode(mimeString)

// Edit top-level headers
message.headers["From"] = "new-sender@example.com"
message.headers["Subject"] = "Updated subject"

// Edit part headers
message.parts[0].headers["Content-Type"] = "text/html"
```

#### Editing Body Content

```swift
var message = try MIMEDecoder().decode(mimeString)

// Edit part body
message.parts[0].body = "This is the new content!"

// For non-multipart messages, edit the single part
if message.parts.count == 1 {
    message.parts[0].body = "New simple message content"
}
```

#### Adding and Removing Parts

```swift
var message = try MIMEDecoder().decode(mimeString)

// Add a new part
var newPartHeaders = MIMEHeaders()
newPartHeaders["Content-Type"] = "text/plain"
let newPart = MIMEPart(headers: newPartHeaders, body: "New part content")
message.parts.append(newPart)

// Remove a part
message.parts.remove(at: 1)
```

#### Encoding Back to MIME Format

After editing, encode the message back to data:

```swift
var message = try MIMEDecoder().decode(mimeString)

// Make some edits
message.headers["From"] = "updated@example.com"
message.parts[0].body = "Updated content"

// Encode back to MIME format
let encoder = MIMEEncoder()
let encodedData = encoder.encode(message)
let encodedString = String(data: encodedData, encoding: .utf8) ?? ""
print(encodedString)
// Output:
// From: updated@example.com
// Content-Type: multipart/mixed; boundary="simple"
//
// --simple
// Content-Type: text/plain
//
// Updated content
// --simple--
```

#### Encoding Individual Parts

You can also encode individual parts:

```swift
var part = message.parts[0]
part.body = "Modified part content"
part.headers["Custom-Header"] = "Custom Value"

let encoder = MIMEEncoder()
let encodedData = encoder.encode(part)
let encodedString = String(data: encodedData, encoding: .utf8) ?? ""
print(encodedString)
// Output:
// Content-Type: text/plain
// Custom-Header: Custom Value
//
// Modified part content
```

### Accessing Headers

Headers are case-insensitive:

```swift
// All of these work (case-insensitive)
let contentType1 = message.headers["Content-Type"]
let contentType2 = message.headers["content-type"]
let contentType3 = message.headers["CONTENT-TYPE"]

// MIME-Version header is optional
let mimeVersion = message.headers["MIME-Version"]  // May be nil
```

Part-specific headers:

```swift
let part = message.parts[0]
print(part.headers["Content-Type"]) // "text/plain"
print(part.headerAttributes("Content-Type")["charset"]) // "utf-8"
print(part.headers["Custom-Header"])
```

#### Iterating Headers in Order

Headers are stored and decoded in the order they appear in the original MIME message. You can iterate through them using the `ordered` property, which returns an array of `MIMEHeader` values. Each `MIMEHeader` is `Identifiable`, making it perfect for SwiftUI `ForEach` loops:

```swift
let message = try MIMEDecoder().decode(mimeContent)

// Iterate through headers in order
for header in message.headers.ordered {
    print("\(header.key): \(header.value)")
}

// Use in SwiftUI ForEach
ForEach(message.headers.ordered) { header in
    HStack {
        Text(header.key)
            .fontWeight(.semibold)
        Text(header.value)
    }
}

// Also works with Collection protocol
let headerCount = message.headers.count
for (key, value) in message.headers {
    print("\(key): \(value)")
}
```

The library preserves header order during parsing and encoding, ensuring round-trip consistency:

```swift
let original = try MIMEDecoder().decode(mimeContent)
let encoded = MIMEEncoder().encode(original)
let reparsed = try MIMEDecoder().decode(encoded)

// Headers maintain their original order
#expect(original.headers.keys == reparsed.headers.keys)
```

#### Working with Header Attributes

Many MIME headers contain a primary value followed by semicolon-separated attributes (e.g., `Content-Type: text/plain; charset=utf-8; format=flowed`). The library provides convenient access to these attributes:

```swift
let message = try MIMEDecoder().decode(mimeString)

// Access Content-Type attributes on the message
let attrs = message.headerAttributes("Content-Type")
print(attrs.value)         // "multipart/mixed"
print(attrs["boundary"])   // "simple"
print(attrs["charset"])    // "utf-8" (if present)
print(attrs.all)           // Dictionary of all attributes

// Access Content-Type attributes on a part
let part = message.parts[0]
let partAttrs = part.headerAttributes("Content-Type")
print(partAttrs.value)      // "text/plain"
print(partAttrs["charset"]) // "utf-8"
print(partAttrs["format"])  // "flowed"

// Parse attributes from any header
let disposition = part.headerAttributes("Content-Disposition")
print(disposition.value)       // "attachment"
print(disposition["filename"]) // "document.pdf"
print(disposition["size"])     // "1024"
```

You can also parse attributes directly:

```swift
let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8; format=flowed")
print(attrs.value)        // "text/plain"
print(attrs["charset"])   // "utf-8" (case-insensitive)
print(attrs["CHARSET"])   // "utf-8" (also works)
print(attrs["format"])    // "flowed"
```

Common use cases:

```swift
// Extract charset for text content
if let charset = part.headerAttributes("Content-Type")["charset"] {
    print("Charset: \(charset)")
}

// Check Content-Disposition for attachments
let disposition = part.headerAttributes("Content-Disposition")
if disposition.value == "attachment", let filename = disposition["filename"] {
    print("Attachment: \(filename)")
}

// Access boundary for multipart messages
if let boundary = message.headerAttributes("Content-Type")["boundary"] {
    print("Boundary: \(boundary)")
}
```

**Complete Example:**

```swift
let mimeContent = """
    From: sender@example.com
    Content-Type: multipart/mixed; boundary="docs"; charset="utf-8"
    
    --docs
    Content-Type: text/plain; charset=utf-8; format=flowed
    
    Hello! Please find the document attached.
    --docs
    Content-Type: application/pdf; name="report.pdf"
    Content-Disposition: attachment; filename="report.pdf"; size=2048
    
    [PDF content here]
    --docs--
    """

let message = try MIMEDecoder().decode(mimeContent)

// Parse message-level Content-Type attributes
let msgAttrs = message.headerAttributes("Content-Type")
print(msgAttrs.value)         // "multipart/mixed"
print(msgAttrs["boundary"])   // "docs"
print(msgAttrs["charset"])    // "utf-8"

// Parse first part (text/plain)
let textPart = message.parts[0]
let textAttrs = textPart.headerAttributes("Content-Type")
print(textAttrs.value)        // "text/plain"
print(textAttrs["charset"])   // "utf-8"
print(textAttrs["format"])    // "flowed"

// Parse second part (attachment)
let pdfPart = message.parts[1]
let pdfAttrs = pdfPart.headerAttributes("Content-Type")
print(pdfAttrs.value)         // "application/pdf"
print(pdfAttrs["name"])       // "report.pdf"

// Parse Content-Disposition for attachment metadata
let disposition = pdfPart.headerAttributes("Content-Disposition")
print(disposition.value)       // "attachment"
print(disposition["filename"]) // "report.pdf"
print(disposition["size"])     // "2048"
```

#### Working with Duplicate Headers

Some headers can appear multiple times in a MIME message (e.g., `Received` headers in email). The library fully supports this:

```swift
// Subscript returns the first value
let firstReceived = message.headers["Received"]

// Get all values for a header
let allReceived = message.headers.values(for: "Received")
for received in allReceived {
    print(received)
}

// Add a header without replacing existing ones
var headers = MIMEHeaders()
headers.add("Received", value: "from server1.example.com")
headers.add("Received", value: "from server2.example.com")
headers.add("Received", value: "from server3.example.com")

// Setting via subscript replaces all occurrences
headers["X-Custom"] = "new-value"  // Replaces all X-Custom headers

// Remove all headers with a name
headers.removeAll("Received")
```

Parsing preserves all duplicate headers:

```swift
let mimeContent = """
    From: sender@example.com
    Received: from server1.example.com
    Received: from server2.example.com
    Received: from server3.example.com
    Content-Type: text/plain
    
    Body
    """

let message = try MIMEDecoder().decode(mimeContent)
let received = message.headers.values(for: "Received")
print(received.count)  // 3
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

let message = try MIMEDecoder().decode(bookmarkData)

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

## Validation

The MIME validator allows you to validate MIME messages according to RFC 2045/2046 and custom rules. You can set header expectations for specific content types, ensuring that messages meet your requirements.

### Basic Validation

```swift
import MIME

let mimeString = """
Content-Type: text/plain

Hello, World!
"""

let validator = MIMEValidator()
let result = try validator.validate(mimeString)

if result.isValid {
    print("✓ Message is valid")
} else {
    print("✗ Message is invalid")
    for error in result.errors {
        print("  • \(error)")
    }
}
```

### Validation with Header Expectations

You can define custom header expectations for specific content types:

```swift
let expectation = MIMEHeaderExpectation(
    contentType: "text/plain",
    requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"],
    recommendedHeaders: ["Content-Disposition"],
    expectedValues: ["Content-Transfer-Encoding": "7bit"]
)

let validator = MIMEValidator(expectations: [expectation])
let result = try validator.validate(mimeString)

print(result.summary)  // "✓ Validation passed" or "✗ Validation failed with N error(s)"
print(result.description)  // Detailed report with errors and warnings
```

### Validation Options

Configure validation behavior with various options:

```swift
// Require MIME-Version header
let validator = MIMEValidator(requireMimeVersion: true)

// Strict multipart validation (requires boundary and non-empty parts)
let validator = MIMEValidator(strictMultipart: true)

// Use default expectations for common content types
let validator = MIMEValidator.withDefaults()
```

### Validating Multipart Messages

The validator automatically validates all parts in multipart messages:

```swift
let multipartMessage = """
Content-Type: multipart/mixed; boundary="boundary123"

--boundary123
Content-Type: text/plain
Content-Transfer-Encoding: 7bit

First part
--boundary123
Content-Type: text/html
Content-Transfer-Encoding: quoted-printable

<p>Second part</p>
--boundary123--
"""

let plainExpectation = MIMEHeaderExpectation(
    contentType: "text/plain",
    requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
)

let htmlExpectation = MIMEHeaderExpectation(
    contentType: "text/html",
    requiredHeaders: ["Content-Type", "Content-Transfer-Encoding"]
)

let validator = MIMEValidator(expectations: [plainExpectation, htmlExpectation])
let result = try validator.validate(multipartMessage)

if result.isValid {
    print("All parts are valid!")
}
```

### Custom Validation Logic

You can add custom validation logic using a closure:

```swift
let expectation = MIMEHeaderExpectation(
    contentType: "text/plain",
    customValidator: { headers in
        // Check for custom header
        guard let customHeader = headers["X-Custom-Header"],
              customHeader == "required-value" else {
            return [.custom("X-Custom-Header must be 'required-value'")]
        }
        return []
    }
)

let validator = MIMEValidator(expectations: [expectation])
let result = try validator.validate(mimeString)
```

### Preset Expectations

The library includes preset expectations for common content types:

```swift
// Available presets:
// - MIMEHeaderExpectation.textPlain
// - MIMEHeaderExpectation.textHtml
// - MIMEHeaderExpectation.applicationJson
// - MIMEHeaderExpectation.multipartMixed
// - MIMEHeaderExpectation.multipartAlternative

let validator = MIMEValidator(expectations: [
    .textPlain,
    .textHtml,
    .applicationJson
])
```

### Validation Results

The `MIMEValidationResult` provides detailed information about validation:

```swift
let result = try validator.validate(mimeString)

// Check if valid
if result.isValid {
    print("Valid!")
}

// Get errors (empty if valid)
for error in result.errors {
    print("Error: \(error)")
}

// Get warnings (non-fatal issues)
for warning in result.warnings {
    print("Warning: \(warning)")
}

// Get summary
print(result.summary)  // "✓ Validation passed" or "✗ Validation failed with 2 error(s)"

// Get full description
print(result.description)  // Includes summary, errors, and warnings
```

### Validating Individual Parts

You can validate individual parts separately:

```swift
let message = try MIMEDecoder().decode(multipartMessage)
let part = message.parts[0]

let expectation = MIMEHeaderExpectation(
    contentType: "text/plain",
    requiredHeaders: ["Content-Type"]
)

let validator = MIMEValidator(expectations: [expectation])
let result = validator.validatePart(part, index: 0)

if result.isValid {
    print("Part is valid!")
}
```

## API Reference

### `MIMEValidator`

Validates MIME messages according to RFC 2045/2046 and custom rules.

#### Initialization

- `init(expectations: [MIMEHeaderExpectation] = [], requireMimeVersion: Bool = false, strictMultipart: Bool = true)`
  - Creates a validator with custom expectations
- `static func withDefaults(requireMimeVersion: Bool = false, strictMultipart: Bool = true) -> MIMEValidator`
  - Creates a validator with default expectations for common content types

#### Methods

- `func validate(_ message: MIMEMessage) -> MIMEValidationResult`
  - Validates a parsed MIME message
- `func validate(_ content: String) throws -> MIMEValidationResult`
  - Parses and validates a MIME message string
- `func validatePart(_ part: MIMEPart, index: Int = 0) -> MIMEValidationResult`
  - Validates a specific part of a message

### `MIMEHeaderExpectation`

Defines header expectations for a specific content type.

#### Initialization

- `init(contentType: String, requiredHeaders: Set<String> = [], recommendedHeaders: Set<String> = [], expectedValues: [String: String] = [:], customValidator: ((MIMEHeaders) -> [MIMEValidationError])? = nil)`
  - Creates a header expectation for a content type

#### Presets

- `.textPlain` - Expectation for text/plain content
- `.textHtml` - Expectation for text/html content
- `.applicationJson` - Expectation for application/json content
- `.multipartMixed` - Expectation for multipart/mixed content
- `.multipartAlternative` - Expectation for multipart/alternative content

### `MIMEValidationResult`

The result of a validation operation.

#### Properties

- `isValid: Bool` - Whether the validation passed
- `errors: [MIMEValidationError]` - List of validation errors (empty if valid)
- `warnings: [String]` - List of validation warnings (non-fatal issues)
- `summary: String` - A human-readable summary
- `description: String` - A detailed description including errors and warnings

#### Factory Methods

- `static func success(warnings: [String] = []) -> MIMEValidationResult`
  - Creates a successful validation result
- `static func failure(errors: [MIMEValidationError], warnings: [String] = []) -> MIMEValidationResult`
  - Creates a failed validation result

### `MIMEValidationError`

Errors that can occur during validation.

#### Cases

- `missingRequiredHeader(String)` - A required header is missing
- `invalidHeaderValue(header: String, expected: String, actual: String?)` - A header value doesn't match expected format
- `invalidContentType(String)` - Content-Type header is missing or invalid
- `missingBoundary` - Multipart message is missing boundary parameter
- `emptyMultipart` - Multipart message has no parts
- `invalidPartIndex(Int)` - Part index is out of bounds
- `partMissingHeader(partIndex: Int, header: String)` - A part is missing required headers
- `partInvalidHeaderValue(partIndex: Int, header: String, expected: String, actual: String?)` - A part has an invalid header value
- `custom(String)` - Custom validation error


### `MIMEDecoder`

The main entry point for parsing MIME messages. Supports both multipart messages (with boundaries) and non-multipart messages.

#### Methods

- `decode(_: Data) throws -> MIMEMessage` - Decode a MIME message from data
- `decode(_: String) throws -> MIMEMessage` - Decode a MIME message from a string

### `MIMEHeaderAttributes`

Represents parsed attributes from a header value. Many MIME headers contain a primary value followed by semicolon-separated attributes.

#### Properties

- `value: String` - The primary value before any attributes
- `all: [String: String]` - Dictionary of all parsed attributes (keys are lowercased)

#### Methods

- `static func parse(_ headerValue: String?) -> MIMEHeaderAttributes`
  - Parses a header value into its primary value and attributes
  - Handles quoted and unquoted attribute values
  - Normalizes attribute names to lowercase for case-insensitive access
- `subscript(key: String) -> String?`
  - Access an attribute by name (case-insensitive)
  - Returns nil if the attribute doesn't exist

#### Example

```swift
let attrs = MIMEHeaderAttributes.parse("text/plain; charset=utf-8; format=flowed")
print(attrs.value)        // "text/plain"
print(attrs["charset"])   // "utf-8"
print(attrs["CHARSET"])   // "utf-8" (case-insensitive)
print(attrs["format"])    // "flowed"
print(attrs.all)          // ["charset": "utf-8", "format": "flowed"]
```

### `MIMEMessage`

Represents a complete MIME message with headers and parts.

#### Properties

- `headers: MIMEHeaders` - The top-level headers
- `parts: [MIMEPart]` - The individual parts of the message
- `body: String?` - The body content for non-multipart messages (returns nil for multipart messages)

#### Methods

- `func parts(withContentType contentType: String) -> [MIMEPart]`
  - Returns all parts with a specific content type
- `func firstPart(withContentType contentType: String) -> MIMEPart?`
  - Returns the first part with a specific content type
- `func hasPart(withContentType contentType: String) -> Bool`
  - Returns true if any part has the specified content type
- `func parts(withContentDispositionName name: String) -> [MIMEPart]`
  - Returns all parts with a specific content-disposition name
- `func firstPart(withContentDispositionName name: String) -> MIMEPart?`
  - Returns the first part with a specific content-disposition name
- `func part(named name: String) -> MIMEPart?`
  - Convenience method that returns the first part with a specific content-disposition name
- `func hasPart(withContentDispositionName name: String) -> Bool`
  - Returns true if any part has the specified content-disposition name
- `func headerAttributes(_ headerName: String) -> MIMEHeaderAttributes`
  - Parses attributes from any header value
- `func encode() -> Data`
  - Encodes the message back to MIME format data

### `MIMEPart`

Represents a single part of a multipart MIME message.

#### Properties

- `headers: MIMEHeaders` - The headers for this part
- `body: String` - The body content (empty for multipart parts with nested parts)
- `parts: [MIMEPart]` - Nested parts for multipart MIME types (empty for non-multipart parts)
- `decodedBody: String` - The decoded body content

#### Methods

- `func headerAttributes(_ headerName: String) -> MIMEHeaderAttributes`
  - Parses attributes from any header value
- `func encode() -> Data`
  - Encodes the part back to MIME format data

### `MIMEHeaders`

A case-insensitive collection for MIME headers with support for duplicate header names.

#### Methods

- `subscript(key: String) -> String?` - Access headers by name (case-insensitive). Returns the first value when multiple headers with the same name exist. Setting a value replaces all existing headers with that name.
- `func values(for key: String) -> [String]` - Returns all values for a given header name, useful for headers that can appear multiple times (e.g., `Received`)
- `func add(_ key: String, value: String)` - Adds a header without replacing existing headers with the same name
- `func removeAll(_ key: String)` - Removes all headers with the given name
- `func contains(_ key: String) -> Bool` - Check if a header exists
- Conforms to `Collection`, so you can iterate over headers

### `MIMEEncoder`

Encodes MIME messages to data.

#### Methods

- `encode(_: MIMEMessage) -> Data` - Encode a MIME message to data
- `encode(_: MIMEPart) -> Data` - Encode a MIME part to data

Example:
```swift
let encoder = MIMEEncoder()
let data = encoder.encode(message)
```

### `MIMEError`

Errors that can occur during parsing.

#### Cases

- `invalidFormat` - The MIME message format is invalid
- `invalidEncoding` - The character encoding is invalid or unsupported
- `invalidUTF8` - The data cannot be decoded as UTF-8
- `noHeaders` - The MIME message has no headers

## Testing

Run the test suite:

```bash
swift test
```

## License

[Your License Here]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
