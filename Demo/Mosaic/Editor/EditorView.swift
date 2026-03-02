import SwiftUI
import MIME

struct EditorView: View {

    @State var editorViewModel = EditorViewModel()
    @State private var isAddingHeader = false
    @State private var newHeaderName = ""
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
                    Menu {
                        Button("Date") {
                            editorViewModel.headers["Date"] = Date.now.rfc1123
                        }
                        Button("From") {
                            editorViewModel.headers["From"] = ""
                        }
                        Button("To") {
                            editorViewModel.headers["To"] = ""
                        }
                        Button("Subject") {
                            editorViewModel.headers["Subject"] = ""
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
        .alert("Add Header", isPresented: $isAddingHeader) {
            TextField("Header name", text: $newHeaderName)
            Button("Cancel", role: .cancel) {}
            Button("Add") {
                let name = newHeaderName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    editorViewModel.headers[name] = ""
                }
            }
        }
        .task {
            focus = .body
        }
    }
}
