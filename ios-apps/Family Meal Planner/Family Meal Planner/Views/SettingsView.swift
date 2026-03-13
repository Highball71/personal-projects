//
//  SettingsView.swift
//  FluffyList
//

import SwiftUI
import SwiftData
import CloudKit
import os

/// Settings screen with household management and API key configuration.
/// The Household section lets you add family members and designate a
/// Head Cook who approves the weekly meal plan.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncMonitor.self) private var syncMonitor
    @Query(sort: \HouseholdMember.name) private var members: [HouseholdMember]

    // Device-local: remembers which household member is using this device.
    // Not synced via CloudKit — each device picks independently.
    @AppStorage("currentUserName") private var currentUserName: String = ""

    @State private var apiKeyText = ""
    @State private var existingKeyHint = ""
    @State private var showingSavedConfirmation = false
    @State private var saveError: String?
    @State private var newMemberName = ""

    // Sharing state
    @State private var isLoadingShare = false
    @State private var showCloudKitAlert = false

    var body: some View {
        NavigationStack {
            Form {
                householdSection
                headCookSection
                sharingSection
                apiKeySection

                if showingSavedConfirmation {
                    Section {
                        Label("Key saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if let error = saveError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadExistingKeyHint()
            }
            .alert("iCloud Required", isPresented: $showCloudKitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Sign in to iCloud in Settings to share your recipe library with household members.")
            }
        }
    }

    // MARK: - Household Section

    private var householdSection: some View {
        Section {
            // Add a new member
            HStack {
                TextField("Add family member", text: $newMemberName)
                    .textContentType(.name)
                    .submitLabel(.done)
                    .onSubmit { addMember() }

                Button(action: addMember) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(newMemberName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // List existing members
            ForEach(members) { member in
                HStack {
                    if member.isHeadCook {
                        Image(systemName: "frying.pan.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                    Text(member.name)
                    if member.isHeadCook {
                        Text("Head Cook")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .onDelete(perform: deleteMembers)

            // "You are" picker — device-local identity
            if !members.isEmpty {
                Picker("You are", selection: $currentUserName) {
                    Text("Not set").tag("")
                    ForEach(members) { member in
                        Text(member.name).tag(member.name)
                    }
                }
            }
        } header: {
            Text("Household")
        } footer: {
            Text("Add your family members here. Pick \"You are\" so the app knows who's using this device.")
        }
    }

    // MARK: - Head Cook Section

    private var headCookSection: some View {
        Section {
            if members.isEmpty {
                Text("Add family members above first")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(members) { member in
                    Button {
                        setHeadCook(member)
                    } label: {
                        HStack {
                            Text(member.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if member.isHeadCook {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                // Option to clear the Head Cook (disables approval flow)
                if members.contains(where: { $0.isHeadCook }) {
                    Button("Remove Head Cook", role: .destructive) {
                        clearHeadCook()
                    }
                }
            }
        } header: {
            Text("Head Cook")
        } footer: {
            Text("The Head Cook has final say on the weekly meal plan. Others can suggest recipes, but the Head Cook approves them. Leave unset to skip the approval flow.")
        }
    }

    // MARK: - Sharing Section

    private var sharingSection: some View {
        Section {
            Button {
                generateShareURL()
            } label: {
                HStack {
                    Label("Share with Household", systemImage: "person.2.fill")
                    Spacer()
                    if isLoadingShare {
                        ProgressView()
                    }
                }
            }
            .disabled(isLoadingShare)

            // Subtle sync status indicator
            SyncStatusRow(syncState: syncMonitor.syncState, isOffline: syncMonitor.isOffline)
        } header: {
            Text("iCloud Sharing")
        } footer: {
            Text("Share your recipe library with household members so everyone sees the same recipes, meal plans, and grocery lists.")
        }
    }

    private func generateShareURL() {
        isLoadingShare = true
        Task {
            guard await CloudKitSharingService.shared.isCloudKitAvailable() else {
                isLoadingShare = false
                showCloudKitAlert = true
                return
            }

            // Use existing share if one was already created.
            if let existingURL = await CloudKitSharingService.shared.existingShareURL() {
                isLoadingShare = false
                presentShareSheet(url: existingURL)
                return
            }

            // Create a new zone-wide share.
            do {
                let url = try await CloudKitSharingService.shared.createHouseholdShare()
                isLoadingShare = false
                presentShareSheet(url: url)
            } catch {
                isLoadingShare = false
                Logger.cloudkit.error("Failed to create share: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Presents the system share sheet imperatively via UIKit.
    /// UIActivityViewController must be presented directly — wrapping it
    /// inside a SwiftUI .sheet causes a double-modal conflict that
    /// silently prevents the share sheet from appearing.
    private func presentShareSheet(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // iPad requires popover source configuration.
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        // Walk up to the topmost presented controller (Settings is already modal).
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(activityVC, animated: true)
    }

    // MARK: - API Key Section

    private var apiKeySection: some View {
        Section {
            SecureField("sk-ant-...", text: $apiKeyText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !existingKeyHint.isEmpty {
                Text("Current key: \(existingKeyHint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Save Key") {
                saveAPIKey()
            }
            .disabled(apiKeyText.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("Anthropic API Key")
        } footer: {
            Text("Required for photo scanning and recipe import. Your key is stored securely in the device Keychain.")
        }
    }

    // MARK: - Household Actions

    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Don't add duplicates
        guard !members.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            newMemberName = ""
            return
        }

        let member = HouseholdMember(name: trimmed)
        modelContext.insert(member)
        newMemberName = ""

        // If this is the first member added, auto-select as "You are"
        if members.count == 0 {
            currentUserName = trimmed
        }
    }

    private func deleteMembers(at offsets: IndexSet) {
        for index in offsets {
            let member = members[index]
            // If deleting the current user, clear the selection
            if member.name == currentUserName {
                currentUserName = ""
            }
            modelContext.delete(member)
        }
    }

    private func setHeadCook(_ member: HouseholdMember) {
        // Clear any existing Head Cook first
        for m in members {
            m.isHeadCook = false
        }
        member.isHeadCook = true
    }

    private func clearHeadCook() {
        for m in members {
            m.isHeadCook = false
        }
    }

    // MARK: - API Key Actions

    /// Check if a key already exists and show the last 4 chars masked.
    private func loadExistingKeyHint() {
        if let key = try? KeychainHelper.getAnthropicAPIKey(), key.count >= 4 {
            let lastFour = String(key.suffix(4))
            existingKeyHint = "••••••\(lastFour)"
        }
    }

    /// Save the entered key to Keychain.
    private func saveAPIKey() {
        let trimmed = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try KeychainHelper.setAnthropicAPIKey(trimmed)
            apiKeyText = ""
            saveError = nil
            showingSavedConfirmation = true
            loadExistingKeyHint()
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
            showingSavedConfirmation = false
        }
    }
}

// MARK: - Sync Status Row

/// Small read-only row that shows the current iCloud sync state.
struct SyncStatusRow: View {
    let syncState: SyncMonitor.SyncState
    let isOffline: Bool

    private var icon: String {
        if isOffline { return "wifi.slash" }
        switch syncState {
        case .synced:  return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        if isOffline { return .orange }
        switch syncState {
        case .synced:  return .green
        case .syncing: return .blue
        case .error:   return .red
        }
    }

    private var label: String {
        if isOffline { return "Offline" }
        switch syncState {
        case .synced:       return "Synced"
        case .syncing:      return "Syncing…"
        case .error(let m): return "Sync error: \(m)"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: syncState == .syncing)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [HouseholdMember.self], inMemory: true)
        .environment(SyncMonitor())
}
