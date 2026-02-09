#!/usr/bin/env swift
import Foundation
import AppKit
import SwiftUI

// Generates a simple before/after PNG for the Liquid Glass PR1.
//
// Run:
//   Scripts/generate_liquid_glass_pr1_screenshots.swift

// MARK: - Legacy (pre-refactor) implementation for screenshots

private struct LegacyGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
    }
}

// MARK: - After implementation (aligned with the new primitives)

private enum AfterTokens {
    static let cornerRadius: CGFloat = 14

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

    static func backgroundFallbackOpacity(contrast: ColorSchemeContrast) -> Double {
        switch contrast {
        case .increased: return 0.92
        default: return 0.86
        }
    }
}

private struct AfterGlassCard<Content: View>: View {
    let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AfterTokens.cornerRadius, style: .continuous)
    }

    private var backgroundStyle: some ShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(
                Color(nsColor: .windowBackgroundColor)
                    .opacity(AfterTokens.backgroundFallbackOpacity(contrast: colorSchemeContrast))
            )
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }

    var body: some View {
        content
            .padding(16)
            .background(backgroundStyle, in: shape)
            .overlay {
                shape
                    .strokeBorder(
                        .white.opacity(AfterTokens.outerStrokeOpacity(contrast: colorSchemeContrast)),
                        lineWidth: 0.5
                    )
            }
            .overlay {
                shape
                    .inset(by: 1)
                    .strokeBorder(
                        .white.opacity(AfterTokens.innerStrokeOpacity(contrast: colorSchemeContrast)),
                        lineWidth: 0.5
                    )
            }
            .shadow(
                color: .black.opacity(AfterTokens.shadowOpacity(contrast: colorSchemeContrast)),
                radius: 14,
                x: 0,
                y: 8
            )
    }
}

// MARK: - Demo content

private struct CardContent: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Divider().opacity(0.3)

            HStack {
                Text("Connection")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Connected")
                    .font(.body.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BeforeAfterView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Liquid Glass PR1")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Before")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    LegacyGlassCard {
                        CardContent(title: "Gateway health", subtitle: "Legacy GlassCard")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("After")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    AfterGlassCard {
                        CardContent(title: "Gateway health", subtitle: "GlassSurface + AppTheme")
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 960, height: 420)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Rendering

@MainActor
private func renderPNG<V: View>(view: V, size: CGSize, url: URL) throws {
    let hosting = NSHostingView(rootView: view)
    hosting.frame = CGRect(origin: .zero, size: size)

    let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
    hosting.cacheDisplay(in: hosting.bounds, to: rep)

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"])
    }

    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: [.atomic])
}

@MainActor
func main() throws {
    let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Docs/Snapshots/liquid-glass-pr1", isDirectory: true)

    let out = outputDir.appendingPathComponent("before-after.png")
    try renderPNG(view: BeforeAfterView(), size: CGSize(width: 960, height: 420), url: out)

    print("Wrote: \(out.path)")
}

try await main()
