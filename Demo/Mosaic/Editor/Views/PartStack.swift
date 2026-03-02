import SwiftUI

struct PartStack: View {
    @Environment(EditorModel.self) var editor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(editor.parts.enumerated()), id: \.element.id) { index, part in
                PartView(
                    part: part,
                    canMoveUp: index > 0,
                    canMoveDown: index < editor.parts.count - 1
                ) {
                    editor.movePartUp(at: index)
                } onMoveDown: {
                    editor.movePartDown(at: index)
                } onDelete: {
                    editor.removePart(at: index)
                }
            }
        }
        .padding()
    }
}
