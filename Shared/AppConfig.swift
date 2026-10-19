import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Crane Inspection Log"
    static let bundleID = "com.example.crane-log"
    static let appGroupID = "group.com.example.crane-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy (somexai_corp repo, scripts/privacy.py).
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/crane-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    /// What the app calls one record. "Entry" for a generic log; "Dose", "Visit", "Inspection" in real apps.
    static let entryNoun = "Inspection"
    static let entryNounPlural = "Inspections"
    /// File name stem for exports: "crane-log-2026-09-11.csv".
    static let exportFileStem = "crane-log"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "crane", title: "Three clocks, one machine",
                       body: "OSHA runs a shift check, a monthly record and an annual on every crane at once. The app runs all three and tells you which is nearest."),
        OnboardingPage(symbol: "signature", title: "Signed where it has to be",
                       body: "Monthly and annual inspections are required to carry the name and signature of whoever did them. Sign with a finger and it prints on the record."),
        OnboardingPage(symbol: "octagon.fill", title: "Red tag means red tag",
                       body: "Call a deficiency a safety hazard and the machine goes out of service until you say it is corrected. Your data stays on your phone."),
    ]

    static let paywallSymbol = "checkmark.seal.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited machines and inspections",
        "Signed monthly and annual records as PDFs",
        "Shift, monthly and annual clocks per machine",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the home screen)
    static let howToIntro = "Four steps. Adding the machine takes the longest, and only happens once."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "crane", title: "Add the machine",
                  body: "Tap Add a machine and fill in the unit number, make, model and serial. Then set what it has — tires, rails, a cab — because that decides which items the inspection asks about. A crawler is never asked about tires.",
                  tip: "Photograph the data plate while you are at the machine. Serial numbers get misread off a note."),
        HowToStep(symbol: "sun.horizon", title: "Do the shift check",
                  body: "Open the machine and tap Shift. Tap Mark everything remaining as OK, then change only what is wrong. The standard asks for no record of this one, so it stays light — but a deficiency found on Tuesday is not lost by Friday."),
        HowToStep(symbol: "signature", title: "Sign the monthly and the annual",
                  body: "These two are the documented ones. Fill in the items, put your name in, and sign with a finger. The record is not complete until it is signed, and the app says so.",
                  tip: "Monthly records have to be kept three months, annual ones twelve. The machine screen warns you when your history is short of that."),
        HowToStep(symbol: "octagon.fill", title: "Know what a hazard does",
                  body: "Marking an item as a Safety hazard rather than a Deficiency takes the machine out of service the moment you save, and it stays out until you tap Return to service. That is the standard's own consequence, not the app's opinion."),
        HowToStep(symbol: "doc.richtext", title: "Produce the record",
                  body: "A signed inspection has an Inspection record (PDF) button at the bottom. For the whole file, use Inspection history (PDF) on the machine screen."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$19.99", lifetime: "$49.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
