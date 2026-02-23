//
//  ContactRowView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI

/// A single row in the contacts list showing name, company, and relationship type.
struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)

                if !contact.company.isEmpty {
                    Text(contact.company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(contact.relationshipType.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.secondary.opacity(0.15))
                .clipShape(Capsule())
                .foregroundStyle(.secondary)
        }
    }
}
