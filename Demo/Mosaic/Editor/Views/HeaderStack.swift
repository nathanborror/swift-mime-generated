import SwiftUI
import MIME

struct HeaderStack: View {
    @Environment(EditorModel.self) var editor

    var focus: FocusState<EditorFocus?>.Binding

    var body: some View {
        @Bindable var editor = editor
        VStack(alignment: .leading, spacing: 0) {
            ContentTypeField()

            ForEach($editor.headers.storage) { $header in
                Divider()
                    .padding(.leading)
                HeaderField(key: header.key, value: $header.value, onRemove: {
                    editor.headers.removeAll(header.key)
                })
            }

            Divider()
                .padding(.leading)

            BodyField(text: $editor.body, focus: focus)
        }
    }
}
