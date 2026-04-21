// ios/MBI/MBI/Views/OnboardingFlowView.swift
// MBI Phase 1.5 — Onboarding Flow · E-06
// Steps: Welcome → Profile → Health Goal → HealthKit → Baseline Bootstrap
// Note: height, weight, age, healthGoal collected in UI only.
//       Schema persistence deferred to post-validation onboarding refinement.

import SwiftUI
import HealthKit

// ─────────────────────────────────────────
// FLOW COORDINATOR
// ─────────────────────────────────────────

struct OnboardingFlowView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var step = 0

    // Shared profile state — passed through steps
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var stepGoalText = "8000"
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var ageText = ""
    @State private var healthGoal = ""

    var totalSteps: Int { 4 }

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()

            switch step {
            case 0:
                OnboardingWelcomeView(onNext: { step = 1 })
            case 1:
                OnboardingProfileView(
                    firstName: $firstName,
                    lastName: $lastName,
                    stepGoalText: $stepGoalText,
                    currentStep: 1, totalSteps: totalSteps,
                    onNext: { step = 2 }
                )
            case 2:
                OnboardingBodyView(
                    heightText: $heightText,
                    weightText: $weightText,
                    ageText: $ageText,
                    healthGoal: $healthGoal,
                    currentStep: 2, totalSteps: totalSteps,
                    onNext: { step = 3 }
                )
            case 3:
                OnboardingHealthKitView(
                    currentStep: 3, totalSteps: totalSteps,
                    onNext: { step = 4 }
                )
            case 4:
                OnboardingBootstrapView(
                    firstName: firstName,
                    onComplete: { step = 5 }
                )
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }
}

// ─────────────────────────────────────────
// PROGRESS DOTS
// ─────────────────────────────────────────

struct OnboardingProgressDots: View {
    let current: Int   // 1-indexed
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= current ? ChronosTheme.gold : ChronosTheme.faint)
                    .frame(width: i == current ? 20 : 6, height: 2)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
    }
}

// ─────────────────────────────────────────
// STEP 0: WELCOME
// ─────────────────────────────────────────

struct OnboardingWelcomeView: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                ChronosLogoMark()
                    .frame(width: 72, height: 72)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.8).delay(0.1), value: appeared)
                    .padding(.bottom, 32)

                VStack(spacing: 8) {
                    Text("CHRONOS")
                        .font(.cormorant(size: 40))
                        .foregroundColor(ChronosTheme.text)
                        .tracking(10)

                    Text("by Mynd & Bodi Institute")
                        .font(.jost(size: 10, weight: .light))
                        .foregroundColor(ChronosTheme.gold)
                        .tracking(4)
                        .textCase(.uppercase)

                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, ChronosTheme.gold, .clear],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: 100, height: 1)
                        .padding(.top, 12)

                    Text("Know your body.\nOwn your health.")
                        .font(.cormorantItalic(size: 16))
                        .foregroundColor(ChronosTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.top, 10)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)
            }

            Spacer()

            VStack(spacing: 14) {
                ChronosPrimaryButton(title: "Get Started", action: onNext)

                Text("Takes about 2 minutes.")
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(ChronosTheme.faint)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.6), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// ─────────────────────────────────────────
// STEP 1: NAME + STEP GOAL
// ─────────────────────────────────────────

struct OnboardingProfileView: View {
    @EnvironmentObject var supabase: SupabaseService
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var stepGoalText: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void

    @State private var isLoading = false
    @State private var error: String?

    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {

            // Progress
            OnboardingProgressDots(current: currentStep, total: totalSteps)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Heading
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who are we\npersonalizing this for?")
                            .font(.cormorant(size: 32, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                            .lineSpacing(4)

                        Text("We'll use your name throughout the app.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                    // Fields
                    VStack(spacing: 14) {
                        ChronosTextField(placeholder: "First name", text: $firstName)
                        ChronosTextField(placeholder: "Last name", text: $lastName)

                        VStack(alignment: .leading, spacing: 6) {
                            ChronosTextField(
                                placeholder: "Daily step goal",
                                text: $stepGoalText,
                                keyboardType: .numberPad
                            )
                            Text("Default is 8,000. Adjust to your lifestyle.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 32)

                    if let error = error {
                        Text(error)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(.red.opacity(0.75))
                            .padding(.top, 12)
                            .padding(.horizontal, 32)
                    }

                    Spacer().frame(height: 40)
                }
            }

            ChronosPrimaryButton(title: "Continue", isLoading: isLoading) {
                guard !firstName.isEmpty, let goal = Int(stepGoalText) else {
                    error = "Please enter your first name and a valid step goal."
                    return
                }
                isLoading = true
                Task {
                    do {
                        guard let userId = supabase.session?.userId else { return }
                        try await supabase.updateUser(
                            userId: userId,
                            displayName: displayName.isEmpty ? firstName : displayName,
                            stepGoal: goal
                        )
                        onNext()
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STEP 2: BODY + HEALTH GOAL
// ─────────────────────────────────────────

struct OnboardingBodyView: View {
    @Binding var heightText: String
    @Binding var weightText: String
    @Binding var ageText: String
    @Binding var healthGoal: String
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void

    let goalOptions = [
        "Optimize recovery",
        "Reduce stress",
        "Improve sleep",
        "Build resilience",
        "General health awareness"
    ]

    var body: some View {
        VStack(spacing: 0) {

            OnboardingProgressDots(current: currentStep, total: totalSteps)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("A little about\nyour body.")
                            .font(.cormorant(size: 32, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                            .lineSpacing(4)

                        Text("Used to contextualize your physiological signals. Optional for now.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .lineSpacing(4)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                    // Body fields
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            ChronosTextField(placeholder: "Height (in)", text: $heightText, keyboardType: .decimalPad)
                            ChronosTextField(placeholder: "Weight (lbs)", text: $weightText, keyboardType: .decimalPad)
                        }
                        ChronosTextField(placeholder: "Age", text: $ageText, keyboardType: .numberPad)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                    // Health goal
                    VStack(alignment: .leading, spacing: 14) {
                        Text("What's your primary health goal?")
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .tracking(1)
                            .padding(.horizontal, 32)

                        VStack(spacing: 8) {
                            ForEach(goalOptions, id: \.self) { option in
                                Button(action: { healthGoal = option }) {
                                    HStack {
                                        Text(option)
                                            .font(.jost(size: 13, weight: .light))
                                            .foregroundColor(healthGoal == option
                                                ? ChronosTheme.gold
                                                : ChronosTheme.muted)
                                        Spacer()
                                        if healthGoal == option {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .light))
                                                .foregroundColor(ChronosTheme.gold)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(healthGoal == option
                                                ? ChronosTheme.goldDim
                                                : ChronosTheme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(healthGoal == option
                                                        ? ChronosTheme.gold.opacity(0.3)
                                                        : ChronosTheme.border,
                                                        lineWidth: 1)
                                            )
                                    )
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }

            ChronosPrimaryButton(title: "Continue") { onNext() }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STEP 3: HEALTHKIT
// ─────────────────────────────────────────

struct OnboardingHealthKitView: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void

    @State private var isLoading = false
    @State private var error: String?

    let metrics: [(String, String, String)] = [
        ("waveform.path.ecg", "Heart Rate Variability", "Your primary recovery signal"),
        ("heart", "Resting Heart Rate", "Autonomic balance and stress load"),
        ("lungs", "Respiratory Rate", "Strongest early illness indicator"),
        ("moon.zzz", "Sleep Duration & Quality", "Cellular repair window"),
        ("figure.walk", "Steps & Active Minutes", "Movement and behavioral patterns"),
    ]

    var body: some View {
        VStack(spacing: 0) {

            OnboardingProgressDots(current: currentStep, total: totalSteps)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Connect\nApple Health.")
                            .font(.cormorant(size: 32, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                            .lineSpacing(4)

                        Text("We read 5 signals to build your daily Chronos score. Nothing is stored on device.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .lineSpacing(5)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                    VStack(spacing: 0) {
                        ForEach(metrics, id: \.1) { icon, name, description in
                            HStack(alignment: .center, spacing: 14) {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .ultraLight))
                                    .foregroundColor(ChronosTheme.gold)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(name)
                                        .font(.jost(size: 13, weight: .regular))
                                        .foregroundColor(ChronosTheme.text)
                                    Text(description)
                                        .font(.jost(size: 11, weight: .light))
                                        .foregroundColor(ChronosTheme.muted)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)

                            if name != metrics.last?.1 {
                                Rectangle()
                                    .fill(ChronosTheme.border)
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }

                    if let error = error {
                        Text(error)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(.red.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, 16)
                            .padding(.horizontal, 32)
                    }

                    Spacer().frame(height: 40)
                }
            }

            ChronosPrimaryButton(title: "Connect Apple Health", isLoading: isLoading) {
                isLoading = true
                Task {
                    do {
                        try await HealthKitManager.shared.requestAuthorization()
                        onNext()
                    } catch {
                        self.error = "Authorization failed. Please allow access in Settings → Privacy → Health."
                    }
                    isLoading = false
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STEP 4: BASELINE BOOTSTRAP
// ─────────────────────────────────────────

struct OnboardingBootstrapView: View {
    @EnvironmentObject var supabase: SupabaseService
    let firstName: String
    let onComplete: () -> Void

    @State private var progress = 0
    @State private var total = 0
    @State private var isStarted = false
    @State private var error: String?
    @State private var isDone = false

    var progressLabel: String {
        if total == 0 { return "Scanning your health history..." }
        if progress == 0 { return "Found \(total) days. Starting..." }
        return "Processing day \(progress) of \(total)..."
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if isDone {
                // ── Done state ──
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(ChronosTheme.gold.opacity(0.2), lineWidth: 1)
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundColor(ChronosTheme.gold)
                    }

                    VStack(spacing: 8) {
                        Text(firstName.isEmpty ? "You're all set." : "\(firstName), you're all set.")
                            .font(.cormorant(size: 32, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                            .multilineTextAlignment(.center)

                        Text("Your baseline is ready.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)

                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, ChronosTheme.gold.opacity(0.4), .clear],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 80, height: 1)
                            .padding(.top, 8)

                        Text("Your first Chronos Score\nwill be waiting for you.")
                            .font(.cormorantItalic(size: 16))
                            .foregroundColor(ChronosTheme.muted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 40)

            } else {
                // ── Syncing state ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("Building your\nbaseline.")
                        .font(.cormorant(size: 32, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .lineSpacing(4)

                    Text("We're reading your full Apple Health history to personalize your scoring from day one.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(5)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                if isStarted {
                    VStack(spacing: 14) {
                        ProgressView(
                            value: total > 0 ? Double(progress) : 0,
                            total: total > 0 ? Double(total) : 1
                        )
                        .tint(ChronosTheme.gold)
                        .padding(.horizontal, 32)

                        Text(progressLabel)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .animation(.easeInOut, value: progress)
                    }
                }

                if let error = error {
                    Text(error)
                        .font(.jost(size: 12, weight: .light))
                        .foregroundColor(.red.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }
            }

            Spacer()

            if isDone {
                ChronosPrimaryButton(title: "Open My Dashboard") {
                    Task {
                        if let userId = supabase.session?.userId {
                            try? await supabase.markOnboardingComplete(userId: userId)
                            _ = try? await supabase.loadCurrentUser(userId: userId)
                        }
                        onComplete()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)

            } else if !isStarted {
                ChronosPrimaryButton(title: "Start Sync") {
                    isStarted = true
                    Task {
                        guard let userId = supabase.session?.userId else { return }
                        do {
                            try await SyncCoordinator.shared.runBaselineBootstrap(
                                userId: userId
                            ) { done, total in
                                Task { @MainActor in
                                    self.progress = done
                                    self.total = total
                                }
                            }
                            isDone = true
                        } catch {
                            self.error = "Some data couldn't be read — your score will improve as more history accumulates."
                            isDone = true
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

// ─────────────────────────────────────────
// CHRONOS PRIMARY BUTTON
// (replaces MBIPrimaryButton in onboarding)
// MBIPrimaryButton kept in file for other views
// ─────────────────────────────────────────

struct ChronosPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ChronosTheme.text)
                    .frame(height: 52)

                if isLoading {
                    ProgressView().tint(ChronosTheme.ink)
                } else {
                    Text(title)
                        .font(.jost(size: 13, weight: .medium))
                        .foregroundColor(ChronosTheme.ink)
                        .tracking(2)
                        .textCase(.uppercase)
                }
            }
        }
        .disabled(isLoading)
    }
}

// ─────────────────────────────────────────
// LEGACY — kept for FeedbackView + AdminView
// ─────────────────────────────────────────

struct MBIPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        ChronosPrimaryButton(title: title, isLoading: isLoading, action: action)
    }
}
