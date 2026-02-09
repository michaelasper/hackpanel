import SwiftUI
import AppKit

struct ConnectionBannerData: Equatable, Sendable {
    var stateText: String

    /// Short, user-facing summary (line-limited in the banner).
    var message: String?

    /// Full error text (copyable / viewable). If nil, we fall back to `message`.
    var fullMessage: String?

    /// e.g. "Last error at 5:31:22 PM"
    var timestampText: String?

    var color: Color
    var icon: String

    /// Whether the banner should offer an "Open Settings" affordance.
    var showsOpenSettings: Bool = false

    static func connected() -> ConnectionBannerData {
        ConnectionBannerData(
            stateText: "Connected",
            message: nil,
            fullMessage: nil,
            timestampText: nil,
            color: .green,
            icon: "checkmark.circle.fill",
            showsOpenSettings: false
        )
    }
}

struct ConnectionBannerView: View {
    let data: ConnectionBannerData

    var onOpenSettings: (() -> Void)? = nil

    @State private var isShowingDetails: Bool = false

    var body: some View {
        GlassSurface {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: data.icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(data.color)
                    .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }

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

                Spacer(minLength: 12)

                if let ts = data.timestampText {
                    Text(ts)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if hasDetailsOrCopy {
                    Button("Details") { isShowingDetails = true }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .popover(isPresented: $isShowingDetails) {
                            errorDetailsView
                        }
                }

                if data.showsOpenSettings, let onOpenSettings {
                    Button("Open Settings") { onOpenSettings() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
            .padding(.horizontal, AppTheme.Glass.bannerHorizontalPadding)
            .padding(.vertical, AppTheme.Glass.bannerVerticalPadding)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .contextMenu {
            if hasDetailsOrCopy {
                Button("Copy Error") { copyToPasteboard(errorText) }
            }
            if data.showsOpenSettings, let onOpenSettings {
                Button("Open Settings") { onOpenSettings() }
            }
        }
    }

    private var errorText: String {
        (data.fullMessage ?? data.message) ?? ""
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private var hasDetailsOrCopy: Bool {
        !errorText.isEmpty
    }

    private var errorDetailsView: some View {
        let text = errorText
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Gateway Error")
                    .font(.headline)
                Spacer()
                Button("Copy") { copyToPasteboard(text) }
            }

            ScrollView {
                Text(text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(.body, design: .monospaced))
            }
            .frame(width: 520, height: 220)

            if let ts = data.timestampText {
                Text(ts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["Gateway", data.stateText]
        if let message = data.message, !message.isEmpty { parts.append(message) }
        if let ts = data.timestampText { parts.append(ts) }
        return parts.joined(separator: ", ")
    }
}
