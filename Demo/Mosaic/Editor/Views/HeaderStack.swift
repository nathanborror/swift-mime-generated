import SwiftUI
import MIME

struct HeaderStack: View {
    @Environment(EditorViewModel.self) var editorViewModel

    var focus: FocusState<EditorFocus?>.Binding

    var body: some View {
        @Bindable var editorViewModel = editorViewModel
        VStack(alignment: .leading, spacing: 0) {
            ContentTypeField()

            ForEach($editorViewModel.headers.storage) { $header in
                Divider()
                    .padding(.leading)
                HeaderField(key: header.key, value: $header.value)
            }

//            DateField(key: "Date", date: $model.headers["Date"])

            Divider()
                .padding(.leading)

            BodyField(
                text: Binding(get: {
                    editorViewModel.body
                },
                set: {
                    editorViewModel.body = $0
                }),
                focus: focus
            )
        }
    }
}
