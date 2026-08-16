//
//  SignInView.swift
//  FluffyList
//
//  Sign in with Apple — "The Press" treatment. Masthead with a BETA
//  dateline, the "Dinner, decided." headline, italic sub-paragraph,
//  numbered value rows, and the one solid-ink block: Sign in with
//  Apple. Auth behaviour unchanged.
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffyMasthead(title: "", dateline: "BETA")
                .padding(.horizontal, 22)

            Text("Dinner,\ndecided.")
                .font(.fluffyDisplayLarge)
                .fluffyTracking(-0.035, at: 52)
                .lineSpacing(-52 * 0.02)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.horizontal, 22)
                .padding(.top, 40)
                .padding(.bottom, 20)

            Text("Sign in to plan\nwith your household.")
                .font(.custom(FluffyFace.italic, size: 19))
                .foregroundStyle(Color.fluffySecondary)
                .lineSpacing(4)
                .padding(.horizontal, 22)

            Spacer()

            FluffyValueRows()
                .padding(.horizontal, 22)
                .padding(.bottom, 30)

            // Sign in with Apple — full-width solid ink block, square
            // corners (Apple's own button, black style).
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
                    // The user backing out of the Apple sheet is a deliberate
                    // cancel, not a failure — don't surface an error for it.
                    if let authError = error as? ASAuthorizationError,
                       authError.code == .canceled {
                        return
                    }
                    authService.errorMessage = error.localizedDescription
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .padding(.horizontal, 22)

            if authService.isLoading {
                Text("Signing in\u{2026}")
                    .font(.fluffyCallout)
                    .foregroundStyle(Color.fluffySecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }

            if let error = authService.errorMessage {
                Text(error)
                    .font(.custom(FluffyFace.regular, size: 13))
                    .foregroundStyle(Color.fluffyError)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
            }

            Text("Free while in beta.")
                .font(.custom(FluffyFace.italic, size: 13))
                .foregroundStyle(Color.fluffySecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.fluffyBackground)
    }
}
