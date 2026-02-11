import SwiftUI
import HackPanelGateway
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @ObservedObject var gateway: GatewayConnectionStore

    // NOTE: OpenClaw Gateway multiplexes WS + HTTP on the same port (default 18789).
    // HackPanel will eventually use the Gateway WebSocket protocol (not plain REST).
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = GatewayDefaults.baseURLString
    @KeychainStorage("gatewayToken") private var gatewayToken: String = ""

    @AppStorage("gatewayAutoApply") private var gatewayAutoApply: Bool = true

    @State private var draftBaseURL: String = ""
    @State private var draftToken: String = ""
    @State private var validationError: String?
    @State private var hasEditedBaseURL: Bool = false

    @State private var copiedAt: Date?

    // Auto-apply / undo
    @State private var pendingApplyTask: Task<Void, Never>?
    @State private var lastAppliedAt: Date?
    @State private var undoSnapshot: (baseURL: String, token: String)?
    @State private var showAppliedToast: Bool = false

    private static let uiTimestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            Form {
                Section("Gateway") {
                    HStack(alignment: .center, spacing: 10) {
                        statusPill

                        Spacer()

                        Toggle("Auto-apply", isOn: $gatewayAutoApply)
                            .toggleStyle(.switch)
                    }

                    LabeledContent("Gateway URL") {
                        TextField("", text: $draftBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .help("Example: \(GatewayDefaults.baseURLString). If you omit a port, HackPanel assumes :\(GatewayDefaults.defaultPort).")
                            .onChange(of: draftBaseURL) { _, newValue in
                                hasEditedBaseURL = true
                                validationError = baseURLValidationMessage(for: newValue)
                                scheduleAutoApplyIfNeeded()
                            }
                            .onSubmit {
                                if !gatewayAutoApply {
                                    applyAndReconnect(userInitiated: true)
                                }
                            }
                    }

                    LabeledContent("Token") {
                        SecureField("", text: $draftToken)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: draftToken) { _, _ in
                                scheduleAutoApplyIfNeeded()
                            }
                    }

                    HStack {
                        if !gatewayAutoApply {
                            Button("Apply & Reconnect") {
                                applyAndReconnect(userInitiated: true)
                            }
                            .disabled(baseURLValidationMessage(for: draftBaseURL) != nil)
                        }

                        Button("Retry Now") {
                            gateway.retryNow()
                        }
                        .buttonStyle(.borderless)

                        Button("Reset to Default") {
                            draftBaseURL = GatewayDefaults.baseURLString
                            hasEditedBaseURL = true
                            validationError = baseURLValidationMessage(for: draftBaseURL)
                            scheduleAutoApplyIfNeeded(force: true)
                        }
                        .buttonStyle(.link)

                        Spacer()
                    }

                    if let validationError, hasEditedBaseURL {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if gatewayAutoApply {
                        Text("Changes apply automatically after a short pause. If the URL is invalid, nothing is applied.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("HackPanel connects to the OpenClaw Gateway WebSocket RPC endpoint (same port as HTTP; default 18789). Token is optional unless your gateway requires it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Diagnostics") {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Connection") {
                                Text(gateway.state.displayName)
                            }

                            LabeledContent("Last error") {
                                Text(gateway.lastErrorMessage ?? "(none)")
                                    .textSelection(.enabled)
                            }

                            if let at = gateway.lastErrorAt {
                                LabeledContent("Last error at") {
                                    Text(Self.uiTimestampFormatter.string(from: at))
                                }
                            }

                            if let until = reconnectBackoffUntil, until > Date() {
                                let remaining = max(0, Int(until.timeIntervalSince(Date()).rounded(.up)))
                                LabeledContent("Reconnect backoff") {
                                    Text("\(remaining)s")
                                }
                            }

                            Button {
                                copyToPasteboard(diagnosticsText)
                                copiedAt = Date()
                            } label: {
                                Label("Copy Diagnostics", systemImage: "doc.on.doc")
                            }

                            if let copiedAt {
                                Text("Copied at \(Self.uiTimestampFormatter.string(from: copiedAt)).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            GlassSurface {
                                ScrollView {
                                    Text(diagnosticsText)
                                        .textSelection(.enabled)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10)
                                }
                                .frame(minHeight: 180)
                            }

                            Text("Token is redacted (last-4 shown when available).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Appearance") {
                    GlassCard {
                        GlassPrimitivesDemoView()
                    }
                }
            }
            .padding(24)
            .onAppear {
                if draftBaseURL.isEmpty { draftBaseURL = gatewayBaseURL }
                if draftToken.isEmpty { draftToken = gatewayToken }
            }
            .onChange(of: gatewayAutoApply) { _, _ in
                // If user toggles auto-apply ON while dirty, apply soon.
                scheduleAutoApplyIfNeeded(force: true)
            }

            if showAppliedToast {
                appliedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 14)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showAppliedToast)
    }

    private func baseURLValidationMessage(for raw: String) -> String? {
        switch GatewaySettingsValidator.validateBaseURL(raw) {
        case .success:
            return nil
        case .failure(let error):
            return error.message
        }
    }

    private func scheduleAutoApplyIfNeeded(force: Bool = false) {
        pendingApplyTask?.cancel()
        pendingApplyTask = nil

        guard gatewayAutoApply else { return }

        // Only apply when Base URL is valid.
        let msg = baseURLValidationMessage(for: draftBaseURL)
        validationError = msg
        guard msg == nil else { return }

        // Avoid re-applying if nothing changed (unless explicitly forced).
        if !force {
            let trimmedBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedToken = draftToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedBaseURL == gatewayBaseURL && trimmedToken == gatewayToken {
                return
            }
        }

        pendingApplyTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                applyAndReconnect(userInitiated: false)
            }
        }
    }

    private var statusPill: some View {
        let (label, color) = pillStyle(for: gateway.state, lastError: gateway.lastErrorMessage)
        return Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private func pillStyle(for state: GatewayConnectionStore.State, lastError: String?) -> (String, Color) {
        switch state {
        case .connected:
            return ("Live", .green)
        case .reconnecting:
            return ("Applying…", .orange)
        case .authFailed:
            return ("Auth failed", .red)
        case .disconnected:
            // If we have an error message, make it red; otherwise neutral.
            if lastError != nil { return ("Error", .red) }
            return ("Disconnected", Color.secondary)
        }
    }

    private var appliedToast: some View {
        GlassSurface {
            HStack(spacing: 10) {
                Text("Applied")
                    .font(.caption.weight(.medium))

                if canUndo {
                    Button("Undo") {
                        undoLastApply()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Undo")
                    .accessibilityHint("Revert to the previous gateway URL and token")
                }

                Spacer(minLength: 0)

                Button {
                    showAppliedToast = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Dismiss")
                .accessibilityHint("Hide the Applied confirmation")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: 420)
    }

    private var canUndo: Bool {
        guard undoSnapshot != nil else { return false }
        guard let lastAppliedAt else { return false }
        return Date().timeIntervalSince(lastAppliedAt) <= 15
    }

    private func undoLastApply() {
        guard let snap = undoSnapshot else { return }
        draftBaseURL = snap.baseURL
        draftToken = snap.token
        hasEditedBaseURL = true
        validationError = baseURLValidationMessage(for: draftBaseURL)

        // Undo should immediately restore the previously-applied config and reconnect,
        // regardless of whether auto-apply is enabled.
        applyAndReconnect(userInitiated: true)
    }

    private func applyAndReconnect(userInitiated: Bool) {
        let trimmedBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = draftToken.trimmingCharacters(in: .whitespacesAndNewlines)

        let url: URL
        switch GatewaySettingsValidator.validateBaseURL(trimmedBaseURL) {
        case .success(let validated):
            url = validated
            validationError = nil
        case .failure(let error):
            validationError = error.message
            return
        }

        // Capture undo snapshot (previous persisted values) before mutating.
        undoSnapshot = (baseURL: gatewayBaseURL, token: gatewayToken)

        // Persist settings.
        gatewayBaseURL = trimmedBaseURL
        gatewayToken = trimmedToken

        // Apply immediately to the live connection store.
        let cfg = GatewayConfiguration(baseURL: url, token: trimmedToken.isEmpty ? nil : trimmedToken)
        gateway.updateClient(LiveGatewayClient(configuration: cfg))

        // Kick the connection loop immediately so users get fast feedback.
        gateway.retryNow()

        lastAppliedAt = Date()
        showAppliedToast = true

        // Auto-hide the toast after a bit (manual applies feel nicer w/ a longer window).
        let hideAfter: TimeInterval = userInitiated ? 6 : 3
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(hideAfter * 1_000_000_000))
            showAppliedToast = false
        }
    }

    private var diagnosticsText: String {
        DiagnosticsFormatter.format(
            .init(
                appVersion: appVersion,
                appBuild: appBuild,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceId: deviceId,
                gatewayBaseURL: gatewayBaseURL,
                gatewayToken: gatewayToken,
                connectionState: gateway.state.displayName,
                lastErrorMessage: gateway.lastErrorMessage,
                lastErrorAt: gateway.lastErrorAt,
                reconnectBackoffUntil: reconnectBackoffUntil
            )
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var reconnectBackoffUntil: Date? {
        switch gateway.state {
        case .reconnecting(let nextRetryAt):
            return nextRetryAt
        default:
            return nil
        }
    }

    private var deviceId: String? {
        try? DeviceIdentity.deviceId()
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    private func copyToPasteboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
