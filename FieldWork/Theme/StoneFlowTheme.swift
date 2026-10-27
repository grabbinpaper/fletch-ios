import SwiftUI
import UIKit

// StoneFlow brand tokens for the iOS app.
// Source of truth: the StoneFlow brand book (Design System artifact), tokens.json v2.
// Every colour is a light/dark pair, so views never hard-code a hex value or a system colour.
//
// Use the semantic names:
//   .sfSurface100  page background        .sfInk / .sfInkMuted   text and icons
//   .sfSurface200  cards, inputs          .sfAccentStrong        teal as text, links, tint, active
//   .sfSurface300  wells, tracks          .sfAccent              teal as a small FILL only (never text)
//   .sfSuccess / .sfWarning / .sfDanger / .sfInfo   status, always paired with a word or icon
//   .sfOnFill      label colour on top of any filled control (accentStrong, warning, danger)

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private func sfDynamic(light: UInt32, dark: UInt32) -> Color {
    Color(UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
    })
}

extension ShapeStyle where Self == Color {
    // Surfaces
    static var sfSurface100: Color { sfDynamic(light: 0xF4F2EF, dark: 0x20262D) }
    static var sfSurface200: Color { sfDynamic(light: 0xFFFFFF, dark: 0x2A3139) }
    static var sfSurface300: Color { sfDynamic(light: 0xE9E6E1, dark: 0x343C45) }

    // Text and lines
    static var sfInk: Color { sfDynamic(light: 0x14181D, dark: 0xF2F0EC) }
    static var sfInkMuted: Color { sfDynamic(light: 0x555D63, dark: 0xA3AAAF) }
    static var sfHairline: Color { sfDynamic(light: 0xD8D4CD, dark: 0x3B434C) }
    static var sfBorderStrong: Color { sfDynamic(light: 0x7A8087, dark: 0x7C858B) }
    static var sfStone: Color { sfDynamic(light: 0x7A8087, dark: 0x7C858B) }

    // Brand teal
    static var sfAccent: Color { sfDynamic(light: 0x14A38B, dark: 0x14A38B) }
    static var sfOnAccent: Color { sfDynamic(light: 0x14181D, dark: 0x14181D) }
    static var sfAccentStrong: Color { sfDynamic(light: 0x0B6B5C, dark: 0x3FD0B4) }
    static var sfAccentTint: Color { sfDynamic(light: 0xE2F1EC, dark: 0x12302B) }

    // Status (success is the brand teal: on schedule)
    static var sfSuccess: Color { sfDynamic(light: 0x0B6B5C, dark: 0x3FD0B4) }
    static var sfWarning: Color { sfDynamic(light: 0x8A5A00, dark: 0xF2B84B) }
    static var sfDanger: Color { sfDynamic(light: 0xB3261E, dark: 0xF2766E) }
    static var sfInfo: Color { sfDynamic(light: 0x2F5E8E, dark: 0x7FA8D6) }

    // Label on a filled status/accent control: white on the dark light-mode fills,
    // charcoal on the lighter dark-mode fills (keeps 4.5:1 in both themes).
    static var sfOnFill: Color { sfDynamic(light: 0xFFFFFF, dark: 0x14181D) }
}

// MARK: - Slice mark

/// The StoneFlow "Slice" mark: a square slab cut on the diagonal, one half slid out.
/// Defaults are the light-ground colours. On a dark ground pass `half: .sfInk` (it flips to
/// the light stone colour in dark mode automatically); for one-colour use pass the same colour for both.
/// `cut` runs from 0 (the slab closed into one square) to 1 (the logo); animate it for the launch slide.
struct SliceMark: View, Animatable {
    var half: Color = .sfInk
    var slide: Color = .sfAccent
    var cut: CGFloat = 1

    var animatableData: CGFloat {
        get { cut }
        set { cut = newValue }
    }

    var body: some View {
        Canvas { [cut] context, size in
            let s = min(size.width, size.height) / 64
            let ox = (size.width - 64 * s) / 2
            let oy = (size.height - 64 * s) / 2
            // The halves span 4...55 and 9...50 of the 64 box; nudge so their centre sits on the box centre.
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + (x + 2.5) * s, y: oy + (y + 2.5) * s) }
            // Closed, the slid half sits 11 left and 1 down of where the logo has it.
            // Each half covers half that distance, so the slab stays centred while it opens.
            let dx = (1 - cut) * 5.5
            let dy = (1 - cut) * 0.5

            var a = Path()
            a.move(to: pt(4 + dx, 10 - dy)); a.addLine(to: pt(44 + dx, 10 - dy)); a.addLine(to: pt(4 + dx, 50 - dy)); a.closeSubpath()
            var b = Path()
            b.move(to: pt(55 - dx, 9 + dy)); b.addLine(to: pt(55 - dx, 49 + dy)); b.addLine(to: pt(15 - dx, 49 + dy)); b.closeSubpath()

            context.fill(a, with: .color(half))
            context.fill(b, with: .color(slide))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("StoneFlow")
    }
}

// MARK: - Launch

private struct SFBrandNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Shared between the launch screen and login so the big Slice mark glides from one to the other.
    var sfBrandNamespace: Namespace.ID? {
        get { self[SFBrandNamespaceKey.self] }
        set { self[SFBrandNamespaceKey.self] = newValue }
    }
}

extension View {
    /// Soft lift under the big launch/login mark only; everywhere else surfaces use hairlines, not shadows.
    func sfHeroMarkShadow() -> some View {
        modifier(SFHeroMarkShadow())
    }

    /// Tags the big Slice mark so it moves, rather than cuts, between launch and login.
    @ViewBuilder
    func sfBrandMark(_ namespace: Namespace.ID?) -> some View {
        if let namespace {
            matchedGeometryEffect(id: "sliceMark", in: namespace)
        } else {
            self
        }
    }
}

/// Dark mode needs a denser shadow than light mode to read as the same lift on the charcoal page.
private struct SFHeroMarkShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content.shadow(color: .black.opacity(0.6), radius: 18, x: 0, y: 10)
        } else {
            content.shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        }
    }
}

/// Launch screen: the slab appears closed, then slides open along its cut into the logo.
struct SFLaunchView: View {
    @Environment(\.sfBrandNamespace) private var brandNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cut: CGFloat = 0
    @State private var shown = false

    /// How long the whole sequence takes; RootView holds the launch screen at least this long.
    static let duration: Duration = .milliseconds(900)
    /// Shared with the login mark so the glide between them keeps one size.
    static let markSize: CGFloat = 104

    var body: some View {
        SliceMark(cut: reduceMotion ? 1 : cut)
            .frame(width: Self.markSize, height: Self.markSize)
            .sfHeroMarkShadow()
            .sfBrandMark(brandNamespace)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.sfSurface100.ignoresSafeArea())
            .onAppear {
                withAnimation(.easeOut(duration: 0.18)) { shown = true }
                guard !reduceMotion else { return }
                withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.6).delay(0.2)) { cut = 1 }
            }
    }
}

// MARK: - Logo lockup

/// Slice mark plus the uppercase STONEFLOW wordmark. Sits in the navigation bar of every main tab.
/// Clear space around the mark is half its width, per the brand book.
struct SFLogoLockup: View {
    var markSize: CGFloat = 22

    var body: some View {
        HStack(spacing: markSize * 0.4) {
            SliceMark()
                .frame(width: markSize, height: markSize)
            Text("STONEFLOW")
                .font(.system(size: markSize * 0.68, weight: .heavy))
                .tracking(markSize * 0.06)
                // Tracking adds space after the last letter too; take it back so the lockup centres.
                .padding(.trailing, -markSize * 0.06)
                .foregroundStyle(Color.sfInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("StoneFlow")
    }
}

extension View {
    /// Puts the logo lockup centred in the navigation bar.
    func sfBrandBar() -> some View {
        toolbar {
            ToolbarItem(placement: .principal) {
                SFLogoLockup()
            }
        }
    }

    /// Stone page background behind a ScrollView or List.
    func sfScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.sfSurface100.ignoresSafeArea())
    }

    /// Card: surface-200 on the page, radius-md, 1px hairline instead of a shadow.
    func sfCard() -> some View {
        background(Color.sfSurface200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.sfHairline, lineWidth: 1)
            )
    }
}

// MARK: - Section label

/// Sentence-case label above a group of content, in ink-muted.
struct SFSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.sfInkMuted)
    }
}

// MARK: - Empty state

/// Empty state with the one-colour Slice mark in stone.
struct SFEmptyState: View {
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            SliceMark(half: .sfStone, slide: .sfStone)
                .frame(width: 44, height: 44)
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.sfInk)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Color.sfInkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Secondary button

/// Outlined button for the second action on a screen (take a photo, pick from library), so the
/// one solid ink button stays the obvious next step. surface-200 fill, border-strong outline.
struct SFSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.sfInk.opacity(isEnabled ? 1 : 0.4))
            .background(configuration.isPressed ? Color.sfSurface300 : Color.sfSurface200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.sfBorderStrong, lineWidth: 1))
    }
}

// MARK: - Primary button

/// Brand primary button: ink fill, surface text, 6pt radius. Teal stays out of big fills.
struct SFPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.sfSurface200)
            .background(Color.sfInk.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.35))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
