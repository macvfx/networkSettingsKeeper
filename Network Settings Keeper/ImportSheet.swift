import SwiftUI

struct ImportSheet: View {
    let model: KeeperModel
    @Bindable var draft: ImportDraft

    private var target: ServiceInfo? { model.services.first { $0.id == draft.targetID } }
    private var replaces: Profile? { model.profiles.first { $0.mac == target?.mac } }
    private var canSave: Bool { target != nil && draft.addressCheck == .ok }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Profile").font(.title2.bold())
            Form {
                TextField("Name", text: $draft.label)
                Picker("Set up on", selection: $draft.targetID) {
                    ForEach(model.savableServices) { service in
                        Text("\(service.name) (\(service.bsdName ?? "?"))").tag(Optional(service.id))
                    }
                }
                Section("Settings in the file") {
                    LabeledContent("IPv4", value: draft.portable.settings.ipv4.method)
                    if draft.isManual {
                        LabeledContent("Subnet mask", value: draft.mask)
                        LabeledContent("Router", value: draft.router ?? "none")
                    }
                    LabeledContent("DNS", value: draft.portable.settings.dns.servers.joined(separator: ", ").ifEmpty("none"))
                    if let mtu = draft.portable.settings.link.mtu { LabeledContent("MTU", value: String(mtu)) }
                }
                if draft.isManual { addressSection }
            }
            .formStyle(.grouped)

            if draft.droppedMedia, draft.portable.sourceHardwareAddress?.lowercased() != target?.mac {
                note("The speed and duplex setting in the file is not imported, because another adapter may not support it.")
            }
            if let replaces {
                note("This replaces the saved settings \"\(replaces.label)\" for this adapter.")
            }
            if model.savableServices.isEmpty {
                note("Connect the Ethernet adapter first. Only connected adapters can be set up.")
            }

            HStack {
                Button("Cancel") { model.importDraft = nil }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { model.saveImported(draft, apply: false) }.disabled(!canSave)
                Button("Save and Apply") { model.saveImported(draft, apply: true) }
                    .buttonStyle(.borderedProminent).disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    @ViewBuilder private var addressSection: some View {
        Section("Address on this Mac") {
            TextField("IP address", text: $draft.addressText)
            if draft.addressChanged {
                Text("The file has \(draft.fileAddress). Only addresses in the same network are accepted.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let message = draft.addressMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            HStack {
                Button("Check if in Use") { Task { await draft.checkAddress(interface: target?.bsdName) } }
                    .disabled(draft.addressCheck != .ok || draft.probe == .checking)
                Button("Suggest a Free Address") { Task { await draft.suggestFree(interface: target?.bsdName) } }
                    .disabled(draft.suggesting)
                if draft.probe == .checking || draft.suggesting { ProgressView().controlSize(.small) }
            }
            switch draft.probe {
            case .inUse:
                Label("Something already answers at this address.", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            case .noReply:
                Label("No reply. A hint it is free, not a guarantee.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            default: EmptyView()
            }
            if let note = draft.suggestionNote { Text(note).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func note(_ text: String) -> some View {
        Label(text, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
