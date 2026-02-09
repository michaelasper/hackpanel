import SwiftUI

/// Minimal in-app demo for the Liquid Glass primitives.
///
/// This intentionally lives in-app (not just previews) so changes can be validated quickly
/// during early UI refactors.
struct GlassPrimitivesDemoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Liquid Glass")
                .font(.headline)

            Text("GlassSurface is the lowest-level primitive. GlassCard is a convenience wrapper for typical padded containers.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.35),
                        Color.purple.opacity(0.25),
                        Color.blue.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                GlassSurface {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("GlassSurface")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("P0")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.white.opacity(0.10), in: Capsule())
                        }

                        Text("Single source of truth for material + border highlight + elevation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button("Primary") {}
                                .buttonStyle(.borderedProminent)
                            Button("Secondary") {}
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(AppTheme.Glass.contentPadding)
                }
                .padding(14)
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }
        }
    }
}
