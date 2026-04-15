//
//  HouseholdOnboardingView.swift
//  FluffyList
//
//  After sign-in, if the user has no household, show this screen
//  to create one or join an existing one by code.
//  Heirloom design tokens throughout.
//

import SwiftUI

struct HouseholdOnboardingView: View {
    @EnvironmentObject private var householdService: HouseholdService

    @State private var mode: OnboardingMode = .choose
    @State private var householdName = ""
    @State private var displayName = ""
    @State private var joinCode = ""

    enum OnboardingMode {
        case choose, create, join
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch mode {
                case .choose:
                    chooseView
                case .create:
                    createView
                case .join:
                    joinView
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fluffyBackground)
            .navigationTitle("Get Started")
            .navigationBarTitleDisplayMode(.large)
            .animation(.easeInOut(duration: 0.25), value: mode)
        }
    }

    // MARK: - Choose Mode

    private var chooseView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.fluffyAmber)

            Text("Set up your household")
                .font(.fluffyDisplaySmall)
                .foregroundStyle(Color.fluffyPrimary)

            Text("Create a new household or join one\nthat someone has already set up.")
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)

            Spacer()

            FluffyPrimaryButton("Create Household", icon: "plus.circle.fill", section: .recipes) {
                mode = .create
            }

            Button {
                mode = .join
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Join with Code")
                }
                .font(.fluffyButton)
                .foregroundStyle(Color.fluffyPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.fluffyBorder, lineWidth: 1)
                )
            }

            Spacer()
                .frame(height: 20)
        }
    }

    // MARK: - Create Household

    private var createView: some View {
        VStack(spacing: 16) {
            Text("Create a Household")
                .font(.fluffyDisplaySmall)
                .foregroundStyle(Color.fluffyPrimary)

            TextField("Household name (e.g. The Alberts)", text: $householdName)
                .textFieldStyle(.roundedBorder)

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            FluffyPrimaryButton("Create", section: .recipes) {
                Task {
                    _ = await householdService.createHousehold(
                        name: householdName,
                        memberDisplayName: displayName
                    )
                }
            }
            .disabled(householdName.isEmpty || displayName.isEmpty || householdService.isLoading)
            .opacity(householdName.isEmpty || displayName.isEmpty ? 0.5 : 1)

            if householdService.isLoading {
                ProgressView()
            }

            errorView

            Button("Back") { mode = .choose }
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffySecondary)

            Spacer()
        }
    }

    // MARK: - Join Household

    private var joinView: some View {
        VStack(spacing: 16) {
            Text("Join a Household")
                .font(.fluffyDisplaySmall)
                .foregroundStyle(Color.fluffyPrimary)

            Text("Ask the household creator for the\n6-character join code.")
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)

            TextField("Join code", text: $joinCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .multilineTextAlignment(.center)

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            FluffyPrimaryButton("Join", section: .recipes) {
                Task {
                    _ = await householdService.joinHousehold(
                        code: joinCode,
                        memberDisplayName: displayName
                    )
                }
            }
            .disabled(joinCode.count != 6 || displayName.isEmpty || householdService.isLoading)
            .opacity(joinCode.count != 6 || displayName.isEmpty ? 0.5 : 1)

            if householdService.isLoading {
                ProgressView()
            }

            errorView

            Button("Back") { mode = .choose }
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffySecondary)

            Spacer()
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorView: some View {
        if let error = householdService.errorMessage {
            Text(error)
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffyError)
                .padding(.horizontal)
        }
    }
}
