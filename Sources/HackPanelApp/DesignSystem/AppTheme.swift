import SwiftUI

/// Centralized UI tokens for HackPanel.
///
/// Keep this intentionally small and pragmatic: only tokens we actively use.
enum AppTheme {
    enum Layout {
        /// Standard spacing between stacked groups.
        static let stackSpacing: CGFloat = 16

        /// Standard outer padding for top-level screens.
        static let pagePadding: CGFloat = 24

        /// Default vertical spacing between top-level sections on a screen.
        static let sectionSpacing: CGFloat = 12

        /// Default vertical padding for list rows.
        static let rowVerticalPadding: CGFloat = 6

        /// Compact row spacing for dense lists.
        static let rowVerticalPaddingCompact: CGFloat = 4
    }

    enum Typography {
        static let pageTitle: Font = .largeTitle.weight(.semibold)
        static let sectionTitle: Font = .title3.weight(.semibold)
        static let bodyEmphasis: Font = .body.weight(.medium)
        static let captionLabel: Font = .caption.weight(.medium)
        static let captionEmphasis: Font = .caption.weight(.semibold)
    }

    enum Glass {
        // MARK: - Raw geometry tokens (keep small)

        static let cornerRadius: CGFloat = 14
        static let contentPadding: CGFloat = 16

        /// Smaller padding used for compact banners.
        static let bannerHorizontalPadding: CGFloat = 16
        static let bannerVerticalPadding: CGFloat = 10

        /// Padding used for compact pills.
        static let pillHorizontalPadding: CGFloat = 10
        static let pillVerticalPadding: CGFloat = 6

        // MARK: - Semantic Liquid Glass tokens (anti-sprawl)
        /// Prefer these semantic helpers from views (vs ad-hoc `.white.opacity(…)`, magic shadow values, etc.).
        ///
        /// Goal: keep the API surface small, but expressive enough that screens don't invent one-off constants.

        static let outerStrokeWidth: CGFloat = 0.5
        static let innerStrokeWidth: CGFloat = 0.5

        static func outerStrokeColor(contrast: ColorSchemeContrast) -> Color {
            .white.opacity(outerStrokeOpacity(contrast: contrast))
        }

        static func innerStrokeColor(contrast: ColorSchemeContrast) -> Color {
            .white.opacity(innerStrokeOpacity(contrast: contrast))
        }

        static func shadowColor(contrast: ColorSchemeContrast) -> Color {
            .black.opacity(shadowOpacity(contrast: contrast))
        }

        struct ShadowToken: Sendable {
            let radius: CGFloat
            let yOffset: CGFloat
        }

        /// Current elevation tier for glass cards/surfaces.
        /// If we add more tiers, keep them here so the app stays consistent.
        static func elevation(contrast: ColorSchemeContrast) -> ShadowToken {
            switch contrast {
            case .increased:
                return ShadowToken(radius: 14, yOffset: 8)
            default:
                return ShadowToken(radius: 14, yOffset: 8)
            }
        }

        static func outerStrokeOpacity(contrast: ColorSchemeContrast) -> Double {
            switch contrast {
            case .increased: return 0.28
            default: return 0.15
            }
        }

        static func innerStrokeOpacity(contrast: ColorSchemeContrast) -> Double {
            switch contrast {
            case .increased: return 0.12
            default: return 0.06
            }
        }

        static func shadowOpacity(contrast: ColorSchemeContrast) -> Double {
            switch contrast {
            case .increased: return 0.18
            default: return 0.10
            }
        }

        // Shadow / elevation (single tier for now)
        static let shadowRadius: CGFloat = 14
        static let shadowYOffset: CGFloat = 8

        // Reduce Transparency fallback
        // When Reduce Transparency is enabled we avoid blur entirely and instead use
        // a solid semantic background + subtle border so text stays legible in light/dark.
        static let backgroundFallback: Color = Color(nsColor: .windowBackgroundColor)

        static func fallbackStrokeOpacity(contrast: ColorSchemeContrast) -> Double {
            switch contrast {
            case .increased: return 0.40
            default: return 0.26
            }
        }

        static func surfaceBackgroundStyle(
            reduceTransparency: Bool,
            contrast: ColorSchemeContrast
        ) -> AnyShapeStyle {
            _ = contrast
            if reduceTransparency {
                return AnyShapeStyle(backgroundFallback)
            }
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }
}
