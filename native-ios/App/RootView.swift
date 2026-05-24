// RootView · 5-tab bottom bar matching the HTML prototype exactly.
//
// Tab bar uses safeAreaInset so it sits flush against the home indicator
// edge with no dead space below. Background is solid dark like the HTML
// (rgba(10,10,10,0.92) — not ultraThinMaterial which washes things out).

import SwiftUI

struct RootView: View {
    @Environment(\.palette) var p
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content (full screen, with reserved bottom space for the bar)
            ZStack {
                Group {
                    switch state.tab {
                    case .dashboard:   DashboardTab().id("t-dashboard")
                    case .skills:      SkillsTab().id("t-skills")
                    case .island:      IslandTab().id("t-island")
                    case .performance: PerformanceTab().id("t-performance")
                    case .settings:    SettingsTab().id("t-settings")
                    }
                }
                .transition(.opacity)
            }
            .animation(.easeOut(duration: 0.12), value: state.tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 56)
            }

            // Tab bar overlays at the bottom · its background extends beneath the home indicator
            tabBar
        }
        .background(p.bg.ignoresSafeArea())
        .foregroundStyle(p.text)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(.dashboard)   { TabIcons.Dashboard()   }
            tabItem(.skills)      { TabIcons.Skills()      }
            tabItem(.island)      { TabIcons.Island()      }
            tabItem(.performance) { TabIcons.Performance() }
            tabItem(.settings)    { TabIcons.Settings()    }
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(p.bg)
        .overlay(alignment: .top) {
            Rectangle().frame(height: 1).foregroundStyle(p.line2)
        }
        .background(p.bg.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func tabItem<Icon: View>(_ t: Tab, @ViewBuilder icon: () -> Icon) -> some View {
        let on = state.tab == t
        Button { state.tab = t } label: {
            VStack(spacing: 4) {
                icon()
                    .frame(width: 24, height: 24)
                Text(t.label.uppercased())
                    .font(.system(size: 9, weight: on ? .bold : .semibold, design: .monospaced))
                    .tracking(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(on ? p.hi : p.text3)
            .overlay(alignment: .top) {
                if on {
                    Rectangle()
                        .frame(width: 24, height: 2)
                        .foregroundStyle(p.hi)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab icons (faithful ports of the HTML inline SVGs)

enum TabIcons {

    /// Dashboard icon · gauge with a needle (matches "device dashboard" framing).
    struct Dashboard: View {
        var body: some View {
            GeometryReader { geo in
                let s = geo.size.width / 24
                ZStack {
                    // Outer half-circle dial (180° arc, opens upward)
                    Path { p in
                        p.addArc(
                            center: CGPoint(x: 12 * s, y: 15 * s),
                            radius: 9 * s,
                            startAngle: .degrees(180),
                            endAngle: .degrees(360),
                            clockwise: false
                        )
                    }
                    .stroke(.foreground, style: .init(lineWidth: 1.8, lineCap: .round))

                    // Needle (pointing ~upper-right, like a 70% reading)
                    Path { p in
                        p.move(to: CGPoint(x: 12 * s, y: 15 * s))
                        p.addLine(to: CGPoint(x: 17.5 * s, y: 9 * s))
                    }
                    .stroke(.foreground, style: .init(lineWidth: 1.8, lineCap: .round))

                    // Pivot dot at the needle base
                    Circle()
                        .fill(.foreground)
                        .frame(width: 2.4 * s, height: 2.4 * s)
                        .position(x: 12 * s, y: 15 * s)
                }
            }
        }
    }

    /// Skills icon · lightning bolt (M13 2L3 14h7l-1 8 10-12h-7l1-8z)
    struct Skills: View {
        var body: some View {
            GeometryReader { geo in
                let s = geo.size.width / 24
                Path { path in
                    path.move(to: .init(x: 13*s, y: 2*s))
                    path.addLine(to: .init(x: 3*s,  y: 14*s))
                    path.addLine(to: .init(x: 10*s, y: 14*s))
                    path.addLine(to: .init(x: 9*s,  y: 22*s))
                    path.addLine(to: .init(x: 19*s, y: 10*s))
                    path.addLine(to: .init(x: 12*s, y: 10*s))
                    path.addLine(to: .init(x: 13*s, y: 2*s))
                    path.closeSubpath()
                }
                .stroke(.foreground, style: .init(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
    }

    /// Island icon · capsule (rect rx 4) with a small filled lens dot inside.
    struct Island: View {
        var body: some View {
            GeometryReader { geo in
                let s = geo.size.width / 24
                ZStack {
                    Path { path in
                        path.addRoundedRect(
                            in: CGRect(x: 3*s, y: 8*s, width: 18*s, height: 8*s),
                            cornerSize: .init(width: 4*s, height: 4*s)
                        )
                    }
                    .stroke(.foreground, lineWidth: 1.8)
                    Circle()
                        .frame(width: 2.4*s, height: 2.4*s)
                        .foregroundStyle(.foreground)
                        .offset(x: 5*s, y: 0)
                }
            }
        }
    }

    /// Performance icon · zig-zag chart line + base axis.
    struct Performance: View {
        var body: some View {
            GeometryReader { geo in
                let s = geo.size.width / 24
                Path { path in
                    path.move(to: .init(x: 3*s,  y: 16*s))
                    path.addLine(to: .init(x: 8*s,  y: 11*s))
                    path.addLine(to: .init(x: 12*s, y: 14*s))
                    path.addLine(to: .init(x: 17*s, y: 7*s))
                    path.addLine(to: .init(x: 21*s, y: 11*s))
                }
                .stroke(.foreground, style: .init(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                Path { path in
                    path.move(to: .init(x: 3*s, y: 20*s))
                    path.addLine(to: .init(x: 21*s, y: 20*s))
                }
                .stroke(.foreground, lineWidth: 1.8)
            }
        }
    }

    /// Shortcuts icon · play triangle inside rounded square (matches Apple's Shortcuts hint).
    struct Shortcuts: View {
        var body: some View {
            GeometryReader { geo in
                let s = geo.size.width / 24
                ZStack {
                    Path { path in
                        path.addRoundedRect(
                            in: CGRect(x: 4*s, y: 4*s, width: 16*s, height: 16*s),
                            cornerSize: .init(width: 4*s, height: 4*s)
                        )
                    }
                    .stroke(.foreground, lineWidth: 1.8)
                    Path { p in
                        p.move(to: .init(x: 10*s, y: 9*s))
                        p.addLine(to: .init(x: 16*s, y: 12*s))
                        p.addLine(to: .init(x: 10*s, y: 15*s))
                        p.closeSubpath()
                    }
                    .fill(.foreground)
                }
            }
        }
    }

    /// Settings icon · gear traced from the HTML SVG path data.
    /// Faithful port of the original M19.4 15... arc-and-curve geometry.
    struct Settings: View {
        var body: some View {
            GeometryReader { geo in
                let s = geo.size.width / 24
                ZStack {
                    GearPath()
                        .stroke(.foreground, style: .init(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                        .frame(width: 24*s, height: 24*s)
                    Circle()
                        .stroke(.foreground, lineWidth: 1.6)
                        .frame(width: 6*s, height: 6*s) // r=3 in 24-unit space
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

/// Gear outline shape (the outer cog teeth + ring) from the HTML inline SVG.
/// The SVG path uses many `a1.7 1.7 0 0 0` arcs that round each tooth corner.
/// We approximate by tracing the polygon with rounded corners (lineJoin: .round)
/// which gets us the same silhouette the SVG produces visually.
struct GearPath: Shape {
    func path(in rect: CGRect) -> Path {
        // The SVG is in a 24×24 viewbox. Map to our rect.
        let s = min(rect.width, rect.height) / 24
        let cx = rect.midX
        let cy = rect.midY
        // Translate from SVG (top-left origin, y-down) to our coordinate space.
        // We trace an 8-tooth gear using two radii: outer (toothTip) and inner (toothBase).
        let toothTipR = 9.5 * s
        let toothBaseR = 7.6 * s
        let teeth = 8
        // Each tooth occupies (2π / teeth) radians; half is the tip, half the base.
        var p = Path()
        for i in 0..<teeth {
            let baseAngle = -.pi / 2 + Double(i) * (2 * .pi / Double(teeth))
            let halfTooth = (2 * .pi / Double(teeth)) / 2
            // 4 corners per tooth: rise, tip, fall, base
            let a1 = baseAngle - halfTooth * 0.55  // outer left
            let a2 = baseAngle - halfTooth * 0.20  // outer left edge of tip
            let a3 = baseAngle + halfTooth * 0.20  // outer right edge of tip
            let a4 = baseAngle + halfTooth * 0.55  // outer right
            let pts: [CGPoint] = [
                CGPoint(x: cx + cos(a1) * toothBaseR, y: cy + sin(a1) * toothBaseR),
                CGPoint(x: cx + cos(a2) * toothTipR,  y: cy + sin(a2) * toothTipR),
                CGPoint(x: cx + cos(a3) * toothTipR,  y: cy + sin(a3) * toothTipR),
                CGPoint(x: cx + cos(a4) * toothBaseR, y: cy + sin(a4) * toothBaseR)
            ]
            if i == 0 { p.move(to: pts[0]) }
            for pt in pts { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
