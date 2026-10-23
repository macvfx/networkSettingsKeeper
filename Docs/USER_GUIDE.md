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
