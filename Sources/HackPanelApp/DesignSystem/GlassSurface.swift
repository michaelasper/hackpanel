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
            .background(
                AppTheme.Glass.surfaceBackgroundStyle(
                    reduceTransparency: reduceTransparency,
                    contrast: colorSchemeContrast
                ),
                in: shape
            )
            .overlay {
                shape
                    .strokeBorder(
                        strokeColor.opacity(outerStrokeOpacity),
                        lineWidth: AppTheme.Glass.outerStrokeWidth
                    )
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .strokeBorder(
                        strokeColor.opacity(innerStrokeOpacity),
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

    private var strokeColor: Color {
        // In Reduce Transparency mode we use semantic strokes that work in light/dark.
        if reduceTransparency { return Color(nsColor: .separatorColor) }
        return .white
    }

    private var outerStrokeOpacity: Double {
        if reduceTransparency { return AppTheme.Glass.fallbackStrokeOpacity(contrast: colorSchemeContrast) }
        return AppTheme.Glass.outerStrokeOpacity(contrast: colorSchemeContrast)
    }

    private var innerStrokeOpacity: Double {
        if reduceTransparency {
            // Slightly softer inner stroke in fallback mode.
            return AppTheme.Glass.fallbackStrokeOpacity(contrast: colorSchemeContrast) * 0.55
        }
        return AppTheme.Glass.innerStrokeOpacity(contrast: colorSchemeContrast)
    }
}
