import Foundation
import MIME

@Observable
class PartModel: Identifiable {
    let id = UUID()
    var kind: PartKind
    var headers: [String: String]
    var body: String
    var isCollapsed: Bool

    init(kind: PartKind, headers: [String: String] = [:], body: String = "", isCollapsed: Bool = false) {
        self.kind = kind
        // Seed from the kind's template fields, then overlay any provided headers
        var seeded: [String: String] = [:]
        for field in kind.headerFields {
            seeded[field.key] = field.defaultValue
        }
        seeded.merge(headers) { _, new in new }
        self.headers = seeded
        self.body = body
        self.isCollapsed = isCollapsed
    }

    init(from part: MIMEPart) {
        let contentType = part.headerAttributes("Content-Type")
        self.kind = PartKind(contentType: contentType.value) ?? .note
        self.body = part.body
        self.isCollapsed = false
        self.headers = [:]
        for header in part.headers {
            // Skip Content-Type since it's derived from kind
            guard header.key != "Content-Type" else { continue }
            headers[header.key] = header.value
        }
    }

    var orderedHeaderKeys: [String] {
        let templateKeys = kind.headerFields.map(\.key)
        let templatePresent = templateKeys.filter { headers[$0] != nil }
        let custom = headers.keys.filter { key in !templateKeys.contains(key) }.sorted()
        return templatePresent + custom
    }

    var missingTemplateHeaders: [PartField] {
        kind.headerFields.filter { headers[$0.key] == nil }
    }

    func makeMIMEPart() -> MIMEPart {
        var mimeHeaders = MIMEHeaders()
        mimeHeaders["Content-Type"] = kind.contentType
        for (key, value) in headers where !value.isEmpty {
            mimeHeaders[key] = value
        }
        return MIMEPart(headers: mimeHeaders, body: body)
    }
}
