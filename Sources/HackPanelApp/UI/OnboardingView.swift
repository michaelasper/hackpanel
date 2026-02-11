import SwiftUI

struct OnboardingView: View {
    var onOpenSettings: () -> Void
    var onReconnect: (() -> Void)?

    @FocusState private var focusOpenSettings: Bool

    var body: some View {
        ContentUnavailableView {
            Label("Connect HackPanel to a Gateway", systemImage: "bolt.horizontal.circle")
        } description: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Open Settings to configure your Gateway URL and token. Once connected, this screen will go away automatically.")

                Text("Your token stays local and is never displayed again.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } actions: {
            Button("Open Settings") { onOpenSettings() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .keyboardShortcut(",", modifiers: .command)
                .focused($focusOpenSettings)
                .accessibilityHint("Opens Settings so you can configure the Gateway connection")

            if let onReconnect {
                Button("Reconnect") { onReconnect() }
                    .accessibilityHint("Retries connecting to the configured Gateway")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focusOpenSettings = true }
    }
}

#Preview {
    OnboardingView(onOpenSettings: {}, onReconnect: {})
}
