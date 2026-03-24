//
//  SettingsView.swift
//  FluffyList
//

import SwiftUI
import SwiftData
import CloudKit
import CoreData
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

    @State private var newMemberName = ""

    // Sharing state
    @State private var isLoadingShare = false
    @State private var shareTask: Task<Void, Never>?
    @State private var sharingDelegate: CloudSharingDelegate?
    @State private var showCloudKitAlert = false
    @State private var showContainerUnavailableAlert = false
    @State private var showingShareError = false
    @State private var shareErrorMessage = ""
    @State private var showingResetConfirm = false

    #if DEBUG
    @State private var showDiagAlert = false
    @State private var diagAlertMessage = ""
    #endif

    var body: some View {
        NavigationStack {
            Form {
                householdSection
                headCookSection
                sharingSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("iCloud Required", isPresented: $showCloudKitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Sign in to iCloud in Settings to share your recipe library with household members.")
            }
            .alert("Sync Not Ready", isPresented: $showContainerUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("CloudKit hasn't synced yet. Wait a moment and try again.")
            }
            .alert("Couldn't Create Share Link", isPresented: $showingShareError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(shareErrorMessage)
            }
            .confirmationDialog(
                "Delete the existing share link?",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Share", role: .destructive) { resetSharing() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All household members will lose access. You can create a new share link afterwards.")
            }
            #if DEBUG
            .alert("Container Diagnostic", isPresented: $showDiagAlert) {
                Button("Continue") { executeShareFlow() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(diagAlertMessage)
            }
            #endif
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
            // Tapping while the spinner is showing cancels the in-flight operation.
            Button {
                if isLoadingShare { cancelShare() } else { generateShareURL() }
            } label: {
                HStack {
                    if isLoadingShare {
                        Label("Cancel", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    } else {
                        Label("Share with Household", systemImage: "person.2.fill")
                    }
                    Spacer()
                    if isLoadingShare {
                        ProgressView()
                    }
                }
            }

            // Subtle sync status indicator
            SyncStatusRow(syncState: syncMonitor.syncState, isOffline: syncMonitor.isOffline)

            Button("Reset Sharing", role: .destructive) {
                showingResetConfirm = true
            }
            .disabled(isLoadingShare)
        } header: {
            Text("iCloud Sharing")
        } footer: {
            Text("Share your recipe library with household members so everyone sees the same recipes, meal plans, and grocery lists.")
        }
    }

    private func generateShareURL() {
        #if DEBUG
        // Show container status before starting — tap Continue to proceed, Cancel to abort.
        let isNil = syncMonitor.persistentContainer == nil
        diagAlertMessage = isNil
            ? "persistentContainer: nil\n\nNot yet captured from sync event notifications. The direct-CloudKit fallback will be attempted."
            : "persistentContainer: available ✓\n\nReady to call share(_:to:completion:)."
        showDiagAlert = true
        // Execution resumes when the user taps Continue in the diagnostic alert.
        #else
        executeShareFlow()
        #endif
    }

    /// Runs the actual share flow. Called directly in release builds and via the
    /// Continue button in the DEBUG diagnostic alert.
    private func executeShareFlow() {
        isLoadingShare = true

        shareTask = Task {
            defer { isLoadingShare = false }

            guard await CloudKitSharingService.shared.isCloudKitAvailable() else {
                showCloudKitAlert = true
                return
            }

            if let persistentContainer = syncMonitor.persistentContainer {
                // Normal path: container captured — use NSPersistentCloudKitContainer API.
                // prepareShare always deletes any existing share before creating a fresh one,
                // so there is no fast path for an existing share here.
                do {
                    let (share, container) = try await CloudKitSharingService.shared.prepareShare(
                        using: persistentContainer
                    )
                    guard !Task.isCancelled else { return }
                    presentCloudSharingController(share: share, container: container)
                } catch is CancellationError {
                    // User tapped Cancel — spinner is already hidden by cancelShare().
                } catch {
                    guard !Task.isCancelled else { return }
                    shareErrorMessage = error.localizedDescription
                    showingShareError = true
                    Logger.cloudkit.error("Failed to prepare share: \(error.localizedDescription, privacy: .public)")
                }
            } else {
                // Fallback: persistentContainer is nil — not yet captured from sync event
                // notifications (e.g. hard reset deleted the zone; SwiftData hasn't restarted
                // sync). Query CloudKit directly for an existing share; no container needed.
                Logger.cloudkit.warning("persistentContainer nil at share time — trying direct CloudKit fallback")
                do {
                    let ckContainer = CKContainer(identifier: CloudKitSharingService.containerIdentifier)
                    if let share = try await CloudKitSharingService.shared.fetchExistingShareDirect() {
                        presentCloudSharingController(share: share, container: ckContainer)
                    } else {
                        // No existing share and no container to create one — wait for sync.
                        showContainerUnavailableAlert = true
                    }
                } catch is CancellationError {
                    // User tapped Cancel
                } catch {
                    guard !Task.isCancelled else { return }
                    shareErrorMessage = error.localizedDescription
                    showingShareError = true
                }
            }
        }
    }

    /// Cancels any in-flight share operation and resets the loading state immediately.
    private func cancelShare() {
        shareTask?.cancel()
        shareTask = nil
        isLoadingShare = false
    }

    /// Hard-resets sharing state: cancels in-flight tasks, clears cached delegate,
    /// then nukes the CKShare directly from CloudKit (bypassing the container).
    private func resetSharing() {
        // Step 1: cancel any in-flight operation and clear all cached state.
        shareTask?.cancel()
        shareTask = nil
        sharingDelegate = nil

        // Step 2: start the hard reset. The container is passed as Optional —
        // hardResetSharing's primary path (direct zone query) works without it,
        // so this succeeds even if persistentContainer is nil.
        isLoadingShare = true
        shareTask = Task {
            defer { isLoadingShare = false }
            do {
                try await CloudKitSharingService.shared.hardResetSharing(
                    persistentContainer: syncMonitor.persistentContainer
                )
            } catch is CancellationError {
                // User tapped Cancel — spinner is already hidden.
            } catch {
                shareErrorMessage = error.localizedDescription
                showingShareError = true
            }
        }
    }

    /// Presents UICloudSharingController imperatively via UIKit.
    /// UICloudSharingController must be presented directly — wrapping it inside a
    /// SwiftUI .sheet causes a double-modal conflict that prevents it from appearing.
    private func presentCloudSharingController(share: CKShare, container: CKContainer) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return
        }

        let sharingController = UICloudSharingController(share: share, container: container)
        // Allow participants to read and write; keep the share private (invite-only).
        sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]

        // Attach delegate so applicationVersion is cleared again after every
        // participant change (UICloudSharingController re-sets it on each save).
        let delegate = CloudSharingDelegate(container: container)
        sharingDelegate = delegate           // retain: SwiftUI @State keeps it alive
        sharingController.delegate = delegate

        // iPad requires popover source configuration.
        if let popover = sharingController.popoverPresentationController {
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
        presenter.present(sharingController, animated: true)
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

// MARK: - Cloud Sharing Delegate

/// UICloudSharingControllerDelegate that keeps applicationVersion cleared.
///
/// Root cause of the recurring "newer version" error: UICloudSharingController
/// saves the CKShare to CloudKit whenever the owner manages participants, and
/// iOS re-injects the `applicationVersion` field on every save. Our pre-presentation
/// clear is not enough — the controller writes the field back after we present it.
///
/// `cloudSharingControllerDidSaveShare(_:)` fires immediately after the controller
/// finishes its CloudKit write, giving us the hook we need to clear the field again.
final class CloudSharingDelegate: NSObject, UICloudSharingControllerDelegate {
    private let container: CKContainer

    init(container: CKContainer) {
        self.container = container
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        "Family Meal Planner"
    }

    func cloudSharingController(
        _ csc: UICloudSharingController,
        failedToSaveShareWithError error: Error
    ) {
        Logger.cloudkit.error(
            "UICloudSharingController save failed: \(error.localizedDescription, privacy: .public)"
        )
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        guard let share = csc.share else { return }
        // Clear applicationVersion on the share the controller just wrote back.
        Task { @MainActor in
            await CloudKitSharingService.shared.clearApplicationVersion(
                from: share, using: container
            )
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [HouseholdMember.self], inMemory: true)
        .environment(SyncMonitor())
}
