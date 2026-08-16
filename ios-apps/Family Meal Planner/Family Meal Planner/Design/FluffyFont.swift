//
//  FluffyFont.swift
//  FluffyList
//
//  "The Press" shared components — the broadsheet furniture every
//  screen is built from: the masthead, hairline rules, section heads,
//  uppercase metadata, underlined text links, and the one filled
//  button style. Replaces the old FluffySectionHeader /
//  FluffyPrimaryButton / FluffyMetadataChip card-era components.
//

import SwiftUI

// MARK: - Rules (hairlines)

/// A horizontal rule. 1pt hairline by default; pass 4 for the
/// masthead's heavy top rule, 2 for field underlines.
struct FluffyRule: View {
    var weight: CGFloat = 1
    var color: Color = .fluffyDivider

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: weight)
    }
}

// MARK: - Masthead

/// The furniture every top-level screen opens with:
/// 4px ink rule → "FLUFFYLIST" + contextual dateline → 1px ink rule
/// → screen title 20pt below.
/// Drawn in scroll content; the system nav bar should be hidden.
struct FluffyMasthead: View {
    let title: String
    let dateline: String
    /// Paper (default) or inverted for Store Mode's ink ground.
    var onInk: Bool = false
    /// Brand text; Store Mode swaps it for "STORE MODE".
    var brand: String = "FLUFFYLIST"

    private var ruleColor: Color { onInk ? .fluffyPaperOnInk : .fluffyPrimary }
    private var brandColor: Color { onInk ? .fluffyPaperOnInk : .fluffyPrimary }
    private var datelineColor: Color { onInk ? .fluffyPaperDimOnInk : .fluffySecondary }
    private var titleColor: Color { onInk ? .fluffyPaperOnInk : .fluffyPrimary }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffyRule(weight: 4, color: ruleColor)

            HStack {
                Text(brand)
                    .font(.fluffyMastheadLabel)
                    .fluffyTracking(0.16, at: 10)
                    .foregroundStyle(brandColor)
                Spacer()
                Text(dateline.uppercased())
                    .font(.fluffyMastheadLabel)
                    .fluffyTracking(0.16, at: 10)
                    .foregroundStyle(datelineColor)
            }
            .padding(.vertical, 8)

            FluffyRule(weight: 1, color: ruleColor)

            Text(title)
                .font(onInk ? .custom(FluffyFace.bold, size: 40) : .fluffyDisplay)
                .fluffyTracking(-0.025, at: onInk ? 40 : 38)
                .foregroundStyle(titleColor)
                .padding(.top, 20)
        }
    }
}

// MARK: - Section Head

/// Uppercase tracked section label — "INGREDIENTS", "PRODUCE".
/// 11pt / 0.16em in fluffySecondary; Store Mode passes ink-1 pale.
struct FluffySectionHead: View {
    let title: String
    var color: Color = .fluffySecondary

    var body: some View {
        Text(title.uppercased())
            .font(.fluffySectionHead)
            .fluffyTracking(0.16, at: 11)
            .foregroundStyle(color)
    }
}

// MARK: - Uppercase Metadata Line

/// Row metadata like "PASTA · 20 MIN" — 12pt / 0.10em uppercase.
struct FluffyMetadataLine: View {
    let text: String
    var color: Color = .fluffySecondary

    var body: some View {
        Text(text.uppercased())
            .font(.fluffyCaption)
            .fluffyTracking(0.10, at: 12)
            .foregroundStyle(color)
    }
}

// MARK: - Text Link ("Build the grocery list →")

/// The Press's primary CTA: an underlined ink-1 text link with a
/// trailing arrow that never wraps onto its own line.
struct FluffyTextLink: View {
    let title: String
    var showArrow: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(showArrow ? "\(title) \u{2192}" : title)
                    .font(.fluffyButton)
                    .foregroundStyle(Color.fluffyAccent)
                    .fixedSize(horizontal: false, vertical: true)
                FluffyRule(weight: 2, color: .fluffyAccent)
            }
            .fixedSize()
        }
        .buttonStyle(FluffyPressDarkenStyle())
    }
}

// MARK: - Filled Ink Button

/// Full-width filled button, square corners. Persimmon by default
/// ("Add to the week", "Create household"); pass .fluffyPrimary for
/// the solid-ink Sign in with Apple block.
struct FluffyFilledButton: View {
    let title: String
    var icon: String? = nil
    var fill: Color = .fluffyAccent
    var textColor: Color = .fluffyBackground
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.custom(FluffyFace.semibold, size: 17))
            }
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill)   // square corners — no shape
        }
        .buttonStyle(FluffyFilledDarkenStyle())
    }
}

// MARK: - Pressed States

/// Pressed state for ink-1 text links: darken to ink 1 deep.
struct FluffyPressDarkenStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(1)
            .colorMultiply(configuration.isPressed ? Color(hex: "BFB9B7") : .white)
    }
}

/// Pressed state for filled buttons: darken the fill.
struct FluffyFilledDarkenStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .colorMultiply(configuration.isPressed ? Color(hex: "D0CCCB") : .white)
    }
}

// MARK: - Square Checkbox

/// The Press checkbox: a square with a 2px border.
/// Paper mode — unchecked: fluffyBorder stroke; checked: ink-1 fill
/// with a paper ✓. Store Mode — checked fills ink-1 pale with an ink ✓.
struct FluffyCheckbox: View {
    let isChecked: Bool
    var size: CGFloat = 20
    var onInk: Bool = false

    private var strokeColor: Color {
        if isChecked { return onInk ? .fluffyAccentPale : .fluffyAccent }
        return onInk ? .fluffyRuleOnInk : .fluffyBorder
    }
    private var fillColor: Color {
        guard isChecked else { return .clear }
        return onInk ? .fluffyAccentPale : .fluffyAccent
    }
    private var checkColor: Color {
        onInk ? .fluffyInkGround : .fluffyBackground
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(fillColor)
            Rectangle()
                .strokeBorder(strokeColor, lineWidth: 2)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.55, weight: .bold))
                    .foregroundStyle(checkColor)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.18), value: isChecked)
    }
}

// MARK: - Halftone Image Treatment

extension View {
    /// The Press photo treatment: desaturate ~35%, contrast ~1.15.
    /// Square corners, no scrim.
    func fluffyHalftone() -> some View {
        self
            .saturation(0.65)
            .contrast(1.15)
    }
}

// MARK: - Legacy shims (card era — retired)

/// Old card-era section header. Kept as a shim over FluffySectionHead
/// so any straggling call site still compiles; new code should use
/// FluffySectionHead directly.
struct FluffySectionHeader: View {
    let title: String
    var section: FluffySection = .recipes

    var body: some View {
        FluffySectionHead(title: title)
    }
}

/// Old bullet row — bullets are retired; rows are ruled now.
struct FluffyBulletRow: View {
    let text: String
    var dotColor: Color = .fluffyAccent

    var body: some View {
        Text(text)
            .font(.fluffyBody)
            .foregroundStyle(Color.fluffyPrimary)
    }
}

/// Old filled rounded button — now square and persimmon.
struct FluffyPrimaryButton: View {
    let title: String
    let icon: String?
    var section: FluffySection = .recipes
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        section: FluffySection = .recipes,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.section = section
        self.action = action
    }

    var body: some View {
        FluffyFilledButton(title: title, icon: icon, action: action)
    }
}

/// Old metadata pill — now a plain uppercase metadata line.
struct FluffyMetadataChip: View {
    let icon: String
    let value: String

    var body: some View {
        FluffyMetadataLine(text: value)
    }
}
