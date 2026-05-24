// SplashView · launch animation. Black background, the dynamic-island pill
// expands in horizontally, the lens dot scales in, then "islet" types out.
//
// Auto-dismisses via the bound `done` flag after the full sequence (~1.6s).

import SwiftUI

struct SplashView: View {
    @Binding var done: Bool

    @State private var pillProgress: CGFloat = 0   // 0 → 1, drives pill width
    @State private var lensIn: Bool = false        // dot scale-in
    @State private var nameOpacity: Double = 0
    @State private var nameOffset: CGFloat = 6
    @State private var subtitleOpacity: Double = 0
    @State private var fade: Double = 1

    private let pillWidth: CGFloat = 200
    private let pillHeight: CGFloat = 46

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                // Pill + lens dot
                ZStack(alignment: .trailing) {
                    Capsule()
                        .fill(Color.white)
                        .frame(width: pillWidth * pillProgress, height: pillHeight)
                        .animation(.easeOut(duration: 0.55), value: pillProgress)

                    Circle()
                        .fill(Color.black)
                        .frame(width: 14, height: 14)
                        .padding(.trailing, 14)
                        .scaleEffect(lensIn ? 1 : 0)
                        .opacity(lensIn ? 1 : 0)
                        .animation(.spring(response: 0.32, dampingFraction: 0.65), value: lensIn)
                        .opacity(pillProgress >= 1 ? 1 : 0)
                }
                .frame(width: pillWidth, height: pillHeight, alignment: .center)

                VStack(spacing: 4) {
                    Text("islet")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .opacity(nameOpacity)
                        .offset(y: nameOffset)
                    Text("DYNAMIC ISLAND DESIGNER")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .opacity(subtitleOpacity)
                }
            }
        }
        .opacity(fade)
        .onAppear { runSequence() }
    }

    private func runSequence() {
        // 1. Expand the pill
        withAnimation(.easeOut(duration: 0.55)) { pillProgress = 1 }

        // 2. Pop the lens dot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            lensIn = true
        }

        // 3. Reveal name
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 0.35)) {
                nameOpacity = 1
                nameOffset = 0
            }
        }

        // 4. Reveal subtitle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) {
            withAnimation(.easeOut(duration: 0.30)) { subtitleOpacity = 1 }
        }

        // 5. Hold, then fade the whole splash out
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            withAnimation(.easeInOut(duration: 0.32)) { fade = 0 }
        }

        // 6. Mark done so the host can stop rendering it
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            done = true
        }
    }
}
