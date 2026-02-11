import Foundation
import SwiftUI

struct GatewayProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    /// Stored as a string so we can represent invalid/incomplete drafts in UI without losing input.
    var baseURLString: String

    init(id: UUID = UUID(), name: String, baseURLString: String) {
        self.id = id
        self.name = name
        self.baseURLString = baseURLString
    }

    var tokenKeychainAccount: String {
        "gatewayToken.profile.\(id.uuidString)"
    }
}

@MainActor
final class GatewayProfilesStore: ObservableObject {
    @Published private(set) var profiles: [GatewayProfile]
    @Published var activeProfileId: UUID

    private static let profilesKey = "gatewayProfiles"
    private static let activeIdKey = "gatewayActiveProfileId"

    init() {
        let defaults = UserDefaults.standard

        let initialProfiles: [GatewayProfile] = {
            if let loaded = Self.loadProfiles(from: defaults, key: Self.profilesKey), !loaded.isEmpty {
                return loaded
            }
            // Default Local profile.
            return [GatewayProfile(name: "Local", baseURLString: GatewayDefaults.baseURLString)]
        }()

        let initialActiveId: UUID = {
            if let active = Self.loadActiveId(from: defaults, key: Self.activeIdKey), initialProfiles.contains(where: { $0.id == active }) {
                return active
            }
            return initialProfiles.first!.id
        }()

        self.profiles = initialProfiles
        self.activeProfileId = initialActiveId

        // One-time best-effort migration: copy legacy token into the active profile token slot.
        // (We keep the legacy key in place for now; Settings keeps them in sync.)
        let legacyToken = Keychain.readString(account: "gatewayToken") ?? ""
        if !legacyToken.isEmpty, token(for: activeProfileId).isEmpty {
            setToken(legacyToken, for: activeProfileId)
        }

        persist()
    }

    var activeProfile: GatewayProfile {
        profiles.first(where: { $0.id == activeProfileId }) ?? profiles.first!
    }

    func token(for profileId: UUID) -> String {
        guard let profile = profiles.first(where: { $0.id == profileId }) else { return "" }
        return Keychain.readString(account: profile.tokenKeychainAccount) ?? ""
    }

    func setToken(_ token: String, for profileId: UUID) {
        guard let profile = profiles.first(where: { $0.id == profileId }) else { return }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            _ = Keychain.delete(account: profile.tokenKeychainAccount)
        } else {
            _ = Keychain.writeString(trimmed, account: profile.tokenKeychainAccount)
        }
    }

    func setActiveProfile(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileId = id
        persist()
    }

    func updateActiveProfile(baseURLString: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == activeProfileId }) else { return }
        profiles[idx].baseURLString = baseURLString
        persist()
    }

    private func persist() {
        Self.saveProfiles(profiles, to: UserDefaults.standard, key: Self.profilesKey)
        UserDefaults.standard.set(activeProfileId.uuidString, forKey: Self.activeIdKey)
    }

    private static func loadProfiles(from defaults: UserDefaults, key: String) -> [GatewayProfile]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([GatewayProfile].self, from: data)
    }

    private static func saveProfiles(_ profiles: [GatewayProfile], to defaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadActiveId(from defaults: UserDefaults, key: String) -> UUID? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return UUID(uuidString: raw)
    }
}
