import SwiftUI

/// A small badge showing the user's current learning streak with a flame icon.
struct StreakBadgeView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .foregroundStyle(streak > 0 ? .orange : .secondary)
                .symbolEffect(.bounce, value: streak)

            Text("\(streak)")
                .font(.title2.bold())
                .foregroundStyle(streak > 0 ? .primary : .secondary)

            Text(streak == 1 ? "day" : "days")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .capsule)
    }
}

#Preview {
    VStack(spacing: 20) {
        StreakBadgeView(streak: 0)
        StreakBadgeView(streak: 1)
        StreakBadgeView(streak: 7)
        StreakBadgeView(streak: 42)
    }
}
