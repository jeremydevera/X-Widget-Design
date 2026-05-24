// IsletApp · @main entry. Builds the shared environment objects.

import SwiftUI

@main
struct IsletApp: App {
    @StateObject private var state = AppState()
    @StateObject private var metrics = DeviceMetrics()
    @State private var runner: SkillsRunner? = nil
    @State private var splashDone: Bool = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(state)
                    .environmentObject(metrics)
                    .environment(\.palette, state.prefs.theme.palette)
                    .fontDesign(state.prefs.font.design)
                    .fontWidth(state.prefs.font.width)
                    .preferredColorScheme(state.prefs.theme == .paper ? .light : .dark)
                    .background(state.prefs.theme.palette.bg.ignoresSafeArea())
                    .tint(state.prefs.theme.palette.hi)
                    .task {
                        if runner == nil {
                            runner = SkillsRunner(state: state, metrics: metrics)
                        }
                    }

                if !splashDone {
                    SplashView(done: $splashDone)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
    }
}
