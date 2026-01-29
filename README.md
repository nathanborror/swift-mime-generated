# MIME

A Swift package for parsing and encoding MIME formatted data (RFC 2045/2046).

## Requirements

- iOS 18.0+ / macOS 15.0+
- Swift 6.2+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/nathanborror/swift-mime-generated.git", from: "1.0.0")
]
```

## Quick Example

```swift
import MIME

let mimeString = """
From: sender@example.com
Content-Type: multipart/mixed; boundary="example"

--example
Content-Type: text/plain

Hello, World!
--example--
"""

let message = try MIMEDecoder().decode(mimeString)

// Access headers and parts
print(message.headers["From"])        // "sender@example.com"
print(message.parts[0].body)          // "Hello, World!"

// Encode back to MIME format
let encoded = MIMEEncoder().encode(message)
```

## Documentation

For detailed usage examples, see the test files:

- `MIMETests.swift` - Decoding/encoding multipart and nested messages
- `MIMEHeaderTests.swift` - Working with headers and duplicate headers
- `MIMEAttributeTests.swift` - Parsing header attributes (charset, boundary, etc.)
