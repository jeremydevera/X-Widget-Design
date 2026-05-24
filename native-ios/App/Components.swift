// Components · reusable UI building blocks
//
// TabHeader, PreviewPill, RingChart, SectionTitle. Used across every tab.

import SwiftUI

/// Top header used by every tab — title left, optional trailing accessory.
struct TabHeader<Trailing: View>: View {
    @Environment(\.palette) var p
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundStyle(p.text)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(p.text3)
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(p.bg)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 1).foregroundStyle(p.line)
        }
    }
}

/// The black pill that the dynamic island design renders inside.
struct PreviewPill<Content: View>: View {
    let isLong: Bool
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: isLong ? 18 : 10) {
            content()
        }
        .frame(height: 44)
        .padding(.horizontal, isLong ? 32 : 18)
        .frame(minWidth: isLong ? 280 : 160)
        .background(Color.black, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 2))
    }
}

/// Slim ring chart (matches "chart 1" style from the web app).
struct RingChart: View {
    @Environment(\.palette) var p
    let value: Double
    let max: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(p.surface3, lineWidth: 4)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(p.hi, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(p.text)
        }
        .frame(width: 64, height: 64)
        .animation(.easeInOut(duration: 0.45), value: clamped)
    }
    private var clamped: CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(min(1, Swift.max(0, value / max)))
    }
}

/// Section title used in scrollable tab bodies.
struct SectionTitle: View {
    @Environment(\.palette) var p
    let text: String
    var trailing: AnyView? = nil
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(p.text2)
            Spacer()
            trailing
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 1).foregroundStyle(p.line)
        }
        .padding(.top, 22)
        .padding(.bottom, 10)
    }
}

/// Mono key-value row used by Device Info, Network etc.
struct InfoRow: View {
    @Environment(\.palette) var p
    let key: String
    let value: String
    var body: some View {
        HStack {
            Text(key).font(.system(size: 11, design: .monospaced)).foregroundStyle(p.text2)
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(p.text)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 1).foregroundStyle(p.line)
        }
    }
}

/// The right-arrow chevron used on tappable rows.
struct RowChevron: View {
    @Environment(\.palette) var p
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(p.text3)
    }
}

/// Apply / Reset / generic ghost button.
struct GhostButton: View {
    @Environment(\.palette) var p
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .padding(.vertical, 7)
                .padding(.horizontal, 14)
                .overlay(Rectangle().stroke(p.line3, lineWidth: 1))
                .foregroundStyle(p.text2)
        }
        .buttonStyle(.plain)
    }
}

/// Mono toggle that mirrors the web app's CSS `.toggle` switch:
/// 38×22 rounded pill, knob slides left ↔ right, tracks white-on / dark-off.
struct MonoToggle: View {
    @Environment(\.palette) var p
    @Binding var isOn: Bool
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? p.hi : p.surface3)
                    .overlay(Capsule().stroke(isOn ? p.hi : p.line2, lineWidth: 1))
                Circle()
                    .fill(isOn ? p.bg : p.text2)
                    .frame(width: 16, height: 16)
                    .padding(2)
            }
            .frame(width: 38, height: 22)
            .animation(.easeInOut(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
    }
}

/// White-fill primary action button.
struct PrimaryButton: View {
    @Environment(\.palette) var p
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(p.hi)
                .foregroundStyle(p.bg)
        }
        .buttonStyle(.plain)
    }
}


/// Reusable toast overlay. Use `.toast(message: $toastBinding)` on any view.
struct ToastModifier: ViewModifier {
    @Environment(\.palette) var p
    @Binding var message: String?
    var alignment: Alignment = .bottom
    var accent: ToastAccent = .neutral

    enum ToastAccent { case neutral, green }

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            if let m = message {
                Text(m)
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(background)
                    .foregroundStyle(textColor)
                    .padding(insetEdges)
                    .transition(transition)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { self.message = nil }
                        }
                    }
            }
        }
        .animation(.easeOut(duration: 0.18), value: message)
    }

    private var background: Color {
        switch accent {
        case .green:   return Color(hex: 0x10b981)
        case .neutral: return p.hi
        }
    }
    private var textColor: Color {
        switch accent {
        case .green:   return .white
        case .neutral: return p.bg
        }
    }
    private var insetEdges: EdgeInsets {
        switch alignment {
        case .topTrailing: return EdgeInsets(top: 14, leading: 0, bottom: 0, trailing: 14)
        case .topLeading:  return EdgeInsets(top: 14, leading: 14, bottom: 0, trailing: 0)
        case .top:         return EdgeInsets(top: 14, leading: 0, bottom: 0, trailing: 0)
        default:           return EdgeInsets(top: 0, leading: 0, bottom: 80, trailing: 0)
        }
    }
    private var transition: AnyTransition {
        switch alignment {
        case .topTrailing, .topLeading, .top:
            return .move(edge: .top).combined(with: .opacity)
        default:
            return .move(edge: .bottom).combined(with: .opacity)
        }
    }
}

extension View {
    func toast(message: Binding<String?>,
               alignment: Alignment = .bottom,
               accent: ToastModifier.ToastAccent = .neutral) -> some View {
        modifier(ToastModifier(message: message, alignment: alignment, accent: accent))
    }
}
