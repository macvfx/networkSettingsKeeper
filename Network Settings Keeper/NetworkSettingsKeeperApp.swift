import SwiftUI

extension Notification.Name {
    static let showMainWindow = Notification.Name("NetworkSettingsKeeper.showMainWindow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Double-clicking a profile file opens it for import.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in KeeperModel.shared.beginImport(url: url) }
    }
}

@main
struct NetworkSettingsKeeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow
    @State private var model = KeeperModel.shared

    init() {
        // Diagnostic: print what the app reads, then exit. No UI, no changes.
        if CommandLine.arguments.contains("--dump-services") {
            for service in ServiceReader.readAll() {
                print("\(service.name) [\(service.bsdName ?? "-")] present=\(service.isPresent) mac=\(service.mac ?? "-")")
                print("  IPv4: \(service.settings.ipv4.summary)")
                print("  DNS: \(service.settings.dns.servers) search: \(service.settings.dns.searchDomains)")
                print("  Link: mtu=\(service.settings.link.mtu.map(String.init) ?? "default") media=\(service.settings.link.mediaSubType ?? "auto")")
            }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: model.overall))
                .onReceive(NotificationCenter.default.publisher(for: .showMainWindow)) { _ in
                    openWindow(id: "main")
                    WindowFront.bring(titleContaining: "Network Settings Keeper")
                }
                .onAppear {
                    if model.importDraft != nil {
                        openWindow(id: "main")
                        WindowFront.bring(titleContaining: "Network Settings Keeper")
                    }
                }
        }

        Window("Network Settings Keeper", id: "main") {
            MainView(model: model)
        }
        .windowResizability(.contentMinSize)

        Window("Network Settings Keeper Help", id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    let model: KeeperModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(headline)
        if !model.profiles.isEmpty { Divider() }
        ForEach(model.profiles) { profile in
            switch model.status(of: profile) {
            case .adapterAbsent:
                Text("\(profile.label): not connected")
            case .matches:
                Text("\(profile.label): settings OK")
            case .differs:
                Button("Restore \(profile.label) settings") { model.restore(profile) }
                    .disabled(model.restoring)
            }
        }
        Divider()
        Menu("Save Current Settings Of") {
            if model.savableServices.isEmpty { Text("No Ethernet adapters connected") }
            ForEach(model.savableServices) { service in
                Button("\(service.name) (\(service.settings.ipv4.method))") { model.save(service) }
            }
        }
        Button("Import Profile…") {
            show("main", "Network Settings Keeper")
            model.chooseImport()
        }
        Button("Open Window…") { show("main", "Network Settings Keeper") }
        Button("Help…") { show("help", "Help") }
        Divider()
        Button("Quit Network Settings Keeper") { NSApplication.shared.terminate(nil) }
    }

    private func show(_ id: String, _ title: String) {
        openWindow(id: id)
        WindowFront.bring(titleContaining: title)
    }

    private var headline: String {
        switch model.overall {
        case .noProfiles: "No saved settings yet"
        case .absent: "Saved adapters not connected"
        case .ok: "All saved settings in place"
        case .drift: "Settings changed. Restore available"
        }
    }
}

enum MenuBarIcon {
    static func image(for overall: KeeperModel.Overall) -> NSImage {
        let color: NSColor = switch overall {
        case .ok: .systemGreen
        case .drift: .systemOrange
        case .absent, .noProfiles: .systemGray
        }
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            .applying(.init(paletteColors: [color]))
        let image = (NSImage(systemSymbolName: "cable.connector", accessibilityDescription: "Network Settings Keeper")
            ?? NSImage(systemSymbolName: "network", accessibilityDescription: nil)
            ?? NSImage()).withSymbolConfiguration(config) ?? NSImage()
        image.isTemplate = false
        return image
    }
}

/// Menu bar apps have no Dock presence, so a window they open can land behind other apps.
enum WindowFront {
    static func bring(titleContaining text: String) {
        NSApp.activate(ignoringOtherApps: true)
        for delay in [0.05, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApp.activate(ignoringOtherApps: true)
                let window = NSApp.windows.first { $0.title.contains(text) }
                window?.makeKeyAndOrderFront(nil)
                window?.orderFrontRegardless()
            }
        }
    }
}
