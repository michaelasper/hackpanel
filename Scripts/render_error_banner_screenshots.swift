#!/usr/bin/env swift
import Foundation
import AppKit
import SwiftUI

// This script renders a few ConnectionBannerView states to PNGs for PR screenshots.
// Run from repo root: `swift Scripts/render_error_banner_screenshots.swift`

// Minimal copies of the banner types (so we can render without importing app targets).
struct ConnectionBannerData: Equatable {
    var stateText: String
    var message: String?
    var timestampText: String?

    var color: Color
    var icon: String
}

struct ConnectionBannerView: View {
    let data: ConnectionBannerData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: data.icon)
                .foregroundStyle(data.color)

            Text(data.stateText)
                .font(.subheadline.weight(.semibold))

            if let message = data.message, !message.isEmpty {
                Text("—")
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let ts = data.timestampText {
                Spacer()
                Text(ts)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(.separator), alignment: .bottom)
    }
}

struct RenderedBanner: View {
    let title: String
    let data: ConnectionBannerData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.top, 12)
                .padding(.horizontal, 14)

            ConnectionBannerView(data: data)
                .frame(width: 900)

            Spacer(minLength: 12)
        }
        .frame(width: 900, height: 120)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

func renderPNG<V: View>(_ view: V, size: CGSize, outURL: URL) throws {
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(origin: .zero, size: size)

    let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
    hosting.cacheDisplay(in: hosting.bounds, to: rep)

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "render", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG"]) 
    }
    try png.write(to: outURL)
}

let fm = FileManager.default
let outDir = URL(fileURLWithPath: fm.currentDirectoryPath)
    .appendingPathComponent("Docs")
    .appendingPathComponent("Screenshots")
try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

let samples: [(String, ConnectionBannerData)] = [
    (
        "Connected",
        ConnectionBannerData(stateText: "Connected", message: nil, timestampText: nil, color: .green, icon: "checkmark.circle.fill")
    ),
    (
        "Disconnected (last error)",
        ConnectionBannerData(stateText: "Disconnected", message: "Timed out while waiting for status response.", timestampText: now, color: .red, icon: "xmark.octagon.fill")
    ),
    (
        "Reconnecting",
        ConnectionBannerData(stateText: "Reconnecting", message: "Waiting for Gateway frame…", timestampText: now, color: .orange, icon: "arrow.triangle.2.circlepath.circle.fill")
    ),
    (
        "Auth failed",
        ConnectionBannerData(stateText: "Auth failed", message: "auth_failed: invalid token", timestampText: now, color: .red, icon: "lock.slash.fill")
    ),
]

for (name, data) in samples {
    let fileName = name
        .lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .replacingOccurrences(of: "(", with: "")
        .replacingOccurrences(of: ")", with: "")
        .replacingOccurrences(of: "/", with: "-")

    let url = outDir.appendingPathComponent("error-banner-\(fileName).png")
    let view = RenderedBanner(title: name, data: data)
    try renderPNG(view, size: CGSize(width: 900, height: 120), outURL: url)
    print("Wrote \(url.path)")
}
