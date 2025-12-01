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

// Convenient access to body for non-multipart messages
if let body = message.body {
    print(body)  // "This is a simple text message..."
}

// Or access via parts array
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

### Editing and Encoding MIME Messages

MIME messages and parts have mutable properties, making them easy to edit. Once edited, you can encode them back to MIME format.

#### Editing Headers

```swift
var message = try MIMEParser.parse(mimeString)

// Edit top-level headers
message.headers["From"] = "new-sender@example.com"
message.headers["Subject"] = "Updated subject"

// Edit part headers
message.parts[0].headers["Content-Type"] = "text/html"
```

#### Editing Body Content

```swift
var message = try MIMEParser.parse(mimeString)

// Edit part body
message.parts[0].body = "This is the new content!"

// For non-multipart messages, edit the single part
if message.parts.count == 1 {
    message.parts[0].body = "New simple message content"
}
```

#### Adding and Removing Parts

```swift
var message = try MIMEParser.parse(mimeString)

// Add a new part
var newPartHeaders = MIMEHeaders()
newPartHeaders["Content-Type"] = "text/plain"
let newPart = MIMEPart(headers: newPartHeaders, body: "New part content")
message.parts.append(newPart)

// Remove a part
message.parts.remove(at: 1)
```

#### Encoding Back to MIME Format

After editing, encode the message back to a string:

```swift
var message = try MIMEParser.parse(mimeString)

// Make some edits
message.headers["From"] = "updated@example.com"
message.parts[0].body = "Updated content"

// Encode back to MIME format
let encodedString = message.encode()
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

let encodedPart = part.encode()
print(encodedPart)
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
let message = try MIMEParser.parse(multipartMessage)
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
- `body: String?` - The body content for non-multipart messages (returns nil for multipart messages)
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
- `func encode() -> String`
  - Encodes the message back to MIME format string

### `MIMEPart`

Represents a single part of a multipart MIME message.

#### Properties

- `headers: MIMEHeaders` - The headers for this part
- `body: String` - The body content
- `contentType: String?` - The content type (e.g., "text/plain")
- `charset: String?` - The charset (e.g., "utf-8")
- `decodedBody: String` - The decoded body content

#### Methods

- `func encode() -> String`
  - Encodes the part back to MIME format string

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
