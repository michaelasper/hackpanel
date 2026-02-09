import SwiftUI

/// Centralized design tokens for HackPanel.
///
/// Keep this intentionally small and composable. Higher-level components should be built
/// on top of these primitives (e.g. GlassSurface / GlassCard) rather than hard-coding
/// paddings, radii, and opacities throughout views.
enum AppTheme {
    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
    }

    enum Glass {
        /// Default internal padding for glass containers.
        static let contentPadding: CGFloat = 14

        /// Corner radius for glass surfaces.
        static let cornerRadius: CGFloat = AppTheme.Radius.md

        /// Border width for glass surfaces.
        static let borderWidth: CGFloat = 1

        /// Border opacity for the highlight edge.
        static let borderOpacity: CGFloat = 0.22

        /// Shadow strength for elevation.
        static let shadowOpacity: CGFloat = 0.18
        static let shadowRadius: CGFloat = 18
        static let shadowYOffset: CGFloat = 8
    }
}
