import SwiftUI
import MIME

struct EditorView: View {

    @State var editor = EditorModel()
    @State private var isAddingHeader = false
    @State private var newHeaderName = ""
    @FocusState var focus: EditorFocus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderStack(focus: $focus)
                .background(.background)

            if editor.isMultipart {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PartStack()
                    }
                }
            } else {
                Spacer()
            }
        }
        .environment(editor)
        .containerBackground(.background, for: .window)
        .background(.quinary.opacity(editor.isMultipart ? 1 : 0))
        .toolbar {
            ToolbarItem {
                Menu {
                    Menu {
                        Button("Date") {
                            editor.headers["Date"] = Date.now.rfc1123
                        }
                        Button("From") {
                            editor.headers["From"] = ""
                        }
                        Button("To") {
                            editor.headers["To"] = ""
                        }
                        Button("Subject") {
                            editor.headers["Subject"] = ""
                        }
                        Divider()
                        Button("Custom...") {
                            newHeaderName = ""
                            isAddingHeader = true
                        }
                    } label: {
                        Text("Add Header")
                    }
                    Divider()
                    Button("Reset") {
                        editor.headers = .init()
                        editor.body = ""
                        editor.parts.removeAll()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem {
                Button {
                    let message = editor.makeMessage()
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
        .alert("Add Header", isPresented: $isAddingHeader) {
            TextField("Header name", text: $newHeaderName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let name = newHeaderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    editor.headers[name] = ""
                }
            }
        }
        .task {
            focus = .body
        }
    }
}
