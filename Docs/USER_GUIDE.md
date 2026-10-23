# Network Settings Keeper user guide

## Saving settings

1. Set the adapter up the way you want it in System Settings, Network.
2. Open the app's window (menu bar icon, "Open Window…"), go to Adapters and choose
   "Save as Known-Good" next to the adapter. The menu's "Save Current Settings Of" does the same.

Only connected Ethernet adapters can be saved. The saved entry appears under Saved Settings,
where you can rename it.

## When settings change

The icon turns orange and a notification lists what differs. Choose Restore settings (in the
notification, the menu, or the Saved Settings tab) and approve with your password or Touch ID.

If you changed the settings on purpose, choose "Keep Current as New Saved" instead.

## Saved Settings tab

Shows each saved adapter, whether it is connected, whether its settings match, and exactly
which values differ. Remove forgets a saved entry.

## Exporting a profile

In Saved Settings, choose Export on a saved entry:

- **Export for Another Mac:** no hardware address. Use this to set up a different adapter.
- **Export with Hardware Address:** also records the adapter's address, so importing it on the
  same physical adapter keeps its speed and duplex setting.

The file holds IP addresses, so treat it as semi-private.

## Importing a profile

Choose Import Profile in Saved Settings or the menu, or double-click a `.nskprofile` file.

1. Pick the connected adapter to set up.
2. Review the settings. For a manual address you can change the IP. Only addresses in the same
   network are accepted, and not the network, broadcast or router address.
3. "Check if in Use" pings the address, and "Suggest a Free Address" tries the next ones. A
   device that does not answer ping looks free, so treat this as a hint.
4. Save stores it as the saved settings for that adapter on this Mac. Save and Apply also writes
   it to the adapter, with your administrator approval. From then on the app keeps watching it.

Speed and duplex from the file are not imported onto a different adapter, because it may not
support them. The file's MTU is.

## Settings

- Check interval, 2 to 300 seconds.
- Notifications on or off.
- Open at login.

## Troubleshooting

Show what the app decided:

```bash
/usr/bin/log show --last 15m --predicate 'subsystem == "com.networksettingskeeper.app"' --info
```

Print what the app reads from macOS, without changing anything:

```bash
"/Applications/Network Settings Keeper.app/Contents/MacOS/Network Settings Keeper" --dump-services
```
