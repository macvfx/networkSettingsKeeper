# Building Network Settings Keeper

Requires Xcode 15 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open "Network Settings Keeper.xcodeproj"
```

`project.yml` is the source of truth for the project; edit it and regenerate. Version and build
number are `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` there.

## Signing for a local build

No team ID is committed. Copy the example and fill it in:

```bash
cp Config/Signing.local.example.xcconfig Config/Signing.local.xcconfig
```

`Config/Signing.local.xcconfig` is gitignored.

## Command line build

```bash
xcodebuild -project "Network Settings Keeper.xcodeproj" -scheme "Network Settings Keeper" -configuration Debug build
```

## Release

Distribution is a Developer ID signed, notarized and stapled disk image. Supply your own
signing identity, team and notarytool keychain profile through the environment, then archive,
sign, notarize and staple, and verify with `spctl --assess --type execute` and
`xcrun stapler validate`.

## Testing a restore

With an adapter saved, change its IP address in System Settings, Network. The app should report
the change within the check interval. Choose Restore and confirm the original address returns.
