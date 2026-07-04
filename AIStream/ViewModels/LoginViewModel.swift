//
//  LoginViewModel.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false
    
    private let authService: AuthService
    
    init(authService: AuthService = .shared) {
        self.authService = authService
    }
    
    var canLogin: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        !isLoading
    }
    
    func login() {
        guard canLogin else { return }
        
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                _ = try await authService.login(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch let error as AuthError {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
            isLoading = false
        }
    }
    
    func clearError() {
        errorMessage = nil
        showErrorAlert = false
    }
}
