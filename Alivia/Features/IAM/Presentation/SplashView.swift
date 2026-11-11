import SwiftUI

/// Restores the saved session and decides where the app starts.
struct SplashView: View {
    let onResolved: (Session?) -> Void

    var body: some View {
        ZStack {
            AliviaColor.background.ignoresSafeArea()
            AliviaLogo(markSize: 40, textSize: 26)
            VStack(spacing: 12) {
                Spacer()
                ProgressView().tint(AliviaColor.tealDark)
                Text("Iniciando sistema...").font(AliviaFont.bodySmall).foregroundStyle(AliviaColor.inkMuted)
            }
            .padding(.bottom, 48)
        }
        .task {
            let session = await AuthModule.restoreSessionUseCase()()
            try? await Task.sleep(for: .milliseconds(600))
            onResolved(session)
        }
    }
}
