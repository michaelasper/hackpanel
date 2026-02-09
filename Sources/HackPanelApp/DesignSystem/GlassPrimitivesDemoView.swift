import SwiftUI

/// Simple showcase for liquid glass primitives.
///
/// Not currently linked from the app; intended for previews and quick manual testing.
struct GlassPrimitivesDemoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Liquid Glass")
                .font(.system(.title, design: .rounded).weight(.semibold))

            HStack(spacing: 16) {
                GlassSurface {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GlassSurface")
                            .font(.headline)
                        Text("Raw surface primitive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(AppTheme.Glass.contentPadding)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GlassCard")
                            .font(.headline)
                        Text("Standard padded card")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview("Liquid Glass Demo") {
    GlassPrimitivesDemoView()
        .padding(24)
        .frame(width: 720, height: 360)
}
