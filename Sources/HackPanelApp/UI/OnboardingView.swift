import SwiftUI

struct OnboardingView: View {
    var onOpenSettings: () -> Void
    var onReconnect: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Connect HackPanel to a Gateway", systemImage: "bolt.horizontal.circle")
        } description: {
            Text("Open Settings to configure your Gateway URL and token. Once connected, this screen will go away automatically.")
        } actions: {
            Button("Open Settings") { onOpenSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .accessibilityHint("Opens Settings so you can configure the Gateway connection")

            if let onReconnect {
                Button("Reconnect") { onReconnect() }
                    .accessibilityHint("Retries connecting to the configured Gateway")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView(onOpenSettings: {}, onReconnect: {})
}
