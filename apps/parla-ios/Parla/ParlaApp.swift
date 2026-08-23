import SwiftUI

@main
@MainActor
struct ParlaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                // L'interface est en français : c'est la langue commune de tous
                // les utilisateurs visés, quelle que soit la langue apprise.
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .tint(Palette.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isOnboarded)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Parler", systemImage: "waveform") }

            NotebookView()
                .tabItem { Label("Carnet", systemImage: "book.closed.fill") }

            ProgressView_Parla()
                .tabItem { Label("Progrès", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}
