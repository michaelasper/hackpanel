import SwiftUI

/// Capsule-shaped liquid-glass surface for compact status pills.
///
/// Keeps pill styling consistent and avoids one-off stroke/shadow values.
struct GlassPill<Content: View>: View {
    let accent: Color?
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    private var shape: Capsule { Capsule(style: .continuous) }

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
            .overlay {
                if let accent {
                    shape
                        .fill(accent.opacity(0.10))
                }
            }
            .overlay {
                if let accent {
                    shape
                        .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                }
            }
            .shadow(
                color: .black.opacity(AppTheme.Glass.shadowOpacity(contrast: colorSchemeContrast)),
                radius: AppTheme.Glass.shadowRadius,
                x: 0,
                y: AppTheme.Glass.shadowYOffset
            )
    }

    private var strokeColor: Color {
        if reduceTransparency { return Color(nsColor: .separatorColor) }
        return .white
    }

    private var outerStrokeOpacity: Double {
        if reduceTransparency { return AppTheme.Glass.fallbackStrokeOpacity(contrast: colorSchemeContrast) }
        return AppTheme.Glass.outerStrokeOpacity(contrast: colorSchemeContrast)
    }

    private var innerStrokeOpacity: Double {
        if reduceTransparency { return AppTheme.Glass.fallbackStrokeOpacity(contrast: colorSchemeContrast) * 0.55 }
        return AppTheme.Glass.innerStrokeOpacity(contrast: colorSchemeContrast)
    }
}
