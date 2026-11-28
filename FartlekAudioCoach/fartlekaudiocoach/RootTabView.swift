import SwiftUI

struct RootTabView: View {
    @StateObject private var environment: AppEnvironment
    @State private var isLoaded = false

    init() {
        _environment = StateObject(wrappedValue: AppEnvironment.bootstrap())
    }

    var body: some View {
        if isLoaded {
            RunnerHomeView(environment: environment)
        } else {
            SplashScreenView()
                .onAppear {
                    // Simulate a small delay to ensure everything is loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isLoaded = true
                        }
                    }
                }
        }
    }
}

private struct SplashScreenView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image("SplashCoachIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 144, height: 144)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .accessibilityHidden(true)
                
                Text("Fartlek")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("Audio Coach")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                
                ProgressView()
                    .padding(.top, 24)
            }
        }
    }
}
