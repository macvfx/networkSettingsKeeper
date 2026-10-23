import AppKit
import Observation
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications
import os

enum SettingKey {
    static let checkSeconds = "checkSeconds"
    static let notifyOnDrift = "notifyOnDrift"
}

@MainActor
@Observable
final class KeeperModel: NSObject, UNUserNotificationCenterDelegate {
    static let shared = KeeperModel()

    /// A profile file being reviewed before it is saved for an adapter on this Mac.
    var importDraft: ImportDraft?
    private(set) var services: [ServiceInfo] = []
    private(set) var profiles: [Profile] = []
    private(set) var statuses: [UUID: ProfileStatus] = [:]
    private(set) var log: [LogEntry] = []
    private(set) var launchAtLogin = false
    private(set) var restoring = false

    private let store = ProfileStore()
    private var timer: Timer?
    private var notifiedSignature: [UUID: [String]] = [:]
    private static let category = "DRIFT"

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [SettingKey.checkSeconds: 5, SettingKey.notifyOnDrift: true])
        profiles = store.load()
        launchAtLogin = SMAppService.mainApp.status == .enabled

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([UNNotificationCategory(
            identifier: Self.category,
            actions: [UNNotificationAction(identifier: "restore", title: "Restore settings"),
                      UNNotificationAction(identifier: "ignore", title: "Ignore")],
            intentIdentifiers: [])])
        center.requestAuthorization(options: [.alert]) { _, _ in }

        refresh()
        schedule()
    }

    // MARK: Derived state

    enum Overall { case noProfiles, absent, ok, drift }

    var overall: Overall {
        if profiles.isEmpty { return .noProfiles }
        let all = profiles.compactMap { statuses[$0.id] }
        if all.contains(where: { if case .differs = $0 { true } else { false } }) { return .drift }
        if all.contains(where: { if case .matches = $0 { true } else { false } }) { return .ok }
        return .absent
    }

    func status(of profile: Profile) -> ProfileStatus { statuses[profile.id] ?? .adapterAbsent }

    /// Present Ethernet services with a hardware address, which can be saved as a profile.
    var savableServices: [ServiceInfo] { services.filter { $0.isPresent && $0.mac != nil } }

    func isSaved(_ service: ServiceInfo) -> Bool {
        profiles.contains { $0.mac == service.mac }
    }

    // MARK: Refresh

    private func schedule() {
        timer?.invalidate()
        let seconds = max(2, UserDefaults.standard.integer(forKey: SettingKey.checkSeconds))
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func settingsChanged() { schedule() }

    func refresh() {
        services = ServiceReader.readAll()
        for profile in profiles {
            let candidates = services.filter { $0.mac == profile.mac && $0.isPresent }
            guard let service = candidates.first(where: \.isEnabled) ?? candidates.first else {
                statuses[profile.id] = .adapterAbsent
                notifiedSignature[profile.id] = nil
                continue
            }
            let diffs = service.settings.differences(from: profile.settings)
            if diffs.isEmpty {
                statuses[profile.id] = .matches(serviceName: service.name)
                notifiedSignature[profile.id] = nil
            } else {
                statuses[profile.id] = .differs(serviceID: service.id, serviceName: service.name, differences: diffs)
                if notifiedSignature[profile.id] != diffs {
                    notifiedSignature[profile.id] = diffs
                    record("\(profile.label): settings differ (\(diffs.joined(separator: "; ")))")
                    notifyDrift(profile, diffs)
                }
            }
        }
    }

    // MARK: Profiles

    func save(_ service: ServiceInfo, label: String? = nil) {
        guard let mac = service.mac else { return }
        let profile = Profile(label: label ?? service.name, mac: mac,
                              savedServiceName: service.name, settings: service.settings)
        profiles.removeAll { $0.mac == mac }
        profiles.append(profile)
        store.save(profiles)
        record("Saved settings of \(service.name) as \"\(profile.label)\"")
        refresh()
    }

    /// Replace a profile's saved settings with what the adapter has now.
    func acceptCurrent(_ profile: Profile) {
        guard let service = services.first(where: { $0.mac == profile.mac && $0.isPresent }) else { return }
        save(service, label: profile.label)
    }

    func rename(_ profile: Profile, to label: String) {
        guard let index = profiles.firstIndex(of: profile) else { return }
        profiles[index].label = label
        store.save(profiles)
    }

    func remove(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        statuses[profile.id] = nil
        store.save(profiles)
        record("Removed \"\(profile.label)\"")
    }

    // MARK: Export and import

    func export(_ profile: Profile, includeHardwareAddress: Bool) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [PortableProfile.contentType]
        panel.nameFieldStringValue = "\(profile.label).\(PortableProfile.fileExtension)"
        panel.message = includeHardwareAddress
            ? "This file includes the adapter's hardware address."
            : "This file can be imported on another Mac. It has no hardware address."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let portable = PortableProfile(label: profile.label,
                                       sourceHardwareAddress: includeHardwareAddress ? profile.mac : nil,
                                       settings: profile.settings)
        do {
            try portable.encoded().write(to: url, options: .atomic)
            record("Exported \"\(profile.label)\" to \(url.lastPathComponent)")
        } catch {
            record("Export failed: \(error.localizedDescription)")
            showError("Could not save the profile.", error)
        }
    }

    func chooseImport() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [PortableProfile.contentType, .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a Network Settings Keeper profile."
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { beginImport(url: url) }
    }

    func beginImport(url: URL) {
        do {
            let portable = try PortableProfile.decode(try Data(contentsOf: url))
            refresh()
            importDraft = ImportDraft(portable: portable, defaultTarget: savableServices.first)
            record("Opened profile \"\(portable.label)\" for import")
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
        } catch {
            record("Import of \(url.lastPathComponent) failed: \(error.localizedDescription)")
            showError("Could not import \(url.lastPathComponent).", error)
        }
    }

    /// Save the reviewed profile for the chosen adapter, and optionally apply it right away.
    func saveImported(_ draft: ImportDraft, apply: Bool) {
        guard let target = services.first(where: { $0.id == draft.targetID }), let mac = target.mac else { return }
        let name = draft.label.trimmingCharacters(in: .whitespaces)
        let profile = Profile(label: name.isEmpty ? target.name : name, mac: mac,
                              savedServiceName: target.name, settings: draft.settings(for: target))
        profiles.removeAll { $0.mac == mac }
        profiles.append(profile)
        store.save(profiles)
        record("Imported \"\(profile.label)\" for \(target.name)")
        importDraft = nil
        refresh()
        if apply, let saved = profiles.first(where: { $0.id == profile.id }) { restore(saved) }
    }

    private func showError(_ message: String, _ error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: Restore

    func restore(_ profile: Profile) {
        guard case .differs(let serviceID, let name, _) = status(of: profile), !restoring else { return }
        restoring = true
        let settings = profile.settings
        Task.detached {
            let result = Result { try Restorer.apply(settings, toServiceID: serviceID) }
            await MainActor.run {
                self.restoring = false
                switch result {
                case .success: self.record("Restored \"\(profile.label)\" on \(name)")
                case .failure(let error): self.record("Restore of \"\(profile.label)\" failed: \(error.localizedDescription)")
                }
                self.notifiedSignature[profile.id] = nil
                self.refresh()
            }
        }
    }

    // MARK: Login item and log

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            record("Launch at login failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func record(_ text: String) {
        Logger(subsystem: "com.networksettingskeeper.app", category: "keeper").notice("\(text, privacy: .public)")
        log.insert(LogEntry(text: text), at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }

    // MARK: Notifications

    private func notifyDrift(_ profile: Profile, _ diffs: [String]) {
        guard UserDefaults.standard.bool(forKey: SettingKey.notifyOnDrift) else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(profile.label) settings changed"
        content.body = diffs.prefix(3).joined(separator: "\n")
        content.categoryIdentifier = Self.category
        content.userInfo = ["profile": profile.id.uuidString]
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "drift-\(profile.id)", content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == "restore",
              let text = response.notification.request.content.userInfo["profile"] as? String,
              let id = UUID(uuidString: text) else { return }
        await MainActor.run {
            if let profile = profiles.first(where: { $0.id == id }) { restore(profile) }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner] }
}
