import SwiftUI

struct MainView: View {
    let model: KeeperModel

    var body: some View {
        VStack(spacing: 8) {
        TabView {
            ProfilesTab(model: model).tabItem { Label("Saved Settings", systemImage: "checkmark.shield") }
            AdaptersTab(model: model).tabItem { Label("Adapters", systemImage: "cable.connector") }
            ActivityTab(model: model).tabItem { Label("Activity", systemImage: "list.bullet") }
            SettingsTab(model: model).tabItem { Label("Settings", systemImage: "gearshape") }
        }
        SiteFooter()
        }
        .padding()
        .frame(minWidth: 620, minHeight: 440)
    }
}

private struct ProfilesTab: View {
    let model: KeeperModel

    var body: some View {
        if model.profiles.isEmpty {
            ContentUnavailableView("No saved settings",
                                   systemImage: "cable.connector",
                                   description: Text("Configure an adapter the way you want it, then save it from the Adapters tab."))
        } else {
            List(model.profiles) { profile in
                ProfileRow(model: model, profile: profile)
            }
        }
    }
}

private struct ProfileRow: View {
    let model: KeeperModel
    let profile: Profile
    @State private var label: String

    init(model: KeeperModel, profile: Profile) {
        self.model = model
        self.profile = profile
        _label = State(initialValue: profile.label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Name", text: $label)
                    .textFieldStyle(.plain).font(.headline)
                    .onSubmit { model.rename(profile, to: label) }
                Spacer()
                statusBadge
            }
            Text("Saved: \(profile.settings.ipv4.summary)").foregroundStyle(.secondary)
            Text("Adapter \(profile.mac), saved \(profile.savedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(.tertiary)
            if case .differs(_, let name, let diffs) = model.status(of: profile) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Now on \(name):").font(.callout.bold())
                    ForEach(diffs, id: \.self) { Text("• \($0)").font(.callout) }
                }
                HStack {
                    Button("Restore Saved Settings") { model.restore(profile) }
                        .buttonStyle(.borderedProminent).disabled(model.restoring)
                    Button("Keep Current as New Saved") { model.acceptCurrent(profile) }
                }
            }
            HStack {
                Spacer()
                Button("Remove", role: .destructive) { model.remove(profile) }
                    .buttonStyle(.link)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var statusBadge: some View {
        switch model.status(of: profile) {
        case .adapterAbsent: Label("Not connected", systemImage: "powerplug").foregroundStyle(.secondary)
        case .matches(let name): Label("OK on \(name)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .differs: Label("Changed", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

private struct AdaptersTab: View {
    let model: KeeperModel

    var body: some View {
        List(model.services) { service in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.name).font(.headline)
                    Text(service.settings.ipv4.summary).foregroundStyle(.secondary)
                    Text("\(service.bsdName ?? "no device") · \(service.mac ?? "no hardware address") · \(service.isPresent ? "connected" : "not present")")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                if service.isPresent && service.mac != nil {
                    if model.isSaved(service) {
                        Label("Saved", systemImage: "checkmark").foregroundStyle(.secondary)
                    } else {
                        Button("Save as Known-Good") { model.save(service) }
                    }
                }
            }
            .padding(.vertical, 3)
        }
    }
}

private struct ActivityTab: View {
    let model: KeeperModel

    var body: some View {
        if model.log.isEmpty {
            Text("Nothing yet").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(model.log) { entry in
                HStack(alignment: .top) {
                    Text(entry.date.formatted(date: .omitted, time: .standard))
                        .monospacedDigit().foregroundStyle(.secondary)
                    Text(entry.text)
                }
            }
        }
    }
}

private struct SettingsTab: View {
    let model: KeeperModel
    @AppStorage(SettingKey.checkSeconds) private var seconds = 5
    @AppStorage(SettingKey.notifyOnDrift) private var notify = true

    var body: some View {
        Form {
            Stepper("Check every \(seconds) seconds", value: $seconds, in: 2...300)
                .onChange(of: seconds) { model.settingsChanged() }
            Toggle("Notify me when settings change", isOn: $notify)
            Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin },
                                                  set: { model.setLaunchAtLogin($0) }))
        }
        .formStyle(.grouped)
    }
}
