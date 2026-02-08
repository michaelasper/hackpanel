import SwiftUI

struct ConnectionBannerData: Equatable, Sendable {
    var stateText: String
    var message: String?
    var timestampText: String?

    var color: Color
    var icon: String

    static func connected() -> ConnectionBannerData {
        ConnectionBannerData(
            stateText: "Connected",
            message: nil,
            timestampText: nil,
            color: .green,
            icon: "checkmark.circle.fill"
        )
    }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts: [String] = ["Gateway", data.stateText]
        if let message = data.message, !message.isEmpty { parts.append(message) }
        if let ts = data.timestampText { parts.append(ts) }
        return parts.joined(separator: ", ")
    }
}
