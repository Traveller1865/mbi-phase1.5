// ios/MBI/MBI/Views/AuthView.swift
// MBI Phase 1.5 — Chronos Auth Screen
// Epic 2 Sprint 1: confirm password field, trust signal, terms links, SSO removed

import SwiftUI

// ─────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────

struct ChronosTheme {
    static let ink       = Color(red: 0.04,  green: 0.04,  blue: 0.06)
    static let surface   = Color(red: 0.08,  green: 0.08,  blue: 0.11)
    static let panel     = Color(red: 0.10,  green: 0.10,  blue: 0.16)
    static let gold      = Color(red: 0.722, green: 0.580, blue: 0.416)
    static let goldLight = Color(red: 0.831, green: 0.671, blue: 0.510)
    static let goldDim   = Color(red: 0.722, green: 0.580, blue: 0.416).opacity(0.15)
    static let text      = Color(red: 0.965, green: 0.953, blue: 0.933)
    static let muted     = Color(red: 0.965, green: 0.953, blue: 0.933).opacity(0.5)
    static let faint     = Color(red: 0.965, green: 0.953, blue: 0.933).opacity(0.18)
    static let border    = Color.white.opacity(0.07)
}

extension Font {
    // Cormorant Garamond
    static func cormorant(size: CGFloat, weight: Font.Weight = .light) -> Font {
        switch weight {
        case .medium:   return .custom("CormorantGaramond-Medium",   size: size)
        case .semibold: return .custom("CormorantGaramond-SemiBold", size: size)
        case .bold:     return .custom("CormorantGaramond-Bold",     size: size)
        default:        return .custom("CormorantGaramond-Light",    size: size)
        }
    }

    static func cormorantItalic(size: CGFloat) -> Font {
        .custom("CormorantGaramond-LightItalic", size: size)
    }

    // Jost
    static func jost(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .light:    return .custom("Jost-Light",   size: size)
        case .medium:   return .custom("Jost-Medium",  size: size)
        case .semibold: return .custom("Jost-SemiBold",size: size)
        case .bold:     return .custom("Jost-Bold",    size: size)
        default:        return .custom("Jost-Regular", size: size)
        }
    }
}

// ─────────────────────────────────────────
// AUTH VIEW
// Sign-up: email + password + confirm + trust signal + terms
// Sign-in: email + password only (no confirm field)
// No SSO buttons — deferred to Phase 2
// ─────────────────────────────────────────

struct AuthView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var email           = ""
    @State private var password        = ""
    @State private var confirmPassword = ""
    @State private var isSignUp        = true    // default to sign-up for new installs
    @State private var isLoading       = false
    @State private var errorMessage: String?
    @State private var appeared        = false

    // Terms/Privacy sheet
    @State private var showTerms       = false
    @State private var showPrivacy     = false

    // Inline field errors
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmError: String?

    var canSubmit: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.06), .clear],
                center: .center, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 52)

                    // ── Logo ──
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

                            Text("BY MYND & BODI INSTITUTE")
                                .font(.jost(size: 9, weight: .light))
                                .foregroundColor(ChronosTheme.gold)
                                .tracking(4)

                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.clear, ChronosTheme.gold, .clear],
                                    startPoint: .leading, endPoint: .trailing))
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
                    .padding(.bottom, 44)

                    // ── Screen headline ──
                    Text(isSignUp ? "Create your account." : "Welcome back.")
                        .font(.cormorant(size: 26, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.4), value: appeared)

                    // ── Form fields ──
                    VStack(spacing: 0) {
                        // Email
                        VStack(alignment: .leading, spacing: 4) {
                            ChronosTextField(
                                placeholder: "Email address",
                                text: $email,
                                keyboardType: .emailAddress
                            )
                            if let err = emailError {
                                Text(err)
                                    .font(.jost(size: 11, weight: .light))
                                    .foregroundColor(Color(red: 0.9, green: 0.65, blue: 0.2))
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.bottom, 12)

                        // Password
                        VStack(alignment: .leading, spacing: 4) {
                            ChronosSecureField(
                                placeholder: "Password",
                                text: $password
                            )
                            if let err = passwordError {
                                Text(err)
                                    .font(.jost(size: 11, weight: .light))
                                    .foregroundColor(Color(red: 0.9, green: 0.65, blue: 0.2))
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.bottom, 12)

                        // Confirm password — sign-up only
                        if isSignUp {
                            VStack(alignment: .leading, spacing: 4) {
                                ChronosSecureField(
                                    placeholder: "Confirm password",
                                    text: $confirmPassword
                                )
                                if let err = confirmError {
                                    Text(err)
                                        .font(.jost(size: 11, weight: .light))
                                        .foregroundColor(Color(red: 0.9, green: 0.65, blue: 0.2))
                                        .padding(.horizontal, 4)
                                }
                            }
                            .padding(.bottom, 12)

                            // Trust signal
                            Text("We don't sell your data. Delete your account anytime.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 16)
                        }
                    }
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)

                    // ── Global error ──
                    if let error = errorMessage {
                        Text(error)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(.red.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)
                    }

                    // ── CTA block ──
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
                        .disabled(isLoading || !canSubmit)
                        .opacity(!canSubmit ? 0.45 : 1)

                        // Terms line — sign-up only
                        if isSignUp {
                            HStack(spacing: 4) {
                                Text("By continuing, you agree to our")
                                    .font(.jost(size: 11, weight: .light))
                                    .foregroundColor(ChronosTheme.faint)
                                Button(action: { showTerms = true }) {
                                    Text("Terms of Service")
                                        .font(.jost(size: 11, weight: .light))
                                        .foregroundColor(ChronosTheme.muted)
                                        .underline()
                                }
                                Text("and")
                                    .font(.jost(size: 11, weight: .light))
                                    .foregroundColor(ChronosTheme.faint)
                                Button(action: { showPrivacy = true }) {
                                    Text("Privacy Policy")
                                        .font(.jost(size: 11, weight: .light))
                                        .foregroundColor(ChronosTheme.muted)
                                        .underline()
                                }
                                Text(".")
                                    .font(.jost(size: 11, weight: .light))
                                    .foregroundColor(ChronosTheme.faint)
                            }
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        // Toggle sign-up / sign-in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isSignUp.toggle()
                            }
                            clearErrors()
                        }) {
                            Text(isSignUp
                                 ? "Already have an account? Sign in"
                                 : "New here? Create account")
                                .font(.jost(size: 13, weight: .light))
                                .foregroundColor(ChronosTheme.muted)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)

                    Spacer().frame(height: 52)

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
        }
        .onAppear { appeared = true }
        // Terms sheet
        .sheet(isPresented: $showTerms) {
            SafariSheet(url: URL(string: "https://myndandbodi.com/terms")!)
        }
        // Privacy sheet
        .sheet(isPresented: $showPrivacy) {
            SafariSheet(url: URL(string: "https://myndandbodi.com/privacy")!)
        }
    }

    // ── Validation & submit ──

    private func clearErrors() {
        emailError    = nil
        passwordError = nil
        confirmError  = nil
        errorMessage  = nil
        confirmPassword = ""
    }

    private func validate() -> Bool {
        var valid = true
        emailError    = nil
        passwordError = nil
        confirmError  = nil

        // Email format
        if !email.contains("@") || !email.contains(".") {
            emailError = "Invalid email format."
            valid = false
        }

        // Password length
        if password.count < 8 {
            passwordError = "Password must be at least 8 characters."
            valid = false
        }

        // Confirm match — sign-up only
        if isSignUp && password != confirmPassword {
            confirmError = "Passwords do not match."
            valid = false
        }

        return valid
    }

    private func submit() {
        errorMessage = nil
        guard validate() else { return }

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
// SAFARI SHEET — in-app browser for Terms / Privacy
// ─────────────────────────────────────────

import SafariServices

struct SafariSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.preferredControlTintColor = UIColor(
            red: 0.722, green: 0.580, blue: 0.416, alpha: 1.0
        )
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// ─────────────────────────────────────────
// CHRONOS LOGO MARK
// ─────────────────────────────────────────

struct ChronosLogoMark: View {
    @State private var arcProgress: CGFloat = 0
    @State private var rotating = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(ChronosTheme.gold.opacity(0.15), lineWidth: 1)
                .frame(width: 80, height: 80)

            Circle()
                .trim(from: 0, to: arcProgress * 0.75)
                .stroke(
                    LinearGradient(
                        colors: [ChronosTheme.gold.opacity(0.3), ChronosTheme.goldLight],
                        startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(-90))

            Circle()
                .stroke(ChronosTheme.gold.opacity(0.08), lineWidth: 1)
                .frame(width: 52, height: 52)

            Circle()
                .fill(ChronosTheme.gold.opacity(0.9))
                .frame(width: 5, height: 5)

            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.9))
                .frame(width: 1.5, height: 20)
                .offset(y: -10)
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: rotating)

            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.4))
                .frame(width: 1, height: 12)
                .offset(y: -8)
                .rotationEffect(.degrees(rotating ? 360 * 12 : 0))
                .animation(.linear(duration: 60).repeatForever(autoreverses: false), value: rotating)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).delay(0.2)) { arcProgress = 1 }
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
// CHRONOS SECURE FIELD — with show/hide toggle
// PDR Screen 3.1: password fields have show/hide toggle
// ─────────────────────────────────────────

struct ChronosSecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .trailing) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.06, green: 0.06, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ChronosTheme.border, lineWidth: 1)
                    )
                    .frame(height: 52)

                if isVisible {
                    TextField("", text: $text)
                        .placeholder(when: text.isEmpty) {
                            Text(placeholder)
                                .font(.jost(size: 13, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                        }
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .padding(.trailing, 44)
                } else {
                    SecureField("", text: $text)
                        .placeholder(when: text.isEmpty) {
                            Text(placeholder)
                                .font(.jost(size: 13, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                        }
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .padding(.horizontal, 16)
                        .padding(.trailing, 44)
                }
            }

            // Show/hide toggle
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 13, weight: .ultraLight))
                    .foregroundColor(ChronosTheme.faint)
            }
            .padding(.trailing, 16)
        }
    }
}

// ─────────────────────────────────────────
// SOCIAL AUTH BUTTON — kept for legacy refs
// Not rendered in Phase 1 (SSO deferred)
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
// LEGACY — MBITextField kept for other views
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
