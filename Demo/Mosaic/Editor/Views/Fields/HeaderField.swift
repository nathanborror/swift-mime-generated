import SwiftUI
import MIME

struct HeaderField: View {
    let key: String

    @Binding var value: String

    var onRemove: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(key):")
                .foregroundStyle(.secondary)
            TextField("", text: $value, prompt: nil)
                .textFieldStyle(.plain)

            if let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
    }
}
