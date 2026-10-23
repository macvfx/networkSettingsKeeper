import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Network Settings Keeper").font(.title2.bold())
            Text("Remembers how an Ethernet adapter is set up and puts the settings back if macOS loses them, "
                 + "for example after a Thunderbolt adapter is unplugged and plugged in again.")
                .fixedSize(horizontal: false, vertical: true)
            item("1.circle", "Save", "Set the adapter up the way you want, then choose "
                 + "\"Save as Known-Good\" in the Adapters tab, or \"Save Current Settings Of\" in the menu.")
            item("eye", "Watch", "The app checks every few seconds. The icon is green when the saved settings "
                 + "are in place, orange when they changed, grey when the adapter is not connected.")
            item("arrow.uturn.backward", "Restore", "When settings change you get a notification. "
                 + "Choose Restore and approve with your administrator password or Touch ID, "
                 + "because macOS requires it to change network settings.")
            item("link", "Follows the adapter", "Saved settings are tied to the adapter's hardware address, "
                 + "so they are put back even if macOS made a new service for it, for example when it is "
                 + "plugged into a different port.")
            item("pencil", "Changed on purpose?", "Use \"Keep Current as New Saved\" so the app stops "
                 + "treating your new settings as a problem.")
        }
        .padding(20)
        .frame(width: 460)
    }

    private func item(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).bold()
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
