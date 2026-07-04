import SwiftUI

struct SetupView: View {

    @StateObject private var viewModel = SetupViewModel()

    var body: some View {
        ZStack {
            DarkGradientBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    AppBrandingView()

                    Spacer(minLength: 48)

                    SetupCardView(
                        displayName: $viewModel.displayName,
                        selectedProvider: $viewModel.selectedProvider,
                        providers: viewModel.availableProviders,
                        providerRequiresKey: viewModel.providerRequiresAPIKey,
                        isLoading: viewModel.isLoading,
                        canContinue: viewModel.canContinue,
                        onContinue: { viewModel.continueToApp() }
                    )
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .alert("Setup Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Dark Gradient Background

private struct DarkGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.05, green: 0.05, blue: 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.blue.opacity(0.1)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        )
        .overlay(.ultraThinMaterial.opacity(0.3))
        .ignoresSafeArea()
    }
}

// MARK: - App Branding

private struct AppBrandingView: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Text("AI")
                    .foregroundStyle(Color(red: 0.58, green: 0.40, blue: 1.0))
                Text("Stream")
                    .foregroundStyle(.white)
            }
            .font(.system(size: 42, weight: .bold, design: .rounded))

            Text("Streaming AI Chat for iOS")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Setup Card

private struct SetupCardView: View {
    @Binding var displayName: String
    @Binding var selectedProvider: AppConfiguration.AIProviderKind
    let providers: [AppConfiguration.AIProviderKind]
    let providerRequiresKey: (AppConfiguration.AIProviderKind) -> Bool
    let isLoading: Bool
    let canContinue: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Get Started")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)

            Text("Choose a display name and AI provider. Demo mode works offline with no API key.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Display Name", text: $displayName)
                .textFieldStyle(.plain)
                .textContentType(.name)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text("AI Provider")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Picker("AI Provider", selection: $selectedProvider) {
                    ForEach(providers, id: \.self) { provider in
                        HStack {
                            Text(provider.displayName)
                            if providerRequiresKey(provider) {
                                Text("(API key required)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onContinue) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.6)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .environment(\.colorScheme, .light)
    }
}

#Preview {
    SetupView()
}
