import Foundation
import Testing

@testable import MIME

@Test("Header order preservation")
func headerOrderPreserved() async throws {
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

    let keys = message.parts[0].headers.map { $0.key }
    #expect(keys.count == 6)
    #expect(keys[0] == "From")
    #expect(keys[1] == "To")
    #expect(keys[2] == "Date")
    #expect(keys[3] == "Subject")
    #expect(keys[4] == "MIME-Version")
    #expect(keys[5] == "Content-Type")
}

@Test("Header order preservation after encoding")
func headerOrderEncoding() async throws {
    var headers = MIMEHeaders()
    headers["From"] = "sender@example.com"
    headers["To"] = "recipient@example.com"
    headers["Date"] = "Mon, 01 Jan 2024 12:00:00 -0800"
    headers["Subject"] = "Test Message"
    headers["MIME-Version"] = "1.0"
    headers["Content-Type"] = "text/plain"

    let message = MIMEMessage([.init(headers: headers, body: "")])
    let encoded = MIMEEncoder().encode(message)
    let reparsed = try MIMEDecoder().decode(encoded)

    let keys = reparsed.parts[0].headers.map { $0.key }
    #expect(keys.count == 6)
    #expect(keys[0] == "From")
    #expect(keys[1] == "To")
    #expect(keys[2] == "Date")
    #expect(keys[3] == "Subject")
    #expect(keys[4] == "MIME-Version")
    #expect(keys[5] == "Content-Type")
}

@Test("Headers on multiple lines")
func headerOnMultipleLines() async throws {
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
    #expect(message.parts[0].headers["From"]?.contains("Very Long Name") == true)
    #expect(message.parts[0].headers["From"]?.contains("very.long.email@example.com") == true)
    #expect(message.parts.count == 2)
}

@Test("Header collection")
func headerCollection() async throws {
    var headers = MIMEHeaders()
    headers["From"] = "test@example.com"
    headers["To"] = "recipient@example.com"
    headers["Subject"] = "Test"

    #expect(headers.count == 3)
    #expect(headers["From"] != "")

    var foundKeys: Set<String> = []
    for header in headers {
        foundKeys.insert(header.key)
    }
    #expect(foundKeys.count == 3)

    // Check ordering
    #expect(headers[0].key == "From")
    #expect(headers[1].key == "To")
    #expect(headers[2].key == "Subject")
}

@Test("Header decoding duplicates")
func headerDecodingDuplicates() async throws {
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
    #expect(message.parts[0].headers["Received"] == "from server1.example.com by server2.example.com")

    // values(for:) should return all values
    let receivedHeaders = message.parts[0].headers.values(for: "Received")
    #expect(receivedHeaders.count == 3)
    #expect(receivedHeaders[0] == "from server1.example.com by server2.example.com")
    #expect(receivedHeaders[1] == "from server2.example.com by server3.example.com")
    #expect(receivedHeaders[2] == "from server3.example.com by server4.example.com")
}

@Test("Header adding duplicates")
func headerAddingDuplicate() async throws {
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

@Test("Header subscript replaces all duplicates")
func headerSubscriptReplacesAllDuplicates() async throws {
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

@Test("Header remove all duplicates")
func headerRemoveAllDuplicates() async throws {
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

@Test("Header encoding duplicates")
func headerEncodingDuplicates() async throws {
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

@Test("Header round-trip with duplicates")
func headerRoundTripWithDuplicates() async throws {
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
    #expect(message.parts[0].headers.values(for: "Received").count == 3)

    // Encode back
    let encoded = MIMEEncoder().encode(message)

    // Parse again
    let reparsed = try MIMEDecoder().decode(encoded)

    // Verify all Received headers are preserved
    let receivedHeaders = reparsed.parts[0].headers.values(for: "Received")
    #expect(receivedHeaders.count == 3)
    #expect(receivedHeaders[0] == "from server1.example.com")
    #expect(receivedHeaders[1] == "from server2.example.com")
    #expect(receivedHeaders[2] == "from server3.example.com")
}

@Test("Header multipart duplicates")
func headerMultipartDuplicates() async throws {
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
    #expect(message.parts[0].headers.values(for: "Received").count == 2)

    // Check part-level duplicate headers
    #expect(message.parts[1].headers.values(for: "X-Custom").count == 2)
    #expect(message.parts[1].headers.values(for: "X-Custom")[0] == "custom1")
    #expect(message.parts[1].headers.values(for: "X-Custom")[1] == "custom2")
}

@Test("Header duplicates removing all")
func headerDuplicatesRemovingAll() async throws {
    var headers = MIMEHeaders()
    headers.add("X-Custom", value: "value1")
    headers.add("X-Custom", value: "value2")
    headers.add("X-Custom", value: "value3")

    #expect(headers.values(for: "X-Custom").count == 3)

    // Setting nil should remove all
    headers["X-Custom"] = nil

    #expect(headers["X-Custom"] == nil)
    #expect(headers.values(for: "X-Custom").isEmpty)
}

@Test("Header attributes")
func headerAttributes() async throws {
    let mimeContent = """
        Content-Type: multipart/mixed; boundary="test"; charset="utf-8"

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

    #expect(message.parts[0].headerAttributes("Content-Type")["boundary"] == "test")
    #expect(message.parts[0].headerAttributes("Content-Type")["charset"] == "utf-8")
    #expect(message.parts[1].headerAttributes("Content-Type")["charset"] == "utf-8")
    #expect(message.parts[2].headerAttributes("Content-Type")["charset"] == "iso-8859-1")
    #expect(message.parts[3].headerAttributes("Content-Type")["charset"] == nil)
}
