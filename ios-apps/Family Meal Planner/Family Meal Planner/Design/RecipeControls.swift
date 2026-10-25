import SwiftUI

/// Explicit styling keeps navigation controls compact across system button styles.
struct RecipeIconButton: View {
    let symbol: String
    let label: String
    var filled = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(filled ? Color.white : Color.fluffyPrimary)
                .frame(width: 38, height: 38)
                .background(filled ? Color.fluffyButtonFill : Color.fluffyBackground, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
