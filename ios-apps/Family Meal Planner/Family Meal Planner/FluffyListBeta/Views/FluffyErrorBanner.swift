//
//  FluffyErrorBanner.swift
//  FluffyList
//
//  "The Press" error band. No rounded card, no shadow: a paper band
//  with a 2px ink-1 rule top and bottom, an uppercase "PROBLEM"
//  kicker, the message at 15pt, and a "Retry" text link in ink 1.
//  Two uses:
//    - Fetch failures: pass `onRetry` so the user can re-run the load.
//      Shown INSTEAD of an empty state — a load failure must never
//      masquerade as "you have no data."
//    - Write failures: omit `onRetry`; the banner just tells the user
//      the action didn't stick and can be dismissed.
//  Messages passed in should be short and human — never a raw
//  localizedDescription from the backend.
//

import SwiftUI

struct FluffyErrorBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffyRule(weight: 2, color: .fluffyAccent)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROBLEM")
                        .font(.fluffySectionHead)
                        .fluffyTracking(0.16, at: 11)
                        .foregroundStyle(Color.fluffyAccent)

                    Text(message)
                        .font(.custom(FluffyFace.regular, size: 15))
                        .foregroundStyle(Color.fluffyPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let onRetry {
                    Button(action: onRetry) {
                        VStack(spacing: 2) {
                            Text("Retry")
                                .font(.fluffyButton)
                                .foregroundStyle(Color.fluffyAccent)
                            FluffyRule(weight: 2, color: .fluffyAccent)
                        }
                        .fixedSize()
                    }
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.fluffySecondary)
                        .frame(minWidth: 28, minHeight: 28)
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.fluffyBackground)

            FluffyRule(weight: 2, color: .fluffyAccent)
        }
    }
}
