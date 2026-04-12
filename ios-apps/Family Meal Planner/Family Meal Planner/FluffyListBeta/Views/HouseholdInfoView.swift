//
//  HouseholdInfoView.swift
//  FluffyList
//
//  Shows household details: name, join code (for sharing),
//  member list, and sign-out button.
//

import SwiftUI

struct HouseholdInfoView: View {
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let household = householdService.household {
                    Section("Household") {
                        LabeledContent("Name", value: household.name)
                    }

                    Section {
                        HStack {
                            Text((household.joinCode ?? "------").uppercased())
                                .font(.title2.monospaced().bold())
                                .foregroundStyle(Color.fluffyAccent)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = household.joinCode ?? ""
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                        }
                    } header: {
                        Text("Join Code")
                    } footer: {
                        Text("Share this code with family members so they can join your household.")
                    }
                }

                Section("Members") {
                    if householdService.isLoadingMembers || !householdService.membersLoaded {
                        HStack {
                            ProgressView()
                            Text("Loading...")
                                .foregroundStyle(Color.fluffySecondary)
                        }
                    } else if householdService.members.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No members found.")
                                .foregroundStyle(Color.fluffySecondary)
                            if let error = householdService.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    } else {
                        ForEach(householdService.members) { member in
                            HStack {
                                Text(member.displayName)
                                Spacer()
                                if member.isHeadCook {
                                    Text("Head Cook")
                                        .font(.caption)
                                        .foregroundStyle(Color.fluffyAccent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await authService.signOut()
                            dismiss()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Household")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await householdService.loadMembers()
            }
        }
    }
}
