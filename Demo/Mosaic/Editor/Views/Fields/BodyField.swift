import SwiftUI

struct BodyField: View {
    @Binding var text: String

    var focus: FocusState<EditorFocus?>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text.isEmpty ? " " : text)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .padding(.leading, 5)
                .opacity(0)

            TextEditor(text: $text)
                .focused(focus, equals: .body)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 18, idealHeight: 18)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Text (optional)")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
        }
    }
}
