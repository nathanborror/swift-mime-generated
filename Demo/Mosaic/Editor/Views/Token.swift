import SwiftUI

struct Token: View {
    @Environment(EditorModel.self) var editor

    let id: UUID
    let title: String
    let symbol: String?

    @State private var isHighlighted = false

    init(id: UUID, title: String, symbol: String? = nil) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)

            if let symbol {
                Image(systemName: symbol)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, symbol != nil ? 8 : 10)
        .padding(.vertical, 4)
        .background(.quinary, in: .rect(cornerRadius: 6))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.blue.opacity(0.2), lineWidth: 2)
            }
        }
        .dropDestination(for: String.self, isEnabled: true) { ids, _ in
            isHighlighted = false
            guard let id = ids.first, let droppedPartID = UUID(uuidString: id) else {
                return
            }
            guard droppedPartID != self.id else {
                return
            }
            editor.movePart(fromID: droppedPartID, toID: self.id)
        }
        .dropConfiguration { session in
            DropConfiguration(operation: .move)
        }
        .dropHoverHighlight(isEnabled: true, isHovering: $isHighlighted)
    }
}
