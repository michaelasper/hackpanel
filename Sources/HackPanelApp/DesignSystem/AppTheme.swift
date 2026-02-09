import SwiftUI

/// Centralized UI tokens for HackPanel.
///
/// Keep this intentionally small and pragmatic: only tokens we actively use.
enum AppTheme {
    enum Glass {
        static let cornerRadius: CGFloat = 14
        static let contentPadding: CGFloat = 16

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
