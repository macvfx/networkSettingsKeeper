# Network Settings Keeper

A macOS menu bar app that remembers how an Ethernet adapter is configured and puts the
settings back when macOS loses them.

Built for the case where a Thunderbolt 10GbE adapter with a manual IP address occasionally
comes back after being unplugged with its static settings gone.

## How it works

1. Configure the adapter the way you want it, then save it as known-good.
2. The app checks every few seconds and compares what macOS has with what you saved.
3. If they differ, you get a notification with a Restore button. Restoring asks for an
   administrator password or Touch ID, because macOS requires it to change network settings.

Saved settings are tied to the adapter's hardware address, not the service name. macOS names a
new service (for example "Thunderbolt Ethernet Slot 1") when an adapter moves to another port,
and that new service starts on DHCP. The app finds the adapter by hardware address and restores
the settings onto whichever service it now has.

## Moving settings to another Mac

Export a saved profile to a `.nskprofile` file (JSON) and import it on another Mac, for example
to give a laptop the same adapter settings as an iMac. The export has no hardware address by
default, so it works as a template for a similar adapter. On import you pick the adapter, and
can change the IP address: only addresses in the original network are accepted, and the app can
check whether something already answers at the address or suggest a free one. Nothing is applied
until you choose Save and Apply. See the [user guide](Docs/USER_GUIDE.md) and
[Docs/Example.nskprofile](Docs/Example.nskprofile).

## What is saved and restored

IPv4 method, address, subnet mask and router; DNS servers and search domains; MTU and
speed/duplex when set explicitly.

## Status icon

Green: saved settings are in place. Orange: they changed. Grey: no saved settings, or the
adapter is not connected.

## Requirements

macOS 14 or later. Not sandboxed (it edits network preferences), so it is distributed outside
the Mac App Store, signed with a Developer ID and notarized.

## Documentation

- [User guide](Docs/USER_GUIDE.md)
- [Build instructions](Docs/BUILD_INSTRUCTIONS.md)
- [Changelog](CHANGELOG.md)

## Privacy

Makes no network requests and collects nothing. Saved profiles are stored on your Mac in
`~/Library/Application Support/Network Settings Keeper/profiles.json`.

## Known limits

- Restore needs an administrator approval each time. Silent automatic restore would need a
  privileged helper and is not built yet.
- IPv6 settings are not saved.
- The "in use" check is a ping, so a device that does not answer ping looks free.
- Only Ethernet-type services (including Thunderbolt and USB adapters) are handled.

## License

MIT. See [LICENSE](LICENSE).
