import Foundation
import MIME

enum EditorFocus: Hashable {
    case body
}

@Observable
class EditorModel {
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

    func makeMessage() -> MIMEMessage {
        var headers = headers
        if isMultipart {
            let boundary = UUID().uuidString
            headers["Content-Type"] = "\(kind.contentType); boundary=\"\(boundary)\""
            let mimeParts = parts.map { $0.makeMIMEPart() }
            return MIMEMessage(headers: headers, parts: mimeParts)
        } else {
            headers["Content-Type"] = kind.contentType
            return MIMEMessage(headers: headers, body: body)
        }
    }

    func load(from message: MIMEMessage) {
        if let dateHeader = message.headers["Date"] {
            headers["Date"] = dateHeader
        }

        let contentType = message.headerAttributes("Content-Type")
        if let messageKind = MessageKind(contentType.value) {
            kind = messageKind
        } else {
            kind = .markdown
        }

        if isMultipart {
            parts = message.parts.map { PartModel(from: $0) }
            body = ""
        } else {
            body = message.body
            parts = []
        }
    }
}
