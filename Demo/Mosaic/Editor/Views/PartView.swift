import SwiftUI

struct PartView: View {
    @Bindable var part: PartModel

    @FocusState private var focus: EditorFocus?

    var canMoveUp: Bool
    var canMoveDown: Bool
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        part.isCollapsed.toggle()
                    }
                } label: {
                    Image(systemName: part.isCollapsed ? "chevron.right" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.borderless)

                Spacer()

                Text(part.kind.description)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("Move Up", action: onMoveUp)
                        .disabled(!canMoveUp)

                    Button("Move Down", action: onMoveDown)
                        .disabled(!canMoveDown)

                    Divider()

                    Button("Add Custom Header") {
                        part.headers["X-Custom"] = ""
                    }

                    Divider()

                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                        .background(.background)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !part.isCollapsed {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(part.sortedHeaderKeys, id: \.self) { key in
                        HeaderField(
                            key: key,
                            value: headerBinding(for: key),
                            onRemove: {
                                part.headers.removeValue(forKey: key)
                            }
                        )
                        Divider()
                            .padding(.leading)
                    }

                    BodyField(text: $part.body, focus: $focus)
                }
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private func headerBinding(for key: String) -> Binding<String> {
        Binding(
            get: { part.headers[key] ?? "" },
            set: { part.headers[key] = $0 }
        )
    }
}
