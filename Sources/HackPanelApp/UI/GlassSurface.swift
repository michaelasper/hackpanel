import SwiftUI

/// The lowest-level "liquid glass" surface primitive.
///
/// Use this as the base for containers. Prefer `GlassCard` for typical padded cards.
struct GlassSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Glass.cornerRadius, style: .continuous))
            .overlay(glassBorder)
            .shadow(
                color: .black.opacity(AppTheme.Glass.shadowOpacity),
                radius: AppTheme.Glass.shadowRadius,
                x: 0,
                y: AppTheme.Glass.shadowYOffset
            )
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Glass.cornerRadius, style: .continuous)
            .fill(.thinMaterial)
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: AppTheme.Glass.cornerRadius, style: .continuous)
            .strokeBorder(
                Color.white.opacity(AppTheme.Glass.borderOpacity),
                lineWidth: AppTheme.Glass.borderWidth
            )
    }
}
