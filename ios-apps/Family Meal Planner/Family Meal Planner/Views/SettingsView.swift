//
//  SettingsView.swift
//  Family Meal Planner
//

import SwiftUI
import CloudKit
import CoreData
import os

/// Settings screen with household management and API key configuration.
/// The Household section lets you add family members and designate a
/// Head Cook who approves the weekly meal plan.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(SyncMonitor.self) private var syncMonitor
    @EnvironmentObject private var persistence: PersistenceController

    @FetchRequest(
        entity: CDHousehold.entity(),
        sortDescriptors: []
    ) private var households: FetchedResults<CDHousehold>

    @FetchRequest(
        entity: CDHouseholdMember.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDHouseholdMember.name, ascending: true)]
    ) private var members: FetchedResults<CDHouseholdMember>

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

    // Debug reset state
    @State private var isResettingLocalState = false
    @State private var showingLocalResetConfirm = false
    @State private var showingCloudResetConfirm = false
    @State private var showResetSuccessAlert = false
    @State private var resetSuccessMessage = ""


    var body: some View {
        NavigationStack {
            Form {
                householdSection
                headCookSection
                sharingSection

                #if DEBUG
                debugSection
                #endif
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
            .alert("Reset Complete", isPresented: $showResetSuccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resetSuccessMessage)
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
            .confirmationDialog(
                "Reset Local Sync State?",
                isPresented: $showingLocalResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Local Data", role: .destructive) { performLocalReset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all local Core Data stores and rebuilds the container. CloudKit will re-download your data. Use this when sharing is stuck.")
            }
            .confirmationDialog(
                "Reset CloudKit Sharing State?",
                isPresented: $showingCloudResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Server Shares", role: .destructive) { performCloudReset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes all CKShare records from CloudKit. Household members will lose access until you re-share.")
            }
        }
    }

    // MARK: - Household Section

    private var householdSection: some View {
        Section {
            // During a reset, the @FetchRequest holds stale CDHouseholdMember
            // objects from the destroyed context. Accessing them crashes with
            // "persistent store is not reachable". Show a placeholder instead.
            if isResettingLocalState {
                HStack {
                    ProgressView()
                    Text("Resetting…")
                        .foregroundStyle(.secondary)
                }
            } else {
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
            // Guard against stale @FetchRequest objects during a reset.
            if isResettingLocalState {
                EmptyView()
            } else if members.isEmpty {
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

    /// Whether we should enable the Share button. We no longer require
    /// SyncMonitor to have captured a container — the share flow falls back
    /// to PersistenceController's container if needed. We only disable when
    /// we know for sure something is wrong (offline or active sync error).
    private var isSyncReady: Bool {
        if syncMonitor.isOffline { return false }
        if case .error = syncMonitor.syncState { return false }
        return true
    }

    private var sharingSection: some View {
        Section {
            // Tapping while the spinner is showing cancels the in-flight operation.
            Button {
                Logger.cloudkit.info("Share button tapped — isLoadingShare=\(isLoadingShare)")
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
            .disabled(!isSyncReady && !isLoadingShare)

            // Subtle sync status indicator
            SyncStatusRow(
                syncState: syncMonitor.syncState,
                isOffline: syncMonitor.isOffline,
                lastErrorMessage: syncMonitor.lastErrorMessage
            )

            Button("Reset Sharing", role: .destructive) {
                showingResetConfirm = true
            }
            .disabled(isLoadingShare)
        } header: {
            Text("iCloud Sharing")
        } footer: {
            if syncMonitor.isOffline {
                Text("You appear to be offline. Connect to the internet to share your recipe library.")
            } else if case .error(let msg) = syncMonitor.syncState {
                Text("Sync issue: \(msg). Try again or use Debug Recovery tools.")
            } else {
                Text("Share your recipe library with household members so everyone sees the same recipes, meal plans, and grocery lists.")
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        Section {
            // Reset Local Sync State — destroys SQLite files, rebuilds container
            Button {
                showingLocalResetConfirm = true
            } label: {
                HStack {
                    Label("Reset Local Sync State", systemImage: "arrow.counterclockwise.circle")
                    Spacer()
                    if isResettingLocalState {
                        ProgressView()
                    }
                }
            }
            .disabled(isResettingLocalState || isLoadingShare)

            // Reset CloudKit Sharing State — server-side only
            Button {
                showingCloudResetConfirm = true
            } label: {
                Label("Reset CloudKit Sharing State", systemImage: "cloud.bolt")
            }
            .disabled(isResettingLocalState || isLoadingShare)

            // Force Clean Share Attempt — resets local + immediately shares
            Button {
                performForceCleanShare()
            } label: {
                HStack {
                    Label("Force Clean Share Attempt", systemImage: "bolt.circle")
                    Spacer()
                    if isResettingLocalState {
                        ProgressView()
                    }
                }
            }
            .disabled(isResettingLocalState || isLoadingShare)

        } header: {
            Text("Debug Recovery")
        } footer: {
            Text("\"Reset Local\" destroys local stores and lets CloudKit re-download. \"Reset CloudKit\" deletes server-side shares only. \"Force Clean Share\" does a full local reset then immediately attempts to share.")
        }
    }
    #endif

    // MARK: - Share Flow

    private func generateShareURL() {
        Logger.cloudkit.info("generateShareURL: entered")
        #if DEBUG
        let monitorContainer = syncMonitor.persistentContainer
        let isSame = monitorContainer === persistence.container
        let message: String
        if monitorContainer == nil {
            message = "SyncMonitor container: nil\nWill use PersistenceController container directly."
        } else {
            message = "SyncMonitor container: available\nMatches PersistenceController: \(isSame ? "YES" : "NO — will fix stale reference")"
        }
        Logger.cloudkit.info("Container Diagnostic: \(message, privacy: .public)")
        executeShareFlow()
        #else
        executeShareFlow()
        #endif
    }

    /// Runs the actual share flow using object-level sharing on CDHousehold.
    private func executeShareFlow() {
        Logger.cloudkit.info("executeShareFlow: entered — isLoadingShare=\(isLoadingShare), shareTask=\(shareTask == nil ? "nil" : "exists")")
        isLoadingShare = true

        shareTask = Task {
            defer { isLoadingShare = false }

            Logger.cloudkit.info("executeShareFlow: Task started, checking iCloud availability")
            guard await CloudKitSharingService.shared.isCloudKitAvailable() else {
                Logger.cloudkit.warning("executeShareFlow: iCloud NOT available — bailing out")
                showCloudKitAlert = true
                return
            }
            Logger.cloudkit.info("executeShareFlow: iCloud available, checking households (count=\(households.count))")

            guard let household = households.first else {
                Logger.cloudkit.warning("executeShareFlow: no household found — bailing out")
                shareErrorMessage = CloudKitSharingError.noHouseholdToShare.localizedDescription
                showingShareError = true
                return
            }
            Logger.cloudkit.info("executeShareFlow: household found — \(household.objectID)")

            let targetContainer = persistence.container

            // Fix stale SyncMonitor reference if needed.
            if let monitored = syncMonitor.persistentContainer, monitored !== targetContainer {
                Logger.cloudkit.info("executeShareFlow: fixing stale SyncMonitor container reference")
                syncMonitor.attach(to: targetContainer)
            }

            do {
                Logger.cloudkit.info("executeShareFlow: calling startShareFlow — Task.isCancelled=\(Task.isCancelled)")
                let (share, container) = try await CloudKitSharingService.shared.startShareFlow(
                    household: household,
                    container: targetContainer,
                    syncMonitor: syncMonitor
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        presentCloudSharingController(share: share, container: container)
                    }
                }
            } catch is CancellationError {
                // User tapped Cancel
            } catch {
                guard !Task.isCancelled else { return }
                shareErrorMessage = error.localizedDescription
                showingShareError = true
                Logger.cloudkit.error("Failed to start share flow: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func cancelShare() {
        shareTask?.cancel()
        shareTask = nil
        isLoadingShare = false
    }

    private func resetSharing() {
        shareTask?.cancel()
        shareTask = nil
        sharingDelegate = nil

        isLoadingShare = true
        shareTask = Task {
            defer { isLoadingShare = false }
            guard let household = households.first else { return }
            do {
                try await CloudKitSharingService.shared.deleteShare(
                    for: household, container: persistence.container
                )
            } catch is CancellationError {
                // User tapped Cancel
            } catch {
                shareErrorMessage = error.localizedDescription
                showingShareError = true
            }
        }
    }

    // MARK: - Debug Recovery Actions

    /// Performs a full local store reset and container rebuild.
    /// This is the primary fix for the sharing hang.
    ///
    /// During the reset, PersistenceController.isResetting removes ALL views
    /// (including this sheet) from the hierarchy at the app root level. This
    /// prevents stale @FetchRequest crashes across every view in the app.
    private func performLocalReset() {
        isResettingLocalState = true

        Task {
            defer { isResettingLocalState = false }

            do {
                // Single call handles everything: detach SyncMonitor, destroy stores,
                // rebuild container, recreate household, reattach SyncMonitor.
                try await persistence.resetLocalStoresAndRebuildContainer(syncMonitor: syncMonitor)

                Logger.cloudkit.info("Local store reset completed successfully")

                // No need to dismiss — PersistenceController.isResetting removes
                // ALL @FetchRequest views from the hierarchy at the app root level.
                // When isResetting clears, a fresh ContentView is created.
            } catch {
                shareErrorMessage = "Local reset failed: \(error.localizedDescription)"
                showingShareError = true
                Logger.cloudkit.error("Local store reset failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Deletes the server-side share without touching local stores.
    private func performCloudReset() {
        isResettingLocalState = true

        Task {
            defer { isResettingLocalState = false }
            guard let household = households.first else {
                isResettingLocalState = false
                return
            }
            do {
                try await CloudKitSharingService.shared.deleteShare(
                    for: household, container: persistence.container
                )
                resetSuccessMessage = "CloudKit sharing state has been reset. You can now create a fresh share."
                showResetSuccessAlert = true
            } catch {
                shareErrorMessage = "CloudKit reset failed: \(error.localizedDescription)"
                showingShareError = true
            }
        }
    }

    /// Nuclear share reset: deletes ALL server-side shares, waits for
    /// the mirror to settle, then creates a brand-new share on the EXISTING
    /// stable container. Does NOT destroy local stores or rebuild the container
    /// (that was causing container.share(...) to hang indefinitely).
    private func performForceCleanShare() {
        Logger.cloudkit.info("performForceCleanShare: entered — isLoadingShare=\(isLoadingShare)")
        isLoadingShare = true

        shareTask = Task {
            defer { isLoadingShare = false }

            guard let household = households.first else {
                Logger.cloudkit.error("performForceCleanShare: no household")
                shareErrorMessage = CloudKitSharingError.noHouseholdToShare.localizedDescription
                showingShareError = true
                return
            }

            do {
                let (share, container) = try await CloudKitSharingService.shared.nuclearShareReset(
                    household: household,
                    container: persistence.container,
                    syncMonitor: syncMonitor
                )
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        presentCloudSharingController(share: share, container: container)
                    }
                }

            } catch is CancellationError {
                // User cancelled
            } catch {
                guard !Task.isCancelled else { return }
                Logger.cloudkit.error("performForceCleanShare failed: \(error.localizedDescription, privacy: .public)")
                shareErrorMessage = "Clean share failed: \(error.localizedDescription)"
                showingShareError = true
            }
        }
    }

    /// Walks the UIKit hierarchy to find the top-most view controller
    /// whose view is actually in a window. Handles UINavigationController
    /// and UITabBarController containers along the way.
    @MainActor
    private func findTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }

        var candidate = rootVC
        while true {
            if let nav = candidate as? UINavigationController,
               let visible = nav.visibleViewController {
                candidate = visible
            } else if let tab = candidate as? UITabBarController,
                      let selected = tab.selectedViewController {
                candidate = selected
            } else if let presented = candidate.presentedViewController,
                      presented.view.window != nil {
                candidate = presented
            } else {
                break
            }
        }

        // Reject PresentationHostingController — it's a SwiftUI sheet host that
        // may be mid-dismissal and not suitable for presenting new controllers.
        let typeName = String(describing: type(of: candidate))
        if typeName.contains("PresentationHostingController") {
            Logger.cloudkit.info("findTopViewController: rejected stale PresentationHostingController, using rootVC instead")
            return rootVC.view.window != nil ? rootVC : nil
        }

        // If the candidate ended up detached, fall back to rootVC.
        if candidate.view.window == nil {
            return rootVC.view.window != nil ? rootVC : nil
        }
        return candidate
    }

    /// Presents share link alert (existing share) or UICloudSharingController (new share).
    @MainActor
    private func presentCloudSharingController(share: CKShare, container: CKContainer) {
        Logger.cloudkit.info("presentCloudSharingController: entered (shareURL=\(share.url?.absoluteString ?? "nil", privacy: .public))")

        if let shareURL = share.url {
            // Existing share with URL — copy to clipboard and show alert.
            Logger.cloudkit.info("presentCloudSharingController: existing share URL — copying to clipboard")
            UIPasteboard.general.url = shareURL
            Logger.cloudkit.info("presentCloudSharingController: clipboard copy done (hasURL=\(UIPasteboard.general.hasURLs))")

            let alert = UIAlertController(
                title: "Share Link Ready",
                message: "The household share link has been copied to the clipboard.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            alert.addAction(UIAlertAction(title: "Open Link", style: .default) { _ in
                UIApplication.shared.open(shareURL)
            })

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard let presenter = self.findTopViewController() else {
                    Logger.cloudkit.error("presentCloudSharingController: no live presenter found")
                    return
                }
                Logger.cloudkit.info("presentCloudSharingController: presenting share link alert from \(String(describing: type(of: presenter)))")
                presenter.present(alert, animated: true)
            }
            return
        }

        // New share — use UICloudSharingController.
        Logger.cloudkit.info("presentCloudSharingController: no share URL — using UICloudSharingController")
        let sharingController = UICloudSharingController(share: share, container: container)
        sharingController.modalPresentationStyle = .formSheet
        sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]

        let delegate = CloudSharingDelegate(container: container)
        sharingDelegate = delegate
        sharingController.delegate = delegate

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard let presenter = self.findTopViewController() else {
                Logger.cloudkit.error("presentCloudSharingController: no live presenter found")
                return
            }

            Logger.cloudkit.info("presentCloudSharingController: live presenter=\(String(describing: type(of: presenter))), inWindow=\(presenter.view.window != nil)")

            guard presenter.view.window != nil else {
                Logger.cloudkit.error("presentCloudSharingController: live presenter not in window hierarchy")
                return
            }

            if let popover = sharingController.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }

            Logger.cloudkit.info("presentCloudSharingController: about to present UICloudSharingController")
            presenter.present(sharingController, animated: true)
            Logger.cloudkit.info("presentCloudSharingController: present(...) returned")
        }
    }

    // MARK: - Household Actions

    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard !members.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            newMemberName = ""
            return
        }

        let member = CDHouseholdMember(context: viewContext)
        member.id = UUID()
        member.name = trimmed
        member.isHeadCook = false
        newMemberName = ""

        if members.count == 0 {
            currentUserName = trimmed
        }

        try? viewContext.save()
    }

    private func deleteMembers(at offsets: IndexSet) {
        for index in offsets {
            let member = members[index]
            if member.name == currentUserName {
                currentUserName = ""
            }
            viewContext.delete(member)
        }
        try? viewContext.save()
    }

    private func setHeadCook(_ member: CDHouseholdMember) {
        for m in members {
            m.isHeadCook = false
        }
        member.isHeadCook = true
        try? viewContext.save()
    }

    private func clearHeadCook() {
        for m in members {
            m.isHeadCook = false
        }
        try? viewContext.save()
    }

}

// MARK: - Sync Status Row

/// Small read-only row that shows the current iCloud sync state.
/// Labels are intentionally conservative — "iCloud connected" rather than
/// "Ready to share" — because .synced only reflects the last event, not
/// whether the internal pipeline is truly idle.
struct SyncStatusRow: View {
    let syncState: SyncMonitor.SyncState
    let isOffline: Bool
    /// Sticky error message from SyncMonitor — persists even when state
    /// flips back to .syncing, so the user can actually read it.
    var lastErrorMessage: String? = nil

    private var icon: String {
        if isOffline { return "wifi.slash" }
        switch syncState {
        case .synced:  return "checkmark.circle.fill"
        case .syncing:
            // Show warning icon if there was a recent error
            return lastErrorMessage != nil ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        if isOffline { return .orange }
        switch syncState {
        case .synced:  return .green
        case .syncing: return lastErrorMessage != nil ? .orange : .blue
        case .error:   return .red
        }
    }

    private var label: String {
        if isOffline { return "Offline" }
        switch syncState {
        case .synced:
            return "iCloud connected"
        case .syncing:
            // If there was a recent error, show it instead of just "Syncing..."
            if let msg = lastErrorMessage {
                return "Syncing (last error: \(msg))"
            }
            return "Syncing..."
        case .error(let m):
            return "Sync issue: \(m)"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .symbolEffect(.pulse, isActive: syncState == .syncing && lastErrorMessage == nil)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Cloud Sharing Delegate

/// UICloudSharingControllerDelegate that keeps applicationVersion cleared.
final class CloudSharingDelegate: NSObject, UICloudSharingControllerDelegate {
    private let container: CKContainer

    init(container: CKContainer) {
        self.container = container
        Logger.cloudkit.info("CloudSharingDelegate: initialized")
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        Logger.cloudkit.info("CloudSharingDelegate: itemTitle called")
        return "Family Meal Planner"
    }

    func cloudSharingController(
        _ csc: UICloudSharingController,
        failedToSaveShareWithError error: Error
    ) {
        Logger.cloudkit.error(
            "CloudSharingDelegate: failedToSaveShare — \(error.localizedDescription, privacy: .public)"
        )
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        Logger.cloudkit.info("CloudSharingDelegate: didSaveShare")
        guard let share = csc.share else {
            Logger.cloudkit.warning("CloudSharingDelegate: didSaveShare but share is nil")
            return
        }
        Task { @MainActor in
            await CloudKitSharingService.shared.clearApplicationVersion(
                from: share, using: container
            )
        }
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        Logger.cloudkit.info("CloudSharingDelegate: didStopSharing")
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environment(SyncMonitor())
        .environmentObject(PersistenceController.shared)
}
