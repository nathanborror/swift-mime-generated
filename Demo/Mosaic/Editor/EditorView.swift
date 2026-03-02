import SwiftUI
import MIME

struct EditorView: View {

    @State var editorViewModel = EditorViewModel()
    @FocusState var focus: EditorFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderStack(focus: $focus)
                .background(.background)

            if editorViewModel.isMultipart {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PartStack(model: editorViewModel)
                    }
                }
            } else {
                Spacer()
            }
        }
        .environment(editorViewModel)
        .containerBackground(.background, for: .window)
        .background(.quinary.opacity(editorViewModel.isMultipart ? 1 : 0))
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Add Date Header") {
                        editorViewModel.headers["Date"] = Date.now.rfc1123
                    }
                    Button("Add Custom Header") {
                        editorViewModel.headers["X-Custom"] = ""
                    }
                    Divider()
                    Button("Reset") {
                        editorViewModel.headers = .init()
                        editorViewModel.body = ""
                        editorViewModel.parts.removeAll()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem {
                Button {
                    let message = editorViewModel.buildMessage()
                    let encoder = MIMEEncoder()
                    let data = encoder.encode(message)
                    if let output = String(data: data, encoding: .utf8) {
                        print(output)
                    }
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            focus = .body
        }
    }
}
