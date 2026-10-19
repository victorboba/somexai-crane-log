# Crane Inspection Log

The three inspections OSHA runs on every crane (the shift check, the signed monthly record and the annual) kept on the phone of whoever does them. For crane operators, competent persons and yard supervisors.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the collection is [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Three clocks on one machine.** The crane screen shows the shift, monthly and annual clocks side by side and sorts worst-first.
- **Honest about what is a record.** The shift check stays light and says the standard asks for no documentation of it. The monthly and annual carry a signature, and the app will not call either complete without one.
- **A drawn signature**: a finger-drawn pad whose result prints on the record.
- **Deficiency or safety hazard**: the inspector's call. Marking an item a safety hazard takes the machine out of service when saved, and it stays red-tagged at the top of the fleet until someone confirms the correction.
- **Retention awareness**: being unable to produce three months of monthlies is its own finding, so the app says when the file is thin.
- **The checklist fits the machine.** A crawler is never asked about tire pressure; a machine that is not rail-mounted is never asked about rails.
- **The record**: a signed PDF per inspection, a whole-machine history PDF, and a CSV with a column per item.
- A Home Screen widget, a Siri App Shortcut, and a How do I use guide.

## The boundary

The app records what the inspector entered. It does not inspect, certify or approve any equipment, and it does not decide whether a deficiency is a safety hazard. That is left to the competent person.

## Privacy

All data stays on the device in SwiftData. There is no account, no analytics and no network code, and `AppConfig.iCloudSyncEnabled` is `false`. Signatures are stored in the on-device database. CSV and PDF export happen only when you choose to share a file.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17+.

```bash
xcodegen generate
open CraneLog.xcodeproj
```

Pick the `CraneLog` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme CraneLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.

To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Project layout

- `CraneLog/App/`: app entry point and the root view that gates onboarding, paywall and the app.
- `CraneLog/Core/`: StoreKit entitlement, CSV and PDF export, App Intents, review prompt, widget sync, debug flags and sample data.
- `CraneLog/Features/`: the screens, including onboarding, paywall, settings and the How do I use guide.
- `CraneLog/Models/`: the SwiftData models and the calculation code. Models are `Crane` and `CheckItem`.
- `CraneLog/StoreKit/Products.storekit`: local StoreKit configuration.
- `CraneLogWidget/`: the Home Screen widget, fed by a snapshot in the App Group.
- `CraneLogTests/` and `CraneLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, onboarding, paywall benefits, How-to steps, disclaimer, product IDs, links).
- `scripts/`: icon and screenshot helpers. `docs/` has notes on capabilities such as iCloud and App Groups.

## Technical notes

- The requirements encoded are from 29 CFR 1926.1412: shift (competent person, visual, no documentation required), monthly (documented, signed, retained at least three months) and annual (qualified person, documented, retained at least twelve months). Verify against the current regulation before relying on it.
- The tests cover which items apply to which machine and tier, which tiers are documented and for how long, the deficiency/hazard distinction, the three clocks, retention gaps and the exports.

## License

MIT. See [LICENSE](LICENSE).
