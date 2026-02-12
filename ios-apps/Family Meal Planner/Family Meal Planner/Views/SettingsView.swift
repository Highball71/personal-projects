//
//  SettingsView.swift
//  Family Meal Planner
//

import SwiftUI

/// Settings screen for entering the Anthropic API key.
/// The key is stored in the device Keychain so photo scanning
/// and URL import work on real devices (not just the Simulator).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var apiKeyText = ""
    @State private var existingKeyHint = ""
    @State private var showingSavedConfirmation = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
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
        }
    }

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

#Preview {
    SettingsView()
}
