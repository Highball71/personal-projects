//
//  SignInView.swift
//  FluffyList
//
//  Sign in with Apple screen — shown before the main app.
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon area
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.fluffyAccent)

            Text("FluffyList")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.fluffyPrimary)

            Text("Household meal planning,\nmade simple.")
                .font(.title3)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Sign in with Apple button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        Task {
                            await authService.signInWithApple(credential: credential)
                        }
                    }
                case .failure(let error):
                    authService.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            if authService.isLoading {
                ProgressView("Signing in...")
            }

            if let error = authService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
    }
}
