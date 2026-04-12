//
//  HouseholdOnboardingView.swift
//  FluffyList
//
//  After sign-in, if the user has no household, show this screen
//  to create one or join an existing one by code.
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
        }
    }

    // MARK: - Choose Mode

    private var chooseView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "house.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.fluffyAccent)

            Text("Set up your household")
                .font(.title2.bold())
                .foregroundStyle(Color.fluffyPrimary)

            Text("Create a new household or join one that someone has already set up.")
                .font(.body)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                mode = .create
            } label: {
                Label("Create Household", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.fluffyAccent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                mode = .join
            } label: {
                Label("Join with Code", systemImage: "person.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.fluffyCard)
                    .foregroundStyle(Color.fluffyPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
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
                .font(.title2.bold())
                .foregroundStyle(Color.fluffyPrimary)

            TextField("Household name (e.g. The Alberts)", text: $householdName)
                .textFieldStyle(.roundedBorder)

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    let success = await householdService.createHousehold(
                        name: householdName,
                        memberDisplayName: displayName
                    )
                    if !success {
                        // Error is shown via householdService.errorMessage
                    }
                }
            } label: {
                if householdService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Create")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.fluffyAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(householdName.isEmpty || displayName.isEmpty || householdService.isLoading)

            errorView

            Button("Back") { mode = .choose }
                .foregroundStyle(Color.fluffySecondary)

            Spacer()
        }
    }

    // MARK: - Join Household

    private var joinView: some View {
        VStack(spacing: 16) {
            Text("Join a Household")
                .font(.title2.bold())
                .foregroundStyle(Color.fluffyPrimary)

            Text("Ask the household creator for the 6-character join code.")
                .font(.subheadline)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)

            TextField("Join code", text: $joinCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.title2.monospaced())
                .multilineTextAlignment(.center)

            TextField("Your name", text: $displayName)
                .textFieldStyle(.roundedBorder)

            Button {
                print("🟡 [HouseholdOnboardingView] Join tapped — code=\"\(joinCode)\", displayName=\"\(displayName)\"")
                Task {
                    let success = await householdService.joinHousehold(
                        code: joinCode,
                        memberDisplayName: displayName
                    )
                    print("🟢 [HouseholdOnboardingView] joinHousehold returned success=\(success)")
                    if !success {
                        // Error is shown via householdService.errorMessage
                    }
                }
            } label: {
                if householdService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Join")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.fluffyAccent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(joinCode.count != 6 || displayName.isEmpty || householdService.isLoading)

            errorView

            Button("Back") { mode = .choose }
                .foregroundStyle(Color.fluffySecondary)

            Spacer()
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorView: some View {
        if let error = householdService.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }
}
