//
//  TagInputView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI

/// Chip-style tag entry: displays existing tags as removable pills
/// and provides a text field to add new ones.
struct TagInputView: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing tags as removable chips
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(title: tag) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }

            // Input field for adding new tags
            TextField("Add a tag...", text: $newTag)
                .onSubmit {
                    addTag()
                }
                .submitLabel(.done)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Prevent duplicates (case-insensitive)
        let isDuplicate = tags.contains { $0.lowercased() == trimmed.lowercased() }
        if !isDuplicate {
            tags.append(trimmed)
        }
        newTag = ""
    }
}

/// A single tag pill with a remove button.
struct TagChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
}

/// Simple flow layout that wraps children to the next line when they
/// exceed the available width. Uses a GeometryReader + preference key
/// to measure child sizes and calculate positions.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            // Wrap to next line if this item doesn't fit
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + lineHeight
        }

        return (positions, CGSize(width: totalWidth, height: totalHeight))
    }
}

#Preview {
    @Previewable @State var tags = ["Golf", "Mentor", "NYC"]
    Form {
        Section("Tags") {
            TagInputView(tags: $tags)
        }
    }
}
