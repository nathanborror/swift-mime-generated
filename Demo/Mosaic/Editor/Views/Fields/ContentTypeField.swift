import SwiftUI

struct ContentTypeField: View {
    @Environment(EditorViewModel.self) var editorViewModel

    var body: some View {
        @Bindable var editorViewModel = editorViewModel
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Type:")
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Menu {
                    ForEach(MessageKind.allCases, id: \.self) { kind in
                        Button {
                            editorViewModel.kind = kind
                        } label: {
                            Text(kind.description)
                        }
                        .disabled(!editorViewModel.parts.isEmpty && !kind.isMultipart)
                    }
                } label: {
                    Token(id: .init(), title: editorViewModel.kind.description, symbol: "chevron.up.chevron.down")
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)

                if editorViewModel.isMultipart {
                    Image(systemName: "chevron.compact.right")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(Array(editorViewModel.parts.enumerated()), id: \.element.id) { index, part in
                            messagePartPill(for: part, index: index)
                        }
                    }

                    Menu {
                        ForEach(PartKind.allCases, id: \.self) { kind in
                            Button(kind.description) {
                                editorViewModel.addPart(kind)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                            .background(.quinary, in: .rect(cornerRadius: 6))
                    }
                    .menuIndicator(.hidden)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    func messagePartPill(for part: PartModel, index: Int) -> some View {
        Token(id: part.id, title: part.kind.description)
            .pointerStyle(.grabIdle)
            .draggable(part.id.uuidString) {
                Token(id: part.id, title: part.kind.description)
            }
//        Menu {
//            Button("Move Up") {
//                model.movePartUp(at: index)
//            }
//            .disabled(index == 0)
//
//            Button("Move Down") {
//                model.movePartDown(at: index)
//            }
//            .disabled(index == model.parts.count - 1)
//
//            Divider()
//
//            Button("Delete") {
//                model.removePart(at: index)
//            }
//        } label: {
//            Token(title: part.kind.description)
//        }
//        .menuIndicator(.hidden)
//        .buttonStyle(.plain)
    }
}

struct Token: View {
    @Environment(EditorViewModel.self) var editorViewModel

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
            editorViewModel.movePart(fromID: droppedPartID, toID: self.id)
        }
        .dropConfiguration { session in
            DropConfiguration(operation: .move)
        }
        .dropHoverHighlight(isEnabled: true, isHovering: $isHighlighted)
    }
}
