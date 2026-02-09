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
        static let cornerRadius: CGFloat = 14
        static let contentPadding: CGFloat = 16

        /// Smaller padding used for compact banners.
        static let bannerHorizontalPadding: CGFloat = 16
        static let bannerVerticalPadding: CGFloat = 10

        /// Padding used for compact pills.
        static let pillHorizontalPadding: CGFloat = 10
        static let pillVerticalPadding: CGFloat = 6

        static let outerStrokeWidth: CGFloat = 0.5
        static let innerStrokeWidth: CGFloat = 0.5

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

        static let shadowRadius: CGFloat = 14
        static let shadowYOffset: CGFloat = 8

        /// When Reduce Transparency is enabled, we fall back to an opaque background.
        static func backgroundFallbackOpacity(contrast: ColorSchemeContrast) -> Double {
            switch contrast {
            case .increased: return 0.92
            default: return 0.86
            }
        }
    }
}
