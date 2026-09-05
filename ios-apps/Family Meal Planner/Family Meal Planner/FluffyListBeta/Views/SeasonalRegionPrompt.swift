//
//  SeasonalRegionPrompt.swift
//  FluffyList
//
//  The one-time seasonal region prompt (2026-09-04). Wherever a
//  seasonal surface would render (Recipes-tab shelf, picker "In
//  season now" section, week-footer strip) but no region is set, this
//  view stands in: a Press-style ruled card — "Pick your growing
//  region" over the manual region menu, "Use my location", and "Not
//  now". Location resolves through RegionLocator (one when-in-use
//  ask, reverse-geocode to a state, StateRegionMap); denial or any
//  failure quietly keeps the manual menu. Picking a region (either
//  way) writes the existing "seasonalRegion" setting, so every
//  surface swaps to real content at once and the prompt never
//  returns. "Not now" collapses the card to a one-line link,
//  remembered across launches ("seasonalRegionPromptDismissed") —
//  a card that reappears every morning is a nag, not a prompt.
//
//  Callers gate on `USRegion(rawValue:) == nil`; this view then
//  decides card vs. one-liner itself, so all three surfaces stay in
//  lockstep. `inList: true` drops the rules and outer padding for
//  the picker sheet's List, which draws its own row chrome.
//

import SwiftUI

struct SeasonalRegionPrompt: View {
    /// True inside the picker sheet's List (no rules, no 22pt inset).
    var inList: Bool = false

    /// USRegion raw value; "" = unset. Same key as Settings.
    @AppStorage("seasonalRegion") private var seasonalRegionRaw = ""
    /// "Not now" was tapped once — show the one-liner instead.
    @AppStorage("seasonalRegionPromptDismissed") private var promptDismissed = false

    @State private var isLocating = false
    @State private var locationFailed = false

    var body: some View {
        if promptDismissed {
            oneLineLink
                .padding(.horizontal, inList ? 0 : 22)
                .padding(.vertical, inList ? 4 : 0)
        } else {
            card
        }
    }

    // MARK: - The card

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !inList { FluffyRule().padding(.horizontal, 22) }

            VStack(alignment: .leading, spacing: 0) {
                FluffySectionHead(title: "In season now")
                    .padding(.bottom, 10)

                Text("Pick your growing region")
                    .font(.fluffyHeadline)
                    .fluffyTracking(-0.01, at: 19)
                    .foregroundStyle(Color.fluffyPrimary)
                    .padding(.bottom, 6)

                Text("Tell FluffyList where you cook and it flags recipes at their local harvest peak. One pick, eight US regions \u{2014} change it any time in Settings.")
                    .font(.custom(FluffyFace.italic, size: 14))
                    .foregroundStyle(Color.fluffySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)

                if locationFailed {
                    Text("Couldn't place you \u{2014} pick a region instead.")
                        .font(.custom(FluffyFace.italic, size: 14))
                        .foregroundStyle(Color.fluffyAccent)
                        .padding(.bottom, 12)
                }

                if isLocating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Finding your region\u{2026}")
                            .font(.custom(FluffyFace.italic, size: 14))
                            .foregroundStyle(Color.fluffySecondary)
                    }
                    .padding(.bottom, 4)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        regionMenu(title: "Choose a region")
                        FluffyTextLink(title: "Use my location", showArrow: false) {
                            useMyLocation()
                        }
                        Button {
                            promptDismissed = true
                        } label: {
                            Text("Not now")
                                .font(.custom(FluffyFace.regular, size: 14))
                                .foregroundStyle(Color.fluffySecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(.horizontal, inList ? 0 : 22)
            .padding(.vertical, 16)

            if !inList { FluffyRule().padding(.horizontal, 22) }
        }
    }

    // MARK: - The one-liner (after "Not now")

    /// What "Not now" leaves behind: one link-styled line that opens
    /// the region menu directly.
    private var oneLineLink: some View {
        regionMenu(title: "Pick your growing region")
    }

    /// The manual picker as a Menu with a text-link-styled label —
    /// the same eight regions as Settings, writing the same setting.
    private func regionMenu(title: String) -> some View {
        Menu {
            ForEach(USRegion.allCases) { region in
                Button(region.displayName) {
                    seasonalRegionRaw = region.rawValue
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.fluffyButton)
                    .foregroundStyle(Color.fluffyAccent)
                    .fixedSize(horizontal: false, vertical: true)
                FluffyRule(weight: 2, color: .fluffyAccent)
            }
            .fixedSize()
        }
    }

    // MARK: - Location

    private func useMyLocation() {
        isLocating = true
        locationFailed = false
        Task {
            let region = await RegionLocator().locateRegion()
            isLocating = false
            if let region {
                seasonalRegionRaw = region.rawValue
            } else {
                // Denied, offline, outside the US, or an unmapped
                // state (Hawaii): stay on the card, note it, and let
                // the manual menu do the job.
                locationFailed = true
            }
        }
    }
}
