import SwiftUI
import HackPanelGateway
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @ObservedObject var gateway: GatewayConnectionStore

    @StateObject private var profiles = GatewayProfilesStore()

    // NOTE: OpenClaw Gateway multiplexes WS + HTTP on the same port (default 18789).
    // HackPanel will eventually use the Gateway WebSocket protocol (not plain REST).
    @AppStorage("gatewayBaseURL") private var gatewayBaseURL: String = GatewayDefaults.baseURLString
    @KeychainStorage("gatewayToken") private var gatewayToken: String = ""

    @AppStorage("gatewayAutoApply") private var gatewayAutoApply: Bool = true

    @State private var draftBaseURL: String = ""
    @State private var draftToken: String = ""
    @State private var validationError: String?
    @State private var tokenValidationError: String?
    @State private var hasEditedBaseURL: Bool = false
    @State private var hasEditedToken: Bool = false

    @State private var copiedAt: Date?
    @State private var copiedSummaryAt: Date?

    @State private var exportedZipAt: Date?
    @State private var exportErrorMessage: String?

    // Profiles: create/edit/delete UI
    @State private var showCreateProfileSheet: Bool = false
    @State private var newProfileName: String = ""
    @State private var newProfileBaseURL: String = GatewayDefaults.baseURLString
    @State private var newProfileToken: String = ""
    @State private var newProfileBaseURLError: String?
    @State private var newProfileTokenError: String?

    @State private var showEditProfileSheet: Bool = false
    @State private var editProfileName: String = ""
    @State private var editProfileBaseURL: String = GatewayDefaults.baseURLString
    @State private var editProfileToken: String = ""
    @State private var editProfileBaseURLError: String?
    @State private var editProfileTokenError: String?

    @State private var showDeleteProfileConfirm: Bool = false

    // Test connection
    @State private var isTestingConnection: Bool = false
    @State private var testConnectionResult: GatewayTestConnectionPresenter.PresentedResult?
    @State private var testConnectionStatus: GatewayStatus?
    @State private var testConnectionAt: Date?

    // Auto-apply / undo
    @State private var pendingApplyTask: Task<Void, Never>?
    @State private var lastAppliedAt: Date?
    @State private var undoSnapshot: (baseURL: String, token: String)?
    @State private var showAppliedToast: Bool = false

    // Reset draft
    @State private var showResetDraftConfirm: Bool = false
    @State private var resetDraftInfoMessage: String?

    private static let uiTimestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()

    private static let fileTimestampFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyyMMdd-HHmmss"
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

                    Picker("Profile", selection: $profiles.activeProfileId) {
                        ForEach(profiles.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .help("Switch between saved gateway connection profiles. Selecting a profile applies it immediately.")
                    .onChange(of: profiles.activeProfileId) { _, _ in
                        // Load profile into drafts and apply immediately.
                        let p = profiles.activeProfile
                        draftBaseURL = p.baseURLString
                        draftToken = profiles.token(for: p.id)
                        hasEditedBaseURL = false
                        hasEditedToken = false
                        validationError = baseURLValidationMessage(for: draftBaseURL)
                        tokenValidationError = tokenValidationMessage(for: draftToken)
                        applyAndReconnect(userInitiated: true)
                    }

                    HStack {
                        Button("New Profile…") {
                            // Seed from current drafts so users can clone + tweak.
                            newProfileName = ""
                            newProfileBaseURL = draftBaseURL.isEmpty ? GatewayDefaults.baseURLString : draftBaseURL
                            newProfileToken = draftToken
                            newProfileBaseURLError = baseURLValidationMessage(for: newProfileBaseURL)
                            newProfileTokenError = tokenValidationMessage(for: newProfileToken)
                            showCreateProfileSheet = true
                        }

                        Button("Edit Profile…") {
                            let p = profiles.activeProfile
                            editProfileName = p.name
                            editProfileBaseURL = p.baseURLString
                            editProfileToken = profiles.token(for: p.id)
                            editProfileBaseURLError = baseURLValidationMessage(for: editProfileBaseURL)
                            editProfileTokenError = tokenValidationMessage(for: editProfileToken)
                            showEditProfileSheet = true
                        }

                        Button("Delete Profile…") {
                            showDeleteProfileConfirm = true
                        }
                        .disabled(profiles.profiles.count <= 1)

                        Spacer()
                    }
                    .confirmationDialog(
                        "Delete gateway profile?",
                        isPresented: $showDeleteProfileConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Profile", role: .destructive) {
                            deleteActiveProfile()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes the profile from HackPanel. You can recreate it later.")
                    }

                    LabeledContent("Gateway URL") {
                        HStack(spacing: 8) {
                            TextField("", text: $draftBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .help("Example: http(s)://your-gateway-host:\(GatewayDefaults.defaultPort). If you omit a port, HackPanel assumes :\(GatewayDefaults.defaultPort).")
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

                            if !draftBaseURL.isEmpty {
                                Button("Clear") {
                                    clearDraftBaseURL()
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Clear Gateway URL")
                            }
                        }
                    }

                    LabeledContent("Token") {
                        HStack(spacing: 8) {
                            SecureField("", text: $draftToken)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("settings.gatewayToken")
                                .onChange(of: draftToken) { _, newValue in
                                    hasEditedToken = true

                                    // Trim leading/trailing whitespace on edit/paste.
                                    let normalized = GatewaySettingsValidator.normalizeToken(newValue)
                                    if newValue != normalized {
                                        draftToken = normalized
                                        return
                                    }

                                    tokenValidationError = tokenValidationMessage(for: normalized)
                                    scheduleAutoApplyIfNeeded()
                                }

                            if !draftToken.isEmpty {
                                Button("Clear") {
                                    clearDraftToken()
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Clear Token")
                            }
                        }
                    }

                    HStack {
                        if !gatewayAutoApply {
                            Button("Apply & Reconnect") {
                                applyAndReconnect(userInitiated: true)
                            }
                            .disabled(
                                !isDraftDirty ||
                                    baseURLValidationMessage(for: draftBaseURL) != nil ||
                                    tokenValidationMessage(for: draftToken) != nil
                            )
                        }

                        Button("Test connection") {
                            runTestConnection()
                        }
                        .disabled(
                            isTestingConnection
                                || baseURLValidationMessage(for: draftBaseURL) != nil
                                || tokenValidationMessage(for: draftToken) != nil
                        )

                        Button("Retry Now") {
                            gateway.retryNow()
                        }
                        .buttonStyle(.borderless)

                        if isDraftDirty {
                            Button("Reset Changes") {
                                showResetDraftConfirm = true
                            }
                            .buttonStyle(.link)
                            .confirmationDialog(
                                "Reset changes?",
                                isPresented: $showResetDraftConfirm,
                                titleVisibility: .visible
                            ) {
                                Button("Reset to Applied", role: .destructive) {
                                    resetDraftToApplied()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("This will discard your unsaved edits and restore the last applied settings.")
                            }
                        }

                        Button("Reset to Default") {
                            draftBaseURL = GatewayDefaults.baseURLString
                            hasEditedBaseURL = true
                            validationError = baseURLValidationMessage(for: draftBaseURL)
                            scheduleAutoApplyIfNeeded(force: true)
                        }
                        .buttonStyle(.link)

                        Spacer()
                    }

                    Text(isDraftDirty ? "Draft has changes" : "No changes")
                        .font(.caption)
                        .foregroundStyle(isDraftDirty ? .secondary : .secondary)
                        .accessibilityLabel(isDraftDirty ? "Draft has changes" : "No changes")
                        .accessibilityHint("Indicates whether the draft settings differ from the applied settings")

                    if isTestingConnection {
                        Text("Testing connection…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let testConnectionResult, let testConnectionAt {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Test result: \(testConnectionResult.message) (\(Self.uiTimestampFormatter.string(from: testConnectionAt)))")
                                .font(.caption)
                                .foregroundStyle(testConnectionResult.kind == .success ? .green : (testConnectionResult.kind == .unknown ? .secondary : .red))

                            if testConnectionResult.kind == .success, let status = testConnectionStatus {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Connected to:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("Version: \(status.version ?? "Not available")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text("Build: \(status.build ?? status.commit ?? "Not available")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if let validationError, hasEditedBaseURL {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let tokenValidationError, hasEditedToken {
                        Text(tokenValidationError)
                            .accessibilityIdentifier("settings.gatewayToken.error")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let resetDraftInfoMessage {
                        Text(resetDraftInfoMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if gatewayAutoApply {
                        Text("Changes apply automatically after a short pause. If the URL is invalid, nothing is applied.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("HackPanel connects to the OpenClaw Gateway WebSocket RPC endpoint (same port as HTTP; default 18789). Token is required to Apply/Test.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if gateway.state != .connected {
                        GlassSurface {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Not connected to Gateway")
                                    .font(.subheadline.weight(.semibold))

                                Text(gatewayBaseURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                if let msg = gateway.lastErrorMessage, !msg.isEmpty {
                                    Text(DiagnosticsFormatter.redactSecrets(in: msg, gatewayToken: gatewayToken))
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                        .textSelection(.enabled)
                                } else {
                                    Text("Start the OpenClaw Gateway and verify the URL/token.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Gateway connection error")
                    }
                }

                Section("Diagnostics") {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Connection") {
                                Text(gateway.state.displayName)
                                    .accessibilityIdentifier("settings.diagnostics.connectionState")
                            }

                            LabeledContent("Last success") {
                                Text(gateway.lastSuccessfulHealthCheckAt.map { Self.uiTimestampFormatter.string(from: $0) } ?? "—")
                                    .accessibilityIdentifier("settings.diagnostics.lastSuccessAt")
                            }

                            LabeledContent("Last error") {
                                let msg = gateway.lastErrorMessage ?? "(none)"
                                Text(DiagnosticsFormatter.redactSecrets(in: msg, gatewayToken: gatewayToken))
                                    .textSelection(.enabled)
                                    .accessibilityIdentifier("settings.diagnostics.lastError")
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

                            Divider()

                            LabeledContent("Last refresh attempt") {
                                Text(gateway.lastRefreshAttemptAt.map { Self.uiTimestampFormatter.string(from: $0) } ?? "—")
                            }

                            LabeledContent("Last refresh result") {
                                Text(gateway.lastRefreshResult ?? "—")
                            }

                            LabeledContent("Next scheduled refresh") {
                                Text(gateway.nextScheduledRefreshAt.map { Self.uiTimestampFormatter.string(from: $0) } ?? "—")
                            }

                            LabeledContent("Current backoff") {
                                if let s = gateway.currentBackoffSeconds {
                                    Text("\(String(format: "%.1f", s))s")
                                } else {
                                    Text("—")
                                }
                            }

                            Button {
                                copyToPasteboard(settingsSummaryText)
                                copiedSummaryAt = Date()
                            } label: {
                                Label("Copy Redacted Settings Summary", systemImage: "doc.on.doc")
                            }

                            HStack {
                                Button {
                                    exportDiagnosticsZip()
                                } label: {
                                    Label("Export Diagnostics (.zip)", systemImage: "square.and.arrow.down")
                                }

                                if let exportedZipAt {
                                    Text("Exported at \(Self.uiTimestampFormatter.string(from: exportedZipAt)).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            if let exportErrorMessage {
                                Text(exportErrorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }

                            if let copiedSummaryAt {
                                Text("Summary copied at \(Self.uiTimestampFormatter.string(from: copiedSummaryAt)).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Button {
                                copyToPasteboard(diagnosticsText)
                                copiedAt = Date()
                            } label: {
                                Label("Copy Diagnostics", systemImage: "doc.on.doc")
                            }

                            if let copiedAt {
                                Text("Diagnostics copied at \(Self.uiTimestampFormatter.string(from: copiedAt)).")
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
            .navigationTitle("Settings")
            .onAppear {
                // Initialize drafts from the active profile.
                let p = profiles.activeProfile
                if draftBaseURL.isEmpty { draftBaseURL = p.baseURLString }
                if draftToken.isEmpty { draftToken = profiles.token(for: p.id) }

                // Prime validation so required fields show inline errors immediately.
                validationError = baseURLValidationMessage(for: draftBaseURL)
                tokenValidationError = tokenValidationMessage(for: draftToken)
                hasEditedBaseURL = true
                hasEditedToken = true
            }
            .onChange(of: gatewayAutoApply) { _, _ in
                // If user toggles auto-apply ON while dirty, apply soon.
                scheduleAutoApplyIfNeeded(force: true)
            }
            .sheet(isPresented: $showCreateProfileSheet) {
                newProfileSheet
            }
            .sheet(isPresented: $showEditProfileSheet) {
                editProfileSheet
            }

            if showAppliedToast {
                appliedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 14)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showAppliedToast)
    }

    private var newProfileSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Gateway Profile")
                .font(.title2.weight(.semibold))

            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $newProfileName)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("Gateway URL") {
                        TextField("", text: $newProfileBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .help("Example: http(s)://your-gateway-host:\(GatewayDefaults.defaultPort). If you omit a port, HackPanel assumes :\(GatewayDefaults.defaultPort).")
                            .onChange(of: newProfileBaseURL) { _, newValue in
                                newProfileBaseURLError = baseURLValidationMessage(for: newValue)
                            }
                    }

                    LabeledContent("Token") {
                        SecureField("", text: $newProfileToken)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: newProfileToken) { _, newValue in
                                let normalized = GatewaySettingsValidator.normalizeToken(newValue)
                                if newValue != normalized {
                                    newProfileToken = normalized
                                    return
                                }
                                newProfileTokenError = tokenValidationMessage(for: normalized)
                            }
                    }

                    if let newProfileBaseURLError {
                        Text(newProfileBaseURLError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let newProfileTokenError {
                        Text(newProfileTokenError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showCreateProfileSheet = false
                }

                Spacer()

                Button("Create") {
                    createProfileFromSheet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(baseURLValidationMessage(for: newProfileBaseURL) != nil || tokenValidationMessage(for: newProfileToken) != nil)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
    }

    private func createProfileFromSheet() {
        // Validate once more to avoid creating broken profiles.
        newProfileBaseURLError = baseURLValidationMessage(for: newProfileBaseURL)
        newProfileTokenError = tokenValidationMessage(for: newProfileToken)
        guard newProfileBaseURLError == nil, newProfileTokenError == nil else { return }

        let created = profiles.createProfile(
            name: newProfileName,
            baseURLString: newProfileBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            token: newProfileToken
        )

        // createProfile(...) already sets the new profile active.
        _ = created
        showCreateProfileSheet = false
    }

    private var editProfileSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Gateway Profile")
                .font(.title2.weight(.semibold))

            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $editProfileName)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("Gateway URL") {
                        TextField("", text: $editProfileBaseURL)
                            .textFieldStyle(.roundedBorder)
                            .help("Example: http(s)://your-gateway-host:\(GatewayDefaults.defaultPort). If you omit a port, HackPanel assumes :\(GatewayDefaults.defaultPort).")
                            .onChange(of: editProfileBaseURL) { _, newValue in
                                editProfileBaseURLError = baseURLValidationMessage(for: newValue)
                            }
                    }

                    LabeledContent("Token") {
                        SecureField("", text: $editProfileToken)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: editProfileToken) { _, newValue in
                                let normalized = GatewaySettingsValidator.normalizeToken(newValue)
                                if newValue != normalized {
                                    editProfileToken = normalized
                                    return
                                }
                                editProfileTokenError = tokenValidationMessage(for: normalized)
                            }
                    }

                    if let editProfileBaseURLError {
                        Text(editProfileBaseURLError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let editProfileTokenError {
                        Text(editProfileTokenError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Button("Cancel") {
                    showEditProfileSheet = false
                }

                Spacer()

                Button("Save") {
                    saveEditsToActiveProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(baseURLValidationMessage(for: editProfileBaseURL) != nil || tokenValidationMessage(for: editProfileToken) != nil)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 320)
    }

    private func saveEditsToActiveProfile() {
        // This sheet edits the currently selected/active profile.
        let activeId = profiles.activeProfileId

        editProfileBaseURLError = baseURLValidationMessage(for: editProfileBaseURL)
        editProfileTokenError = tokenValidationMessage(for: editProfileToken)
        guard editProfileBaseURLError == nil, editProfileTokenError == nil else { return }

        let trimmedURL = editProfileBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        profiles.updateProfile(activeId, name: editProfileName, baseURLString: trimmedURL, token: editProfileToken)

        // Keep drafts and live connection in sync with the updated active profile.
        draftBaseURL = trimmedURL
        draftToken = editProfileToken
        hasEditedBaseURL = true
        hasEditedToken = true
        applyAndReconnect(userInitiated: true)

        showEditProfileSheet = false
    }

    private func deleteActiveProfile() {
        let id = profiles.activeProfileId
        profiles.deleteProfile(id)

        // Load the new active profile into drafts and apply immediately.
        let p = profiles.activeProfile
        draftBaseURL = p.baseURLString
        draftToken = profiles.token(for: p.id)
        hasEditedBaseURL = true
        hasEditedToken = true
        validationError = baseURLValidationMessage(for: draftBaseURL)
        tokenValidationError = tokenValidationMessage(for: draftToken)
        applyAndReconnect(userInitiated: true)
    }

    private func baseURLValidationMessage(for raw: String) -> String? {
        switch GatewaySettingsValidator.validateBaseURL(raw) {
        case .success:
            return nil
        case .failure(let error):
            return error.message
        }
    }

    private func tokenValidationMessage(for raw: String) -> String? {
        switch GatewaySettingsValidator.validateToken(raw) {
        case .success:
            return nil
        case .failure(let error):
            return error.message
        }
    }

    private func clearDraftBaseURL() {
        guard !draftBaseURL.isEmpty else { return }
        hasEditedBaseURL = true
        draftBaseURL = ""
        validationError = baseURLValidationMessage(for: draftBaseURL)
        scheduleAutoApplyIfNeeded()
    }

    private func clearDraftToken() {
        guard !draftToken.isEmpty else { return }
        hasEditedToken = true
        draftToken = ""
        tokenValidationError = tokenValidationMessage(for: draftToken)
        scheduleAutoApplyIfNeeded()
    }

    private func scheduleAutoApplyIfNeeded(force: Bool = false) {
        pendingApplyTask?.cancel()
        pendingApplyTask = nil

        guard gatewayAutoApply else { return }

        // Only apply when Base URL and Token are valid.
        let msg = baseURLValidationMessage(for: draftBaseURL)
        validationError = msg
        guard msg == nil else { return }

        let tokenMsg = tokenValidationMessage(for: draftToken)
        tokenValidationError = tokenMsg
        guard tokenMsg == nil else { return }

        // Avoid re-applying if nothing changed (unless explicitly forced).
        if !force {
            if !isDraftDirty {
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

    private var isDraftDirty: Bool {
        let draft = GatewaySettingsDraft(baseURL: draftBaseURL, token: draftToken)
        let applied = GatewaySettingsDraft(baseURL: gatewayBaseURL, token: gatewayToken)
        return draft.differs(fromApplied: applied)
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

    private func resetDraftToApplied() {
        pendingApplyTask?.cancel()
        pendingApplyTask = nil

        var draft = GatewaySettingsDraft(baseURL: draftBaseURL, token: draftToken)
        let applied = GatewaySettingsDraft(baseURL: gatewayBaseURL, token: gatewayToken)

        let outcome = draft.reset(toApplied: applied, defaultBaseURL: GatewayDefaults.baseURLString)

        draftBaseURL = draft.baseURL
        draftToken = draft.token

        hasEditedBaseURL = false
        hasEditedToken = false
        validationError = baseURLValidationMessage(for: draftBaseURL)
        tokenValidationError = tokenValidationMessage(for: draftToken)

        switch outcome {
        case .resetToApplied:
            resetDraftInfoMessage = "Restored last applied settings."
        case .resetToDefaultBaseURL:
            resetDraftInfoMessage = "Applied settings were missing; restored defaults."
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            resetDraftInfoMessage = nil
        }
    }

    private func applyAndReconnect(userInitiated: Bool) {
        let trimmedBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        let trimmedToken: String
        switch GatewaySettingsValidator.validateToken(draftToken) {
        case .success(let validated):
            trimmedToken = validated
            tokenValidationError = nil
        case .failure(let error):
            tokenValidationError = error.message
            return
        }

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

        // Persist into the active profile (and keep legacy single-config keys in sync).
        profiles.updateActiveProfile(baseURLString: trimmedBaseURL)
        profiles.setToken(trimmedToken, for: profiles.activeProfileId)

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

    private func runTestConnection() {
        guard !isTestingConnection else { return }

        // Validate Base URL (and normalize/validate token) once up front.
        let url: URL
        switch GatewaySettingsValidator.validateBaseURL(draftBaseURL) {
        case .success(let validated):
            url = validated
        case .failure:
            return
        }

        let token: String
        switch GatewaySettingsValidator.validateToken(draftToken) {
        case .success(let validated):
            token = validated
        case .failure:
            return
        }

        isTestingConnection = true
        testConnectionResult = nil
        testConnectionStatus = nil
        testConnectionAt = nil

        Task { @MainActor in
            defer { isTestingConnection = false }

            do {
                let status: GatewayStatus
                if gatewayAutoApply {
                    // Auto-apply ON: draft is (or will soon be) applied; use the live store client.
                    status = try await gateway.testConnection()
                } else {
                    // Auto-apply OFF: explicitly test the *draft* values without persisting/applying.
                    let cfg = GatewayConfiguration(baseURL: url, token: token.isEmpty ? nil : token)
                    let client = LiveGatewayClient(configuration: cfg)
                    status = try await client.fetchStatus()
                }

                testConnectionStatus = status
                testConnectionResult = GatewayTestConnectionPresenter.presentSuccess()
            } catch {
                testConnectionStatus = nil
                testConnectionResult = GatewayTestConnectionPresenter.present(error: error)
            }

            testConnectionAt = Date()
        }
    }

    private var settingsSummaryText: String {
        DiagnosticsFormatter.formatSettingsSummary(
            appVersion: appVersion,
            appBuild: appBuild,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            gatewayBaseURL: gatewayBaseURL,
            gatewayAutoApply: gatewayAutoApply,
            connectionState: gateway.state.displayName,
            lastErrorMessage: gateway.lastErrorMessage
        )
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
                reconnectBackoffUntil: reconnectBackoffUntil,
                isRefreshPaused: gateway.isRefreshPaused,
                lastActiveAt: gateway.lastActiveAt
            )
        )
    }

    private var recentLogsText: String {
        let lines = gateway.recentLogLines
        guard !lines.isEmpty else {
            return "(no recent logs captured)\n"
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private func exportDiagnosticsZip() {
        exportErrorMessage = nil

        Task { @MainActor in
            do {
                let now = Date()

                let bundle = try DiagnosticsExportBuilder.build(
                    .init(
                        appVersion: appVersion,
                        appBuild: appBuild,
                        osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                        generatedAt: now,
                        settingsSummaryText: settingsSummaryText,
                        logsText: recentLogsText
                    )
                )

                let fm = FileManager.default
                let exportDir = fm.temporaryDirectory
                    .appending(path: "hackpanel-diagnostics-\(UUID().uuidString)", directoryHint: .isDirectory)

                try fm.createDirectory(at: exportDir, withIntermediateDirectories: true)

                for entry in bundle.entries {
                    let url = exportDir.appending(path: entry.filename)
                    try entry.data.write(to: url, options: [.atomic])
                }

                let timestamp = Self.fileTimestampFormatter.string(from: now)
                let tempZipURL = fm.temporaryDirectory.appending(path: "HackPanel-Diagnostics-\(timestamp).zip")
                try? fm.removeItem(at: tempZipURL)

                // Zip via ditto (FileManager.zipItem isn't available in all Foundation toolchains).
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                p.arguments = [
                    "-c",
                    "-k",
                    "--sequesterRsrc",
                    "--keepParent",
                    exportDir.path,
                    tempZipURL.path
                ]
                try p.run()
                p.waitUntilExit()
                guard p.terminationStatus == 0 else {
                    throw NSError(
                        domain: "HackPanel.DiagnosticsExport",
                        code: Int(p.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create zip (ditto exit \(p.terminationStatus))."]
                    )
                }

                #if os(macOS)
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType.zip]
                panel.canCreateDirectories = true
                panel.isExtensionHidden = false
                panel.nameFieldStringValue = tempZipURL.lastPathComponent

                guard panel.runModal() == .OK, let destinationURL = panel.url else {
                    return
                }

                try? fm.removeItem(at: destinationURL)
                try fm.copyItem(at: tempZipURL, to: destinationURL)
                #endif

                exportedZipAt = now
            } catch {
                exportErrorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
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