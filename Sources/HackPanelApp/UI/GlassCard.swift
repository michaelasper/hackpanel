import SwiftUI

/// Standard padded container for content on a glass surface.
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassSurface {
            content
                .padding(AppTheme.Glass.contentPadding)
        }
    }
}
