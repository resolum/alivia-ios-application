import SwiftUI

/// Screens pushed over the main tabs.
enum Route: Hashable {
    case order(Int64)
    case evaluation(Int64)
    case installation(Int64)
    case completed(Int64)
}

enum AppStage: Equatable {
    case splash
    case login
    case main(Session)
}

/// Root of the app: splash, sign-in and the main tabs with the order screens on top.
struct AppNavigation: View {
    @State private var stage: AppStage = .splash
    @State private var path: [Route] = []

    var body: some View {
        Group {
            switch stage {
            case .splash:
                SplashView { restored in stage = restored.map(AppStage.main) ?? .login }
            case .login:
                LoginView { signedIn in
                    path = []
                    stage = .main(signedIn)
                }
            case .main(let session):
                NavigationStack(path: $path) {
                    MainView(session: session, onOpenOrder: { path.append(.order($0)) }, onSignOut: signOut)
                        .hidesNavigationBar()
                        .navigationDestination(for: Route.self, destination: destination)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            // The refresh token expired: back to the sign-in screen.
            SharedModule.apiClient.onSessionExpired = { goToLogin() }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .order(let id):
            OrderDetailView(orderId: id, onBack: back,
                            onOpenEvaluation: { path.append(.evaluation($0)) },
                            onOpenInstallation: { path.append(.installation($0)) },
                            onOpenCompleted: { path.append(.completed($0)) })
        case .evaluation(let id):
            EvaluationView(orderId: id, onBack: back) { next in
                switch next {
                case .completed(let orderId): path = [.completed(orderId)]
                }
            }
        case .installation(let id):
            InstallationView(orderId: id, onExit: back, onCompleted: { path = [.completed($0)] })
        case .completed(let id):
            OrderCompletedView(orderId: id, onBackToOrders: { path = [] },
                               onOpenSummary: { path = [.order($0)] },
                               onOpenInstallation: { path = [.order($0)] })
        }
    }

    private func back() {
        if !path.isEmpty { path.removeLast() }
    }

    private func goToLogin() {
        path = []
        stage = .login
    }

    private func signOut() {
        Task {
            await AuthModule.signOutUseCase()()
            goToLogin()
        }
    }
}
