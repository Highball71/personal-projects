//
//  HouseholdOnboardingView.swift
//  FluffyList
//
//  After sign-in, if the user has no household: "The Press" step 2.
//  "Who's cooking with you?" — name a household on a solid ink rule
//  and create it, or join one below the "OR JOIN ONE" divider with a
//  six-cell invite code. Service calls unchanged.
//

import SwiftUI

struct HouseholdOnboardingView: View {
    @EnvironmentObject private var householdService: HouseholdService

    @State private var householdName = ""
    @State private var displayName = ""
    @State private var joinCode = ""
    @FocusState private var codeFieldFocused: Bool

    private var canCreate: Bool {
        !householdName.isEmpty && !displayName.isEmpty && !householdService.isLoading
    }

    private var canJoin: Bool {
        joinCode.count == 6 && !displayName.isEmpty && !householdService.isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FluffyMasthead(title: "", dateline: "STEP 2 OF 2")
                    .padding(.horizontal, 22)

                Text("Who's cooking\nwith you?")
                    .font(.fluffyDisplay)
                    .fluffyTracking(-0.025, at: 38)
                    .foregroundStyle(Color.fluffyPrimary)
                    .padding(.horizontal, 22)
                    .padding(.top, 30)
                    .padding(.bottom, 12)

                Text("A household shares one plan, one recipe box, and one list.")
                    .font(.custom(FluffyFace.italic, size: 16))
                    .foregroundStyle(Color.fluffySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)

                // Name the household — value on a solid ink rule; a
                // filled field would break the system.
                inkRuleField(
                    label: "Name your household",
                    placeholder: "e.g. The Night Kitchen",
                    text: $householdName
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 20)

                inkRuleField(
                    label: "Your name",
                    placeholder: "e.g. David",
                    text: $displayName
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 30)

                FluffyFilledButton(title: "Create household") {
                    Task {
                        _ = await householdService.createHousehold(
                            name: householdName,
                            memberDisplayName: displayName
                        )
                    }
                }
                .disabled(!canCreate)
                .opacity(canCreate ? 1 : 0.5)
                .padding(.horizontal, 22)
                .padding(.bottom, 30)

                // Rule-with-centred-label divider
                orDivider
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)

                // Invite code — six equal cells, each a 2px bottom
                // rule only, no boxes.
                codeCells
                    .padding(.horizontal, 22)
                    .padding(.bottom, 15)

                Text("Ask the household creator for the six-character code.")
                    .font(.custom(FluffyFace.italic, size: 14))
                    .foregroundStyle(Color.fluffySecondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)

                FluffyTextLink(title: "Join household") {
                    Task {
                        _ = await householdService.joinHousehold(
                            code: joinCode,
                            memberDisplayName: displayName
                        )
                    }
                }
                .disabled(!canJoin)
                .opacity(canJoin ? 1 : 0.5)
                .padding(.horizontal, 22)
                .padding(.bottom, 15)

                if householdService.isLoading {
                    Text("Working\u{2026}")
                        .font(.fluffyCallout)
                        .foregroundStyle(Color.fluffySecondary)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)
                }

                if let error = householdService.errorMessage {
                    Text(error)
                        .font(.custom(FluffyFace.regular, size: 13))
                        .foregroundStyle(Color.fluffyError)
                        .padding(.horizontal, 22)
                        .padding(.bottom, 10)
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.fluffyBackground)
        .animation(.easeInOut(duration: 0.25), value: householdService.isLoading)
    }

    // MARK: - Ink-Rule Field

    /// Uppercase label over a value set on a 2px SOLID INK rule —
    /// stronger than the form fields elsewhere, per the spec.
    private func inkRuleField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FluffySectionHead(title: label)
            VStack(spacing: 7) {
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.custom(FluffyFace.regular, size: 22))
                            .foregroundStyle(Color.fluffyTertiary)
                    }
                    TextField("", text: text)
                        .font(.custom(FluffyFace.semibold, size: 22))
                        .foregroundStyle(Color.fluffyPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                FluffyRule(weight: 2, color: .fluffyPrimary)
            }
        }
    }

    // MARK: - OR Divider

    private var orDivider: some View {
        HStack(spacing: 12) {
            FluffyRule()
            Text("OR JOIN ONE")
                .font(.fluffySectionHead)
                .fluffyTracking(0.16, at: 11)
                .foregroundStyle(Color.fluffySecondary)
                .fixedSize()
            FluffyRule()
        }
    }

    // MARK: - Code Cells

    /// Six square, equal-width cells, characters at 26pt SemiBold
    /// centred, each cell a 2px bottom rule only. A hidden text field
    /// underneath collects the input.
    private var codeCells: some View {
        ZStack {
            TextField("", text: $joinCode)
                .focused($codeFieldFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .opacity(0.01)
                .onChange(of: joinCode) { _, newValue in
                    let cleaned = String(newValue.prefix(6))
                    if cleaned != newValue { joinCode = cleaned }
                }

            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    VStack(spacing: 6) {
                        Text(character(at: index))
                            .font(.custom(FluffyFace.semibold, size: 26))
                            .foregroundStyle(Color.fluffyPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                        FluffyRule(
                            weight: 2,
                            color: index < joinCode.count ? .fluffyPrimary : .fluffyFieldRule
                        )
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { codeFieldFocused = true }
        }
        .frame(height: 48)
    }

    private func character(at index: Int) -> String {
        guard index < joinCode.count else { return " " }
        let i = joinCode.index(joinCode.startIndex, offsetBy: index)
        return String(joinCode[i]).uppercased()
    }
}
