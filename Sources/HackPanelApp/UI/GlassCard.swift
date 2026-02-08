import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
    }
}
