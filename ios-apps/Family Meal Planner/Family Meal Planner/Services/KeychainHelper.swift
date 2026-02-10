//
//  KeychainHelper.swift
//  Family Meal Planner
//

import Foundation
import Security

/// Reads and writes secrets in the iOS Keychain.
/// The Anthropic API key is stored under the service name below.
enum KeychainHelper {

    enum KeychainError: LocalizedError {
        case itemNotFound
        case unexpectedData
        case osError(OSStatus)

        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                "API key not found in Keychain. Please add your Anthropic API key."
            case .unexpectedData:
                "Could not read API key data from Keychain."
            case .osError(let status):
                "Keychain error: \(status)"
            }
        }
    }

    static let anthropicServiceName = "anthropic-api-key"
    static let anthropicAccountName = "highball71"

    /// Retrieve the Anthropic API key from the iOS Keychain.
    static func getAnthropicAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  anthropicServiceName,
            kSecAttrAccount as String:  anthropicAccountName,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }
        guard status == errSecSuccess else {
            throw KeychainError.osError(status)
        }
        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return key
    }

    /// Store the Anthropic API key in the iOS Keychain.
    /// Used during development to set up the key.
    static func setAnthropicAPIKey(_ key: String) throws {
        let data = Data(key.utf8)

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  anthropicServiceName,
            kSecAttrAccount as String:  anthropicAccountName,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:       anthropicServiceName,
            kSecAttrAccount as String:       anthropicAccountName,
            kSecValueData as String:         data,
            kSecAttrAccessible as String:    kSecAttrAccessibleWhenUnlocked,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.osError(status)
        }
    }
}
