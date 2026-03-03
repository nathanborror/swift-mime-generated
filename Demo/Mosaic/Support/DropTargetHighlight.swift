import SwiftUI

struct DropTargetHighlight: ViewModifier {
    let isEnabled: Bool

    @Binding var isHovering: Bool
    @State private var globalFrame: CGRect = .zero
    @State private var localSize: CGSize = .zero

    func body(content: Content) -> some View {
        content
            // Capture this view’s global frame so we can test against the drop location.
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            globalFrame = proxy.frame(in: .global)
                            localSize = proxy.size
                        }
                        .onChange(of: proxy.frame(in: .global)) { _, newValue in
                            globalFrame = newValue
                        }
                        .onChange(of: proxy.size) { _, newValue in
                            localSize = newValue
                        }
                }
            )
            // Session-wide updates while a drop is moving over this subtree.
            #if os(macOS)
            .onDropSessionUpdated { session in
                guard isEnabled else {
                    isHovering = false
                    return
                }

                switch session.phase {
                case .entering, .active:
                    // `DropSession.location` has shifted semantics across API generations.
                    // Accept either global or local coordinates.
                    let localBounds = CGRect(origin: .zero, size: localSize)
                    let point = session.location
                    isHovering = globalFrame.contains(point) || localBounds.contains(point)
                case .exiting, .ended, .dataTransferCompleted:
                    isHovering = false
                @unknown default:
                    isHovering = false
                }
            }
            #endif
            .onDisappear {
                isHovering = false
            }
    }
}

extension View {
    func dropHoverHighlight(isEnabled: Bool, isHovering: Binding<Bool>) -> some View {
        modifier(DropTargetHighlight(isEnabled: isEnabled, isHovering: isHovering))
    }
}
