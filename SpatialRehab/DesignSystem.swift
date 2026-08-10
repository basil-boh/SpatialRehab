import SwiftUI

/// The shared visual language for the flat-window layer — the main window's home /
/// in-activity / finished screens, the Daily Practice hub, and the persistent ornament.
///
/// Added 2026-08-10 with the window UI pass. Before it, every screen invented its own
/// sizes (`.system(size: 80)`, `44`, `40`, `34`, `30`), which meant nothing responded to
/// Dynamic Type and no two screens agreed on a heading size. Everything here is a
/// *relative* text style, so the whole app scales with the person's accessibility settings
/// — which matters more here than in most apps, since the audience is elderly.
///
/// Deliberately not applied to `CaregiverDashboardView` or `BaselineResultsDebugView`:
/// those read to a caregiver, not the patient, and keep the default (non-rounded) system
/// face with tabular numerals. See `RehabTint` for the tint discipline.

// MARK: - Type

extension Font {
    /// Screen-owning statement: the greeting, the current instruction, "That's your kopi".
    static let rehabDisplay = Font.system(.largeTitle, design: .rounded, weight: .semibold)
    /// Section-owning: the greeting line, screen titles.
    static let rehabTitle = Font.system(.title, design: .rounded, weight: .semibold)
    /// Card and row headings.
    static let rehabHeadline = Font.system(.title2, design: .rounded, weight: .semibold)
    /// Button titles and row labels.
    static let rehabBody = Font.system(.title3, design: .rounded)
    /// Supporting sentences under a heading.
    static let rehabCaption = Font.system(.body, design: .rounded)
    /// The 中文 line under an English one. One step down, never smaller than `.callout`
    /// — it is a real reading line for someone whose first language it is, not a caption.
    static let rehabChinese = Font.system(.callout, design: .rounded)
    /// Eyebrow labels: "Today", "Or something else", the date strip.
    static let rehabLabel = Font.system(.subheadline, design: .rounded, weight: .semibold)
}

// MARK: - Color

/// One accent, one lifeline. Anything else competing for attention is a bug.
enum RehabTint {
    /// "Do this now" — the single prominent action on any patient-facing screen. Jade
    /// rather than the system blue so it never collides with a system control.
    static let action = Color(red: 0.13, green: 0.66, blue: 0.53)

    /// Reserved for `WhoAmIButton` and nothing else. It is the reorientation lifeline —
    /// the one control that must be findable in a panic — so it gets sole ownership of
    /// the warmest, highest-salience colour in the app. The music toggle gave up its teal
    /// for this (2026-08-10): a mute switch should not read as urgently as "who am I?".
    static let lifeline = Color.orange
}

// MARK: - Metrics

enum RehabMetrics {
    /// Patient-facing cards. Softer than the 20pt the data cards use.
    static let cardRadius: CGFloat = 28
    /// Secondary rows in the "or something else" stack.
    static let rowRadius: CGFloat = 22
    static let cardPadding: CGFloat = 22
    /// visionOS minimum comfortable target. Rows and icon buttons are pinned to it so
    /// nothing here is a gaze-and-pinch near-miss.
    static let minTarget: CGFloat = 60
}

// MARK: - Motion

/// Shared timings, so the whole window layer moves at one pace.
///
/// Every animated surface routes through `RehabMotion.honouring(reduceMotion:)` rather
/// than calling `withAnimation` directly — passing a `nil` animation is how SwiftUI
/// disables a transition, so honouring Reduce Motion is a single `nil` at the call site.
enum RehabMotion {
    /// Screen-to-screen and phase-to-phase changes.
    static let screen = Animation.smooth(duration: 0.42)
    /// A value landing in place: step dots advancing, progress bars filling.
    static let settle = Animation.spring(response: 0.5, dampingFraction: 0.78)
    /// Content arriving for the first time.
    static let entrance = Animation.smooth(duration: 0.5)
    /// The celebratory pop on the finished screen.
    static let arrive = Animation.spring(response: 0.55, dampingFraction: 0.62)
    /// The slow glow on the "Today" card. Low amplitude on purpose: it should read as
    /// breathing, not blinking — an attentional cue toward the recommended action, which
    /// is the one thing on the home screen we want gaze to land on first.
    static let breath = Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true)
    /// Seconds between staggered siblings.
    static let staggerStep = 0.07

    static func honouring(_ reduceMotion: Bool, _ animation: Animation = screen) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - Bilingual text

/// An English line with its 中文 counterpart underneath.
///
/// The persona layer has been bilingual since it was written — `FamilyMember` carries
/// `chineseName`, `relationChinese`, and bilingual `videoLine`s, and `NameCardView`
/// renders both. Nothing outside the name card did, which left the screens Lim Chio Bu
/// sees every session in English only. In dementia the first language is the one that
/// survives longest, so every patient-facing string now carries both.
///
/// Read as a single accessibility element: VoiceOver should say the line once, in the
/// device language, not stumble through both.
struct BilingualText: View {
    let english: String
    let chinese: String
    var font: Font = .rehabHeadline
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(english)
                .font(font)
            Text(chinese)
                .font(.rehabChinese)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(english)
    }
}

// MARK: - Surfaces

extension View {
    /// The patient-facing card: material, generous radius, optional tint wash for the one
    /// card on screen that is being recommended.
    func rehabCard(radius: CGFloat = RehabMetrics.cardRadius, tint: Color? = nil) -> some View {
        padding(RehabMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
                ZStack {
                    shape.fill(.regularMaterial)
                    if let tint {
                        shape.fill(tint.opacity(0.14))
                    }
                }
            }
    }

    /// Fades and lifts content into place on first appearance, staggered by `index`.
    func rehabEntrance(_ index: Int = 0) -> some View {
        modifier(RehabEntrance(index: index))
    }

    /// The slow breathing outline on the recommended card. No-op under Reduce Motion.
    func rehabAttention(radius: CGFloat = RehabMetrics.cardRadius, tint: Color = RehabTint.action) -> some View {
        modifier(RehabAttention(radius: radius, tint: tint))
    }
}

private struct RehabEntrance: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .onAppear {
                guard !visible else { return }
                guard !reduceMotion else {
                    visible = true
                    return
                }
                withAnimation(RehabMotion.entrance.delay(Double(index) * RehabMotion.staggerStep)) {
                    visible = true
                }
            }
    }
}

private struct RehabAttention: ViewModifier {
    let radius: CGFloat
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(tint.opacity(glowing ? 0.6 : 0.22), lineWidth: glowing ? 2.5 : 1.5)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(RehabMotion.breath) {
                    glowing = true
                }
            }
    }
}
