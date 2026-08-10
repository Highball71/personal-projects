//
//  FluffyErrorBanner.swift
//  FluffyList
//
//  Compact, dismissable error banner shared by the tab views.
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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffyError)

            Text(message)
                .font(.fluffyFootnote)
                .foregroundStyle(Color.fluffyPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(.fluffySubheadline)
                    .foregroundStyle(Color.fluffyError)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.fluffyCaption)
                    .foregroundStyle(Color.fluffySecondary)
                    .frame(minWidth: 28, minHeight: 28)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fluffyError.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}
