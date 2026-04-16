// ios/MBI/Views/AuthView.swift
// MBI Phase 1 — Auth Screen (Email/Password via Supabase)

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Brand
                VStack(spacing: 8) {
                    Text("MYND & BODI")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(4)

                    Text("Institute")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.white)

                    Text("Daily physiological intelligence")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 56)

                // Form
                VStack(spacing: 16) {
                    MBITextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                    MBITextField(placeholder: "Password", text: $password, isSecure: true)
                }
                .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 12)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                // CTA
                VStack(spacing: 12) {
                    Button(action: submit) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white)

                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(height: 52)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1)

                    Button(action: { isSignUp.toggle(); errorMessage = nil }) {
                        Text(isSignUp ? "Already have an account? Sign in" : "New here? Create account")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                if isSignUp {
                    _ = try await supabase.signUp(email: email, password: password)
                } else {
                    _ = try await supabase.signIn(email: email, password: password)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct MBITextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .frame(height: 50)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
            }
        }
    }
}
