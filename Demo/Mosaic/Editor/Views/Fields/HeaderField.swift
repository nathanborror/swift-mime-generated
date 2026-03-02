import SwiftUI
import MIME

struct HeaderField: View {
    @Environment(EditorViewModel.self) var editorViewModel

    let key: String

    @Binding var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(key):")
                .foregroundStyle(.secondary)
            TextField("", text: $value, prompt: nil)
                .textFieldStyle(.plain)

            Button {
                editorViewModel.headers.removeAll(key)
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
