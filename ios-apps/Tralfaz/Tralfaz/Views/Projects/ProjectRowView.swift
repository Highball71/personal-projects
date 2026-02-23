//
//  ProjectRowView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI

/// A single row in the projects list showing name, status badge,
/// and counts of linked items.
struct ProjectRowView: View {
    let project: CRMProject

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)

                if !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(project.status.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .foregroundStyle(statusColor)
                .clipShape(Capsule())
        }
    }

    /// Builds a summary like "3 contacts · 5 tasks" showing only non-zero counts.
    private var summaryText: String {
        var parts: [String] = []
        let contacts = project.contactsList.count
        let tasks = project.tasksList.count
        let appointments = project.appointmentsList.count

        if contacts > 0 { parts.append("\(contacts) contact\(contacts == 1 ? "" : "s")") }
        if tasks > 0 { parts.append("\(tasks) task\(tasks == 1 ? "" : "s")") }
        if appointments > 0 { parts.append("\(appointments) appt\(appointments == 1 ? "" : "s")") }

        return parts.joined(separator: " · ")
    }

    private var statusColor: Color {
        switch project.status {
        case .active: return .green
        case .onHold: return .orange
        case .completed: return .blue
        case .archived: return .gray
        }
    }
}
