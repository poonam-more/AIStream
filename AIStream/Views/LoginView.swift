//
//  LoginView.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import SwiftUI

struct LoginView: View {
    
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        ZStack {
            // Full screen dark blurred gradient background
            DarkGradientBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    // App name with purple "i"
                    AppBrandingView()
                    
                    Spacer(minLength: 48)
                    
                    // Login card
                    LoginCardView(
                        email: $viewModel.email,
                        password: $viewModel.password,
                        isPasswordVisible: $viewModel.isPasswordVisible,
                        isLoading: viewModel.isLoading,
                        canLogin: viewModel.canLogin,
                        onLogin: { viewModel.login() }
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .alert("Login Error", isPresented: $viewModel.showErrorAlert) {
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
            // "NaIDA" with purple "i"
            HStack(spacing: 0) {
                Text("N")
                    .foregroundStyle(.white)
                Text("ai")
                    .foregroundStyle(Color(red: 0.58, green: 0.40, blue: 1.0))
                Text("DA")
                    .foregroundStyle(.white)
            }
            .font(.system(size: 42, weight: .bold, design: .rounded))
            
            Text("Your AI Assistant")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

// MARK: - Login Card

private struct LoginCardView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isPasswordVisible: Bool
    let isLoading: Bool
    let canLogin: Bool
    let onLogin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Login")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
            
            // Email field
            TextField("Email", text: $email)
                .textFieldStyle(.plain)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Password field with eye toggle
            HStack(spacing: 12) {
                Group {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textFieldStyle(.plain)
                .textContentType(.password)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(.systemGray))
                }
                .buttonStyle(.plain)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Login button
            Button(action: onLogin) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                    } else {
                        Text("Login")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [
                            Color.blue,
                            Color.blue.opacity(0.85)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(!canLogin)
            .opacity(canLogin ? 1 : 0.6)
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
    LoginView()
}
