import SwiftUI

struct DateField: View {
    let key: String

    @Binding var date: Date

    @State private var text = ""

    @FocusState var focused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(key):")
                .foregroundStyle(.secondary)

            TextField(key, text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
        }
        .padding(.horizontal)
        .padding(.vertical, 14)
        .onChange(of: focused) { _, _ in
            guard focused == false else { return }
            validate()
        }
        .onAppear {
            text = formatted(date)
        }
    }

    func validate() {
        if let parsed = parse(text) {
            date = parsed
        }
        text = formatted(date)
    }

    func formatted(_ date: Date) -> String {
        date.formatted(date: .long, time: .shortened)
    }

    func parse(_ string: String) -> Date? {
        return LiberalDateParser.parse(string)
    }
}
