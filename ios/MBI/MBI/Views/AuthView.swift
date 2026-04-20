// ios/MBI/MBI/Views/AuthView.swift
// MBI Phase 1.5 — Chronos Auth Screen

import SwiftUI

// ─────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────

struct ChronosTheme {
    static let ink = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let surface = Color(red: 0.08, green: 0.08, blue: 0.11)
    static let panel = Color(red: 0.10, green: 0.10, blue: 0.16)
    static let gold = Color(red: 0.722, green: 0.580, blue: 0.416)
    static let goldLight = Color(red: 0.831, green: 0.671, blue: 0.510)
    static let goldDim = Color(red: 0.722, green: 0.580, blue: 0.416).opacity(0.15)
    static let text = Color(red: 0.965, green: 0.953, blue: 0.933)
    static let muted = Color(red: 0.965, green: 0.953, blue: 0.933).opacity(0.5)
    static let faint = Color(red: 0.965, green: 0.953, blue: 0.933).opacity(0.18)
    static let border = Color.white.opacity(0.07)
}

extension Font {
    // Cormorant Garamond
    static func cormorant(size: CGFloat, weight: Font.Weight = .light) -> Font {
        switch weight {
        case .medium:
            return .custom("CormorantGaramond-Medium", size: size)
        case .semibold:
            return .custom("CormorantGaramond-SemiBold", size: size)
        case .bold:
            return .custom("CormorantGaramond-Bold", size: size)
        default:
            return .custom("CormorantGaramond-Light", size: size)
        }
    }

    static func cormorantItalic(size: CGFloat) -> Font {
        .custom("CormorantGaramond-LightItalic", size: size)
    }

    // Jost
    static func jost(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .light:
            return .custom("Jost-Light", size: size)
        case .medium:
            return .custom("Jost-Medium", size: size)
        case .semibold:
            return .custom("Jost-SemiBold", size: size)
        case .bold:
            return .custom("Jost-Bold", size: size)
        default:
            return .custom("Jost-Regular", size: size)
        }
    }
}

// ─────────────────────────────────────────
// AUTH VIEW
// ─────────────────────────────────────────

struct AuthView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Background
            ChronosTheme.ink.ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo Mark ──
                VStack(spacing: 0) {
                    ChronosLogoMark()
                        .frame(width: 80, height: 80)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.easeOut(duration: 0.8).delay(0.1), value: appeared)

                    VStack(spacing: 6) {
                        Text("CHRONOS")
                            .font(.cormorant(size: 44))
                            .foregroundColor(ChronosTheme.text)
                            .tracking(10)

                        Text("by Mynd & Bodi Institute")
                            .font(.jost(size: 10, weight: .light))
                            .foregroundColor(ChronosTheme.gold)
                            .tracking(4)
                            .textCase(.uppercase)

                        // Thin gold rule
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, ChronosTheme.gold, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 120, height: 1)
                            .padding(.top, 10)

                        Text("Know your body. Own your health.")
                            .font(.cormorantItalic(size: 15))
                            .foregroundColor(ChronosTheme.muted)
                            .padding(.top, 8)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)
                }
                .padding(.bottom, 52)

                // ── Form ──
                VStack(spacing: 12) {
                    ChronosTextField(
                        placeholder: "Email address",
                        text: $email,
                        keyboardType: .emailAddress
                    )
                    ChronosTextField(
                        placeholder: "Password",
                        text: $password,
                        isSecure: true
                    )
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)

                // ── Error ──
                if let error = errorMessage {
                    Text(error)
                        .font(.jost(size: 12, weight: .light))
                        .foregroundColor(.red.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 32)
                }

                // ── CTA ──
                VStack(spacing: 16) {
                    // Primary button
                    Button(action: submit) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ChronosTheme.text)
                                .frame(height: 52)

                            if isLoading {
                                ProgressView().tint(ChronosTheme.ink)
                            } else {
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.jost(size: 14, weight: .medium))
                                    .foregroundColor(ChronosTheme.ink)
                                    .tracking(2)
                                    .textCase(.uppercase)
                            }
                        }
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.5 : 1)

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle().fill(ChronosTheme.border).frame(height: 1)
                        Text("or")
                            .font(.jost(size: 11, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                        Rectangle().fill(ChronosTheme.border).frame(height: 1)
                    }

                    // Apple Sign In stub (Phase 2)
                    SocialAuthButton(
                        icon: "apple.logo",
                        label: "Continue with Apple"
                    ) {
                        // Phase 2 implementation
                    }

                    // Google Sign In stub (Phase 2)
                    SocialAuthButton(
                        icon: "globe",
                        label: "Continue with Google"
                    ) {
                        // Phase 2 implementation
                    }

                    // Toggle sign up / sign in
                    Button(action: {
                        isSignUp.toggle()
                        errorMessage = nil
                    }) {
                        Text(isSignUp
                             ? "Already have an account? "
                             + "Sign in"
                             : "New here? "
                             + "Create account")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)

                Spacer()

                // Footer
                Text("Chronos · MBI · Confidential")
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.faint)
                    .tracking(2)
                    .padding(.bottom, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.8), value: appeared)
            }
        }
        .onAppear { appeared = true }
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

// ─────────────────────────────────────────
// CHRONOS LOGO MARK (SVG-style in SwiftUI)
// ─────────────────────────────────────────

struct ChronosLogoMark: View {
    @State private var arcProgress: CGFloat = 0
    @State private var rotating = false

    var body: some View {
        ZStack {
            // Tick ring
            Circle()
                .stroke(ChronosTheme.gold.opacity(0.15), lineWidth: 1)
                .frame(width: 80, height: 80)

            // Animated arc
            Circle()
                .trim(from: 0, to: arcProgress * 0.75)
                .stroke(
                    LinearGradient(
                        colors: [ChronosTheme.gold.opacity(0.3), ChronosTheme.goldLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            // Inner circle
            Circle()
                .stroke(ChronosTheme.gold.opacity(0.08), lineWidth: 1)
                .frame(width: 52, height: 52)

            // Center dot
            Circle()
                .fill(ChronosTheme.gold.opacity(0.9))
                .frame(width: 5, height: 5)

            // Hour hand
            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.9))
                .frame(width: 1.5, height: 20)
                .offset(y: -10)
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .animation(
                    .linear(duration: 60).repeatForever(autoreverses: false),
                    value: rotating
                )

            // Minute hand
            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.4))
                .frame(width: 1, height: 12)
                .offset(y: -8)
                .rotationEffect(.degrees(rotating ? 360 * 12 : 0))
                .animation(
                    .linear(duration: 60).repeatForever(autoreverses: false),
                    value: rotating
                )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.2)) {
                arcProgress = 1
            }
            rotating = true
        }
    }
}

// ─────────────────────────────────────────
// CHRONOS TEXT FIELD
// ─────────────────────────────────────────

struct ChronosTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ChronosTheme.border, lineWidth: 1)
                )
                .frame(height: 52)

            if isSecure {
                SecureField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                    .font(.jost(size: 13, weight: .light))
                    .foregroundColor(ChronosTheme.text)
                    .padding(.horizontal, 16)
                    .autocorrectionDisabled()
            } else {
                TextField("", text: $text)
                    .placeholder(when: text.isEmpty) {
                        Text(placeholder)
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                    .font(.jost(size: 13, weight: .light))
                    .foregroundColor(ChronosTheme.text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
            }
        }
    }
}

// ─────────────────────────────────────────
// SOCIAL AUTH BUTTON
// ─────────────────────────────────────────

struct SocialAuthButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light))
                Text(label)
                    .font(.jost(size: 13, weight: .light))
                    .tracking(0.5)
            }
            .foregroundColor(ChronosTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(ChronosTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ChronosTheme.border, lineWidth: 1)
                    )
            )
        }
    }
}

// ─────────────────────────────────────────
// PLACEHOLDER HELPER
// ─────────────────────────────────────────

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}

// ─────────────────────────────────────────
// LEGACY SUPPORT — MBITextField kept for
// other views that still reference it
// ─────────────────────────────────────────

struct MBITextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        ChronosTextField(
            placeholder: placeholder,
            text: $text,
            keyboardType: keyboardType,
            isSecure: isSecure
        )
    }
}
