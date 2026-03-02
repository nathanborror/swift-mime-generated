import Foundation
import MIME

enum EditorFocus: Hashable {
    case body
}

@Observable
class EditorViewModel {
    var kind: MessageKind = .markdown
    var headers: MIMEHeaders = ["Date": Date.now.rfc1123]
    var body = ""
    var parts: [PartModel] = []

    var isMultipart: Bool {
        kind.isMultipart
    }

    func addPart(_ kind: PartKind) {
        parts.append(PartModel(kind: kind))
    }

    func removePart(at index: Int) {
        guard parts.indices.contains(index) else { return }
        parts.remove(at: index)
    }

    func movePartUp(at index: Int) {
        guard index > 0, parts.indices.contains(index) else { return }
        parts.swapAt(index, index - 1)
    }

    func movePartDown(at index: Int) {
        guard parts.indices.contains(index), index < parts.count - 1 else { return }
        parts.swapAt(index, index + 1)
    }

    func movePart(fromID sourceID: UUID, toID destinationID: UUID) {
        guard let sourceIndex = parts.firstIndex(where: { $0.id == sourceID }),
              let destinationIndex = parts.firstIndex(where: { $0.id == destinationID }),
              sourceIndex != destinationIndex else { return }
        let part = parts.remove(at: sourceIndex)
        parts.insert(part, at: destinationIndex)
    }

    func buildMessage() -> MIMEMessage {
        var headers = headers
        if isMultipart {
            let boundary = UUID().uuidString
            headers["Content-Type"] = "\(kind.contentType); boundary=\"\(boundary)\""
            let envelope = MIMEPart(headers: headers, body: "")
            var mimeParts = [envelope]
            for part in parts {
                mimeParts.append(part.buildMIMEPart())
            }
            return MIMEMessage(mimeParts)
        } else {
            headers["Content-Type"] = kind.contentType
            let part = MIMEPart(headers: headers, body: body)
            return MIMEMessage([part])
        }
    }

    func load(from message: MIMEMessage) {
        guard let first = message.parts.first else { return }

        if let dateHeader = first.headers["Date"] {
            headers["Date"] = dateHeader
        }

        let contentType = first.headerAttributes("Content-Type")
        if let messageKind = MessageKind(contentType.value) {
            kind = messageKind
        } else {
            kind = .markdown
        }

        if isMultipart {
            parts = message.parts.dropFirst().map { PartModel(from: $0) }
            body = ""
        } else {
            body = first.body
            parts = []
        }
    }
}

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
            seeded[field.key] = ""
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

    var sortedHeaderKeys: [String] {
        headers.keys.sorted()
    }

    var removedTemplateHeaders: [String] {
        kind.headerFields.map(\.key).filter { headers[$0] == nil }
    }

    func buildMIMEPart() -> MIMEPart {
        var mimeHeaders = MIMEHeaders()
        mimeHeaders["Content-Type"] = kind.contentType
        for (key, value) in headers where !value.isEmpty {
            mimeHeaders[key] = value
        }
        return MIMEPart(headers: mimeHeaders, body: body)
    }
}
