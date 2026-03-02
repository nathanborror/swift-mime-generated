import SwiftUI

struct PartStack: View {
    @Bindable var model: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(model.parts.enumerated()), id: \.element.id) { index, part in
                PartView(
                    part: part,
                    canMoveUp: index > 0,
                    canMoveDown: index < model.parts.count - 1
                ) {
                    model.movePartUp(at: index)
                } onMoveDown: {
                    model.movePartDown(at: index)
                } onDelete: {
                    model.removePart(at: index)
                }
            }
        }
        .padding()
    }
}
