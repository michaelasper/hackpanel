import SwiftUI

/// Apple-style "liquid glass" surface: material + subtle strokes + shadow.
///
/// Accessibility:
/// - Reduce Transparency: removes blur, uses opaque background.
/// - Increase Contrast: strengthens strokes/shadow via `colorSchemeContrast`.
struct GlassSurface<Content: View>: View {
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AppTheme.Glass.cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .background(backgroundStyle, in: shape)
            .overlay {
                shape
                    .strokeBorder(
                        .white.opacity(AppTheme.Glass.outerStrokeOpacity(contrast: colorSchemeContrast)),
                        lineWidth: AppTheme.Glass.outerStrokeWidth
                    )
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .strokeBorder(
                        .white.opacity(AppTheme.Glass.innerStrokeOpacity(contrast: colorSchemeContrast)),
                        lineWidth: AppTheme.Glass.innerStrokeWidth
                    )
            }
            .shadow(
                color: .black.opacity(AppTheme.Glass.shadowOpacity(contrast: colorSchemeContrast)),
                radius: AppTheme.Glass.shadowRadius,
                x: 0,
                y: AppTheme.Glass.shadowYOffset
            )
    }

    private var backgroundStyle: some ShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(
                Color(nsColor: .windowBackgroundColor)
                    .opacity(AppTheme.Glass.backgroundFallbackOpacity(contrast: colorSchemeContrast))
            )
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}
