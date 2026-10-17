//
//  LegalDocumentView.swift
//  AstroAI
//

import SwiftUI

/// Apple's standard licensed-application terms. Used when the app has no custom EULA.
enum AppLegal {
    static let standardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: "Privacy Policy"
        case .terms: "Terms of Use"
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Text(bodyText)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(AppColor.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    if document == .terms {
                        Link("Apple Standard EULA", destination: AppLegal.standardEULA)
                            .font(AppFont.bodyMedium.weight(.semibold))
                    }
                }
                .padding(Spacing.margin)
                .padding(.bottom, Spacing.lg)
            }
            .screenBackground()
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
    }

    private var bodyText: String {
        switch document {
        case .privacy: Self.privacy
        case .terms: Self.terms
        }
    }

    private static let privacy = """
        AstroAI stores what you enter so it can calculate a birth chart on this iPhone. This policy describes that data. AstroAI does not run an account server, and it does not sell personal information.

        Stored on this iPhone
        The app saves your name, birth date and time, birth city, coordinates, time zone, natal chart, journal, saved people and their birth data, preferences, and profile photo. The profile photo is a file in the app's documents. The rest is stored as ordinary app data on the device. The app does not encrypt this store.

        None of that chart, journal, or profile data is uploaded to an AstroAI server. There is no AstroAI account to sign in to.

        Oracle
        The Oracle runs on this iPhone. It is given your name, chart, and the people you saved, including their names, so it can answer about them. It does not remove your name or your birth data. The question is not sent to a server.

        If Apple Intelligence is unavailable, the app can download an open model once from Hugging Face. The download is the model, not your chart or journal. After the model is on the phone, answers stay on the phone.

        Birth city
        Searching for a birth city sends the city name you type to Apple Maps, so the chart can use coordinates and a time zone. The rest of your chart is not part of that search.

        Purchases
        Sanctuary is an auto-renewable subscription sold by Apple. Apple processes the payment. AstroAI does not receive your payment card number. Apple may provide the app with the fact that the subscription is active and when it renews.

        Deletion
        Settings includes Erase Chart and Journal. That deletes the chart, journal, saved people, photo, and calculations from this iPhone and returns you to the start of the app. Deleting AstroAI also removes this local data. Canceling the subscription is separate: Settings, Apple ID, Subscriptions.

        Children
        AstroAI is not directed at children under 13.

        Contact
        Questions about this policy can be sent through the support link on the AstroAI page in the App Store.
        """

    private static let terms = """
        AstroAI is a birth-chart and reflection app. These terms cover use of the app and the Sanctuary subscription. The Apple Standard EULA linked below also applies.

        Sanctuary
        Sanctuary is an auto-renewable subscription. The purchase screen shows the plan name, length, price, and what is included before you confirm. Payment is charged to your Apple ID.

        If the plan you select includes a free trial, the trial length and the price charged when it ends are shown on the purchase screen. Unless you cancel at least 24 hours before the trial ends, Apple bills the subscription price and the plan renews.

        The subscription renews for the same length and price until you cancel. Apple charges the renewal within 24 hours before the current period ends. Cancel anytime in Settings, Apple ID, Subscriptions. Deleting the app does not cancel the subscription.

        Sanctuary unlocks on the devices signed in with the same Apple ID. Restore Purchases on the subscription screen checks that Apple ID for an active plan.

        The chart, the day's sky, and Oracle answers are symbolic reflections. They are not medical, legal, or financial advice.

        The Apple Standard EULA is the end user license for the app.
        """
}
