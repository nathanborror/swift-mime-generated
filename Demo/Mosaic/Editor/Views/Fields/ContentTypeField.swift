import SwiftUI

struct ContentTypeField: View {
    @Environment(EditorModel.self) var editor

    var body: some View {
        @Bindable var editor = editor
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Type:")
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Menu {
                    ForEach(MessageKind.allCases, id: \.self) { kind in
                        Button {
                            editor.kind = kind
                        } label: {
                            Text(kind.description)
                        }
                        .disabled(!editor.parts.isEmpty && !kind.isMultipart)
                    }
                } label: {
                    Token(id: .init(), title: editor.kind.description, symbol: "chevron.up.chevron.down")
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)

                if editor.isMultipart {
                    Image(systemName: "chevron.compact.right")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(editor.parts) { part in
                            partPill(for: part)
                        }
                    }

                    Menu {
                        ForEach(PartKind.allCases, id: \.self) { kind in
                            Button(kind.description) {
                                editor.addPart(kind)
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

    func partPill(for part: PartModel) -> some View {
        Token(id: part.id, title: part.kind.description)
            .pointerStyle(.grabIdle)
            .draggable(part.id.uuidString) {
                Token(id: part.id, title: part.kind.description)
            }
    }
}
