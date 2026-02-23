//
//  SampleData.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// Seeds the database with sample data on first launch.
/// Checks if any contacts exist first to avoid duplicating data.
struct SampleData {
    static func seedIfNeeded(context: ModelContext) {
        // Only seed if the database is empty
        let descriptor = FetchDescriptor<Contact>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        // MARK: - Contacts

        let alice = Contact(
            firstName: "Alice",
            lastName: "Chen",
            company: "Vertex Labs",
            phone: "555-0101",
            email: "alice@vertexlabs.io",
            birthday: calendar.date(from: DateComponents(year: 1988, month: 3, day: 15)),
            relationshipType: .colleague,
            howWeMet: "Met at WWDC 2024",
            notes: "Great iOS developer, interested in AR/VR"
        )
        alice.tags = ["tech", "iOS", "conference"]
        alice.linkedInURL = "linkedin.com/in/alicechen"
        alice.twitterHandle = "@alicechen"
        alice.lastContactedDate = daysAgo(3)

        let bob = Contact(
            firstName: "Bob",
            lastName: "Martinez",
            company: "Greenfield Capital",
            phone: "555-0102",
            email: "bob@greenfieldcap.com",
            relationshipType: .client,
            howWeMet: "Referral from Sarah",
            notes: "Looking for a portfolio tracking app"
        )
        bob.tags = ["finance", "potential-project"]
        bob.lastContactedDate = daysAgo(10)

        let carol = Contact(
            firstName: "Carol",
            lastName: "Washington",
            company: "",
            phone: "555-0103",
            email: "carol.w@gmail.com",
            birthday: calendar.date(from: DateComponents(year: 1990, month: 7, day: 22)),
            relationshipType: .friend,
            howWeMet: "College roommate's wedding"
        )
        carol.tags = ["golf", "travel"]
        carol.lastContactedDate = daysAgo(30)

        let dave = Contact(
            firstName: "Dave",
            lastName: "Patel",
            company: "Patel & Associates",
            phone: "555-0104",
            email: "dave@patellaw.com",
            relationshipType: .acquaintance,
            howWeMet: "Neighborhood block party"
        )
        dave.tags = ["legal", "neighbor"]

        let emma = Contact(
            firstName: "Emma",
            lastName: "Johansson",
            company: "Nordic Design Co",
            phone: "555-0105",
            email: "emma@nordicdesign.se",
            relationshipType: .colleague,
            howWeMet: "Freelance project collaboration",
            notes: "Amazing UX designer, based in Stockholm"
        )
        emma.tags = ["design", "UX", "remote"]
        emma.instagramHandle = "@emma.designs"
        emma.lastContactedDate = daysAgo(1)

        let frank = Contact(
            firstName: "Frank",
            lastName: "Albert",
            company: "",
            phone: "555-0106",
            email: "frank.a@family.com",
            birthday: calendar.date(from: DateComponents(year: 1955, month: 11, day: 8)),
            relationshipType: .family
        )
        frank.tags = ["family"]
        frank.lastContactedDate = daysAgo(7)

        let contacts = [alice, bob, carol, dave, emma, frank]
        contacts.forEach { context.insert($0) }

        // MARK: - Projects

        let appProject = CRMProject(
            name: "Portfolio Tracker App",
            notes: "Mobile app for Bob's firm to track investment portfolios",
            status: .active
        )
        appProject.contactsList = [bob, emma]

        let redesign = CRMProject(
            name: "Website Redesign",
            notes: "Refresh the marketing site with Nordic Design Co",
            status: .onHold
        )
        redesign.contactsList = [emma]

        let golfEvent = CRMProject(
            name: "Charity Golf Tournament",
            notes: "Annual fundraiser planning",
            status: .active
        )
        golfEvent.contactsList = [carol, dave]

        let projects = [appProject, redesign, golfEvent]
        projects.forEach { context.insert($0) }

        // MARK: - Tasks

        let tasks: [CRMTask] = [
            CRMTask(title: "Send proposal to Bob", notes: "Include timeline and cost estimate", dueDate: daysFromNow(2), priority: .high, contact: bob, project: appProject),
            CRMTask(title: "Review Emma's wireframes", dueDate: daysFromNow(5), priority: .medium, contact: emma, project: appProject),
            CRMTask(title: "Call Carol about golf tournament", dueDate: daysFromNow(1), priority: .medium, contact: carol, project: golfEvent),
            CRMTask(title: "Follow up with Dave on sponsorship", dueDate: daysFromNow(7), priority: .low, contact: dave, project: golfEvent),
            CRMTask(title: "Share WWDC session links with Alice", dueDate: daysAgo(1), priority: .low, contact: alice),
            CRMTask(title: "Birthday gift for Frank", notes: "He mentioned wanting a new fishing rod", dueDate: daysFromNow(14), priority: .medium, contact: frank),
        ]

        // Mark one task as completed
        let completedTask = CRMTask(title: "Send NDA to Dave", priority: .high, contact: dave)
        completedTask.isCompleted = true
        completedTask.completedAt = daysAgo(2)

        (tasks + [completedTask]).forEach { context.insert($0) }

        // MARK: - Appointments

        let appointments: [Appointment] = [
            Appointment(
                title: "Lunch with Alice",
                notes: "Catch up on her new AR project",
                location: "Blue Bottle Coffee",
                date: todayAt(hour: 12, minute: 30),
                endDate: todayAt(hour: 13, minute: 30),
                contacts: [alice]
            ),
            Appointment(
                title: "Portfolio app kickoff",
                notes: "First meeting to discuss requirements",
                location: "Zoom",
                date: daysFromNowAt(days: 1, hour: 10, minute: 0),
                endDate: daysFromNowAt(days: 1, hour: 11, minute: 0),
                contacts: [bob, emma],
                project: appProject
            ),
            Appointment(
                title: "Golf course walkthrough",
                location: "Pebble Creek Golf Club",
                date: daysFromNowAt(days: 3, hour: 9, minute: 0),
                endDate: daysFromNowAt(days: 3, hour: 11, minute: 0),
                contacts: [carol, dave],
                project: golfEvent
            ),
            Appointment(
                title: "Family dinner",
                location: "Frank's house",
                date: daysFromNowAt(days: 5, hour: 18, minute: 0),
                contacts: [frank]
            ),
            Appointment(
                title: "Design review with Emma",
                location: "Google Meet",
                date: daysAgoAt(days: 2, hour: 14, minute: 0),
                endDate: daysAgoAt(days: 2, hour: 15, minute: 0),
                contacts: [emma],
                project: redesign
            ),
        ]

        appointments.forEach { context.insert($0) }
    }

    // MARK: - Date Helpers

    private static let calendar = Calendar.current

    private static func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: Date())!
    }

    private static func daysFromNow(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: Date())!
    }

    private static func todayAt(hour: Int, minute: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private static func daysFromNowAt(days: Int, hour: Int, minute: Int) -> Date {
        let future = daysFromNow(days)
        var components = calendar.dateComponents([.year, .month, .day], from: future)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private static func daysAgoAt(days: Int, hour: Int, minute: Int) -> Date {
        let past = daysAgo(days)
        var components = calendar.dateComponents([.year, .month, .day], from: past)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
