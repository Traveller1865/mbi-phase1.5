// ios/MBI/MBI/Views/OnboardingFlowView.swift
// MBI Phase 1.5 — Onboarding Redesign · Epic 2 Sprint 1
// Stages: Claim → How It Works (3) → Account → Personalization (2) → HealthKit (2) → Baseline → Completion
// PDR: MBI_Epic2_Sprint1_OnboardingRedesign_PDR_v1_0

import SwiftUI
import HealthKit

// ─────────────────────────────────────────
// FLOW COORDINATOR
// Steps:
//   0  — Stage 1: The Claim
//   1  — Stage 2a: Five Signals      (skippable → 4)
//   2  — Stage 2b: Your Baseline     (skippable → 4)
//   3  — Stage 2c: Prediction Promise(skippable → 4)
//   4  — Stage 3: Account Creation   (handled by AuthView in sign-up mode — routed externally)
//        Note: Auth is handled by MBIApp root; after sign-up succeeds, onboarding resumes at step 5
//   5  — Stage 4a: Name & Step Goal
//   6  — Stage 4b: Health Goal
//   7  — Stage 5a: Soft HealthKit Pre-Permission
//   8  — Stage 5b: HealthKit Signal Confirmation
//   9  — Stage 6a: Baseline Build
//   10 — Stage 6b: Completion & Handoff
// ─────────────────────────────────────────

struct OnboardingFlowView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var step = 0

    // Shared profile state
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var birthday    = ""
    @State private var heightFt    = ""
    @State private var heightIn    = ""
    @State private var weightText  = ""
    @State private var healthGoal: String = ""   // no default — user must select

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()

            switch step {
            // Stage 1
            case 0:
                OnboardingClaimView(onNext: { step = 1 })

            // Stage 2 — How It Works (all skippable)
            case 1:
                OnboardingFiveSignalsView(
                    onNext: { step = 2 },
                    onSkip: { step = 5 }   // skip routes to Stage 4
                )
            case 2:
                OnboardingYourBaselineView(
                    onNext: { step = 3 },
                    onSkip: { step = 5 }
                )
            case 3:
                OnboardingPredictionPromiseView(
                    onNext: { step = 5 },  // Stage 2 → Stage 4 (auth already done)
                    onSkip: { step = 5 }
                )

            // Stage 4 — Personalization
            case 5:
                OnboardingProfileView(
                    firstName:  $firstName,
                    lastName:   $lastName,
                    birthday:   $birthday,
                    heightFt:   $heightFt,
                    heightIn:   $heightIn,
                    weightText: $weightText,
                    onNext: { step = 6 }
                )
            case 6:
                OnboardingHealthGoalView(
                    healthGoal: $healthGoal,
                    onNext: { step = 7 }
                )

            // Stage 5 — Connect Your Data
            case 7:
                OnboardingSoftHealthKitView(onNext: { step = 8 })
            case 8:
                OnboardingHealthKitConfirmView(onNext: { step = 9 })

            // Stage 6 — Baseline Build & Handoff
            case 9:
                OnboardingBootstrapView(
                    firstName: firstName,
                    onComplete: { step = 10 }
                )
            case 10:
                OnboardingCompletionView(firstName: firstName)

            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }
}

// ─────────────────────────────────────────
// PROGRESS INDICATOR — gold dash / muted dashes
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
// STAGE 1 — THE CLAIM
// PDR Screen 1.1
// ─────────────────────────────────────────

struct OnboardingClaimView: View {
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo block
            VStack(spacing: 0) {
                ChronosLogoMark()
                    .frame(width: 72, height: 72)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.8).delay(0.1), value: appeared)
                    .padding(.bottom, 24)

                VStack(spacing: 8) {
                    Text("CHRONOS")
                        .font(.cormorant(size: 40))
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
                        .frame(width: 100, height: 1)
                        .padding(.top, 12)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)
            }

            // Headline block
            VStack(spacing: 16) {
                Text("You are not average.\nYour health score shouldn't be either.")
                    .font(.cormorant(size: 28, weight: .light))
                    .foregroundColor(ChronosTheme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 32)
                    .padding(.top, 36)

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, ChronosTheme.gold.opacity(0.5), .clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: 60, height: 1)

                // Body copy — three lines, each one claim
                VStack(spacing: 8) {
                    Text("Five signals. One score. Updated every morning.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                    Text("Compared only to you. Never a population.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                    Text("The more you connect, the smarter it gets.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                }
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.7).delay(0.45), value: appeared)

            // Proof point card
            VStack(alignment: .leading, spacing: 8) {
                Text("FOR EXAMPLE")
                    .font(.jost(size: 9, weight: .medium))
                    .foregroundColor(ChronosTheme.gold)
                    .tracking(3)

                Text("\"Your HRV at 42ms is your strongest reading in 3 weeks.\"")
                    .font(.cormorantItalic(size: 15))
                    .foregroundColor(ChronosTheme.text.opacity(0.85))
                    .lineSpacing(4)

                Text("Same number. Completely different meaning.")
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ChronosTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ChronosTheme.border, lineWidth: 1)
                    )
                    .overlay(
                        // Gold left border
                        Rectangle()
                            .fill(ChronosTheme.gold)
                            .frame(width: 2)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            ),
                        alignment: .leading
                    )
            )
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.65), value: appeared)

            Spacer()

            // CTA block
            VStack(spacing: 12) {
                ChronosPrimaryButton(title: "Get Started", action: onNext)

                Text("Takes about 2 minutes.")
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(ChronosTheme.faint)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 52)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.8), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// ─────────────────────────────────────────
// STAGE 2a — THE FIVE SIGNALS
// PDR Screen 2.1
// ─────────────────────────────────────────

struct OnboardingFiveSignalsView: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    let signals: [(String, String, String)] = [
        ("waveform.path.ecg",  "Heart Rate Variability",  "How well your nervous system recovered overnight."),
        ("heart",              "Resting Heart Rate",       "How hard your heart is working at rest. A stress signal."),
        ("lungs",              "Respiratory Rate",         "Your earliest warning signal for illness and overload."),
        ("moon.zzz",           "Sleep Duration & Quality", "The window where your body repairs itself."),
        ("figure.walk",        "Steps & Active Minutes",   "How much you moved and how your body responded."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: 1, total: 3)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("We read five signals\nyour body sends every night.")
                            .font(.cormorant(size: 30, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                    VStack(spacing: 0) {
                        ForEach(signals, id: \.1) { icon, name, meaning in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .ultraLight))
                                    .foregroundColor(ChronosTheme.gold)
                                    .frame(width: 20, height: 20)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(name)
                                        .font(.jost(size: 13, weight: .regular))
                                        .foregroundColor(ChronosTheme.text)
                                    Text(meaning)
                                        .font(.jost(size: 12, weight: .light))
                                        .foregroundColor(ChronosTheme.muted)
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)

                            if name != signals.last?.1 {
                                Rectangle()
                                    .fill(ChronosTheme.border)
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }

                    // Skip link
                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 8)
                }
            }

            ChronosPrimaryButton(title: "Continue", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STAGE 2b — YOUR BASELINE
// PDR Screen 2.2
// ─────────────────────────────────────────

struct OnboardingYourBaselineView: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: 2, total: 3)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("Your baseline\nis yours alone.")
                        .font(.cormorant(size: 30, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)

                    // Two-column comparison card
                    HStack(spacing: 0) {
                        // Left — Every Other App
                        VStack(spacing: 8) {
                            Text("EVERY OTHER APP")
                                .font(.jost(size: 9, weight: .medium))
                                .foregroundColor(ChronosTheme.faint)
                                .tracking(2)
                                .multilineTextAlignment(.center)
                            Text("HRV 42ms")
                                .font(.cormorant(size: 22, weight: .light))
                                .foregroundColor(ChronosTheme.muted)
                            Text("Is this good?\nDepends on the average.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 12)

                        Rectangle()
                            .fill(ChronosTheme.border)
                            .frame(width: 1)
                            .padding(.vertical, 16)

                        // Right — Chronos
                        VStack(spacing: 8) {
                            Text("CHRONOS")
                                .font(.jost(size: 9, weight: .medium))
                                .foregroundColor(ChronosTheme.gold)
                                .tracking(2)
                            Text("HRV 42ms")
                                .font(.cormorant(size: 22, weight: .light))
                                .foregroundColor(ChronosTheme.text)
                            Text("Your strongest\nreading in 3 weeks.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.muted)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ChronosTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ChronosTheme.border, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                    // Explanation
                    VStack(alignment: .leading, spacing: 10) {
                        Text("We don't compare you to anyone else. We track your patterns over time and tell you when something shifts relative to your own normal.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .lineSpacing(5)

                        Text("That's why your score on Monday means something different than it does for your partner.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .lineSpacing(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 8)

                    // Skip link
                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                }
            }

            ChronosPrimaryButton(title: "Continue", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STAGE 2c — THE PREDICTION PROMISE
// PDR Screen 2.3
// ─────────────────────────────────────────

struct OnboardingPredictionPromiseView: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: 3, total: 3)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Text("The more you connect,\nthe more we can see.")
                        .font(.cormorant(size: 30, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 36)

                    // Three-tier device list
                    VStack(spacing: 0) {
                        DeviceTierRow(icon: "applewatch",        label: "Apple Watch",      badgeText: "Connected",   badgeActive: true)
                            Rectangle().fill(ChronosTheme.border).frame(height: 1).padding(.horizontal, 32)
                            DeviceTierRow(icon: "scalemass",         label: "Smart Scale",      badgeText: "Connected",   badgeActive: true)
                            Rectangle().fill(ChronosTheme.border).frame(height: 1).padding(.horizontal, 32)
                            DeviceTierRow(icon: "heart.text.square", label: "Blood Pressure",   badgeText: "Connected",   badgeActive: true)
                            Rectangle().fill(ChronosTheme.border).frame(height: 1).padding(.horizontal, 32)
                            DeviceTierRow(icon: "drop.circle",       label: "Blood Panel",      badgeText: "Coming Soon", badgeActive: false)
                            Rectangle().fill(ChronosTheme.border).frame(height: 1).padding(.horizontal, 32)
                            DeviceTierRow(icon: "target",            label: "Personal Targets", badgeText: "Coming Soon", badgeActive: false)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ChronosTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ChronosTheme.border, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                    Text("Right now, we're reading your Apple Health data. As you connect more devices, your Chronos score becomes more precise — and we can start to see patterns before you feel them.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

                    // Skip link
                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                }
            }

            ChronosPrimaryButton(title: "Continue", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

private struct DeviceTierRow: View {
    let icon: String
    let label: String
    let badgeText: String
    let badgeActive: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .ultraLight))
                .foregroundColor(badgeActive ? ChronosTheme.gold : ChronosTheme.faint)
                .frame(width: 24)

            Text(label)
                .font(.jost(size: 13, weight: .regular))
                .foregroundColor(badgeActive ? ChronosTheme.text : ChronosTheme.muted)

            Spacer()

            Text(badgeText)
                .font(.jost(size: 10, weight: .medium))
                .foregroundColor(badgeActive ? ChronosTheme.gold : ChronosTheme.faint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(badgeActive ? ChronosTheme.goldDim : ChronosTheme.surface)
                        .overlay(
                            Capsule().stroke(
                                badgeActive ? ChronosTheme.gold.opacity(0.3) : ChronosTheme.border,
                                lineWidth: 1
                            )
                        )
                )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }
}

// ─────────────────────────────────────────
// STAGE 4a — NAME & STEP GOAL
// PDR Screen 4.1
// ─────────────────────────────────────────

struct OnboardingProfileView: View {
    @EnvironmentObject var supabase: SupabaseService
    @Binding var firstName:  String
    @Binding var lastName:   String
    @Binding var birthday:   String
    @Binding var heightFt:   String
    @Binding var heightIn:   String
    @Binding var weightText: String
    let onNext: () -> Void

    @State private var selectedDate   = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var showDatePicker = false
    @State private var isLoading      = false
    @State private var error: String?

    private let storageFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()
    private var maxBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -13, to: Date()) ?? Date()
    }

    var canContinue: Bool { !firstName.trimmingCharacters(in: .whitespaces).isEmpty }
    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: 1, total: 2)
                .padding(.top, 64).padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who are we\npersonalizing this for?")
                            .font(.cormorant(size: 32, weight: .light))
                            .foregroundColor(ChronosTheme.text).lineSpacing(4)
                        Text("We use this to personalize your daily score and baseline calculations.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted).lineSpacing(4).padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32).padding(.bottom, 36)

                    VStack(spacing: 14) {
                        ChronosTextField(placeholder: "First name", text: $firstName)
                        ChronosTextField(placeholder: "Last name",  text: $lastName)

                        // Birthday — inline wheel picker
                        VStack(alignment: .leading, spacing: 6) {
                            Button(action: {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                withAnimation(.easeInOut(duration: 0.25)) { showDatePicker.toggle() }
                            }) {
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(red: 0.06, green: 0.06, blue: 0.09))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChronosTheme.border, lineWidth: 1))
                                        .frame(height: 52)
                                    HStack {
                                        Text(birthday.isEmpty ? "Birthday" : displayFmt.string(from: selectedDate))
                                            .font(.jost(size: 13, weight: .light))
                                            .foregroundColor(birthday.isEmpty ? ChronosTheme.faint : ChronosTheme.text)
                                            .padding(.horizontal, 16)
                                        Spacer()
                                        Image(systemName: "calendar")
                                            .font(.system(size: 13, weight: .ultraLight))
                                            .foregroundColor(ChronosTheme.faint).padding(.trailing, 16)
                                    }
                                }
                            }
                            if showDatePicker {
                                DatePicker("", selection: $selectedDate, in: ...maxBirthday, displayedComponents: .date)
                                    .datePickerStyle(.wheel).labelsHidden().colorScheme(.dark)
                                    .frame(maxWidth: .infinity)
                                    .onChange(of: selectedDate) { newDate in
                                        birthday = storageFmt.string(from: newDate)
                                    }
                                    .tint(ChronosTheme.gold)
                            }
                            Text("Used to calculate age-relative baselines.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint).padding(.horizontal, 4)
                        }

                        // Height
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                ChronosTextField(placeholder: "Ft",        text: $heightFt, keyboardType: .numberPad)
                                ChronosTextField(placeholder: "In (0–11)", text: $heightIn, keyboardType: .numberPad)
                            }
                            Text("Height — feet and inches.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint).padding(.horizontal, 4)
                        }

                        // Weight
                        VStack(alignment: .leading, spacing: 6) {
                            ChronosTextField(placeholder: "Current weight (lbs)", text: $weightText, keyboardType: .decimalPad)
                            Text("Used to personalize activity and metabolic signals.")
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint).padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 32)

                    if let error = error {
                        Text(error).font(.jost(size: 12, weight: .light)).foregroundColor(.red.opacity(0.75))
                            .padding(.top, 12).padding(.horizontal, 32)
                    }
                    Spacer().frame(height: 40)
                }
            }
            // Fix 1: tap outside to dismiss keyboard
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }

            ChronosPrimaryButton(title: "Continue", isLoading: isLoading) {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                guard canContinue else { error = "Please enter your first name to continue."; return }
                isLoading = true
                Task {
                    do {
                        guard let userId = supabase.session?.userId else { return }
                        try await supabase.updateOnboardingProfile(
                            userId:      userId,
                            displayName: displayName.isEmpty ? firstName : displayName,
                            birthday:    birthday.isEmpty ? nil : birthday,
                            heightFt:    Int(heightFt),
                            heightIn:    Int(heightIn),
                            weightLbs:   Double(weightText)
                        )
                        onNext()
                    } catch { self.error = error.localizedDescription }
                    isLoading = false
                }
            }
            .opacity(canContinue ? 1 : 0.45)
            .padding(.horizontal, 32).padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STAGE 4b — HEALTH GOAL
// PDR Screen 4.2 · Bug S1-001 fix: no default
// ─────────────────────────────────────────

struct OnboardingHealthGoalView: View {
    @EnvironmentObject var supabase: SupabaseService
    @Binding var healthGoal: String
    let onNext: () -> Void

    @State private var isLoading = false
    @State private var error: String?

    // PDR options → Supabase raw values
    // "Improve sleep" removed per founder decision (maps to general_wellness,
    // duplicate of General health awareness)
    let goalOptions: [(label: String, value: String)] = [
        ("Optimize recovery",       "recovery"),
        ("Reduce stress",           "stress_management"),
        ("Build resilience",        "fitness"),
        ("General health awareness","general_wellness"),
    ]

    var canContinue: Bool { !healthGoal.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressDots(current: 2, total: 2)
                .padding(.top, 64)
                .padding(.bottom, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's your primary\nhealth goal?")
                            .font(.cormorant(size: 32, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                            .lineSpacing(4)

                        Text("This shapes how we explain your score each day.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)

                    VStack(spacing: 10) {
                        ForEach(goalOptions, id: \.value) { option in
                            let isSelected = healthGoal == option.value
                            Button(action: { healthGoal = option.value }) {
                                HStack {
                                    Text(option.label)
                                        .font(.jost(size: 13, weight: isSelected ? .medium : .light))
                                        .foregroundColor(isSelected ? ChronosTheme.gold : ChronosTheme.muted)
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .light))
                                            .foregroundColor(ChronosTheme.gold)
                                    }
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isSelected ? ChronosTheme.goldDim : ChronosTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isSelected
                                                        ? ChronosTheme.gold.opacity(0.5)
                                                        : ChronosTheme.border,
                                                    lineWidth: isSelected ? 1.5 : 1
                                                )
                                        )
                                )
                            }
                            .padding(.horizontal, 32)
                        }
                    }

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
                guard canContinue else {
                    error = "Please select a health goal to continue."
                    return
                }
                isLoading = true
                Task {
                    do {
                        guard let userId = supabase.session?.userId else { return }
                        try await supabase.updateProfile(userId: userId, healthGoal: healthGoal)
                        onNext()
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            }
            .opacity(canContinue ? 1 : 0.45)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STAGE 5a — SOFT HEALTHKIT PRE-PERMISSION
// PDR Screen 5.1 · Net new
// ─────────────────────────────────────────

struct OnboardingSoftHealthKitView: View {
    let onNext: () -> Void

    @State private var isLoading = false

    let signals: [(String, String)] = [
        ("waveform.path.ecg",  "Heart Rate Variability"),
        ("heart",              "Resting Heart Rate"),
        ("lungs",              "Respiratory Rate"),
        ("moon.zzz",           "Sleep Duration & Quality"),
        ("figure.walk",        "Steps & Active Minutes"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    // Logo mark — smaller
                    ChronosLogoMark()
                        .frame(width: 56, height: 56)
                        .padding(.bottom, 32)

                    Text("Connect\nApple Health.")
                        .font(.cormorant(size: 32, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 16)

                    // Two-sentence explanation
                    VStack(spacing: 8) {
                        Text("We read 5 signals to build your daily Chronos score.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .multilineTextAlignment(.center)
                        Text("Without this connection, we can't calculate your score.")
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 36)

                    // Signal preview list
                    VStack(spacing: 0) {
                        ForEach(signals, id: \.1) { icon, name in
                            HStack(spacing: 14) {
                                Image(systemName: icon)
                                    .font(.system(size: 14, weight: .ultraLight))
                                    .foregroundColor(ChronosTheme.gold)
                                    .frame(width: 20)
                                Text(name)
                                    .font(.jost(size: 13, weight: .light))
                                    .foregroundColor(ChronosTheme.text)
                                Spacer()
                            }
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)

                            if name != signals.last?.1 {
                                Rectangle()
                                    .fill(ChronosTheme.border)
                                    .frame(height: 1)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                    .padding(.bottom, 12)

                    Text("Nothing is stored on device.")
                        .font(.jost(size: 11, weight: .light))
                        .foregroundColor(ChronosTheme.faint)
                        .padding(.bottom, 40)

                }
            }

            ChronosPrimaryButton(title: "Connect Apple Health", isLoading: isLoading) {
                isLoading = true
                Task {
                    try? await HealthKitManager.shared.requestAuthorization()
                    isLoading = false
                    onNext()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STAGE 5b — HEALTHKIT SIGNAL CONFIRMATION
// PDR Screen 5.2 · Existing screen refined
// ─────────────────────────────────────────

struct OnboardingHealthKitConfirmView: View {
    let onNext: () -> Void

    let metrics: [(String, String, String)] = [
        ("waveform.path.ecg", "Heart Rate Variability", "Your primary recovery signal"),
        ("heart",             "Resting Heart Rate",      "Autonomic balance and stress load"),
        ("lungs",             "Respiratory Rate",        "Strongest early illness indicator"),
        ("moon.zzz",          "Sleep Duration & Quality","Cellular repair window"),
        ("figure.walk",       "Steps & Active Minutes",  "Movement and behavioral patterns"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    Text("Connect\nApple Health.")
                        .font(.cormorant(size: 32, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)

                    Text("We read 5 signals to build your daily Chronos score. Nothing is stored on device.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(5)
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
                    .padding(.bottom, 20)

                    // Connected confirmation line
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .ultraLight))
                            .foregroundColor(ChronosTheme.gold)
                        Text("Apple Health connected. We'll start reading your data now.")
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }

            ChronosPrimaryButton(title: "Continue", action: onNext)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STAGE 6a — BASELINE BUILD
// PDR Screen 6.1 · Auto-starts, sequential callouts
// ─────────────────────────────────────────

struct OnboardingBootstrapView: View {
    @EnvironmentObject var supabase: SupabaseService
    let firstName: String
    let onComplete: () -> Void

    @State private var progress = 0
    @State private var total    = 0
    @State private var calloutIndex = 0
    @State private var error: String?
    @State private var isDone = false

    // Sequential signal callouts — PDR Section 6.1
    let callouts = [
        "Reading your HRV history...",
        "Reading your heart rate patterns...",
        "Reading your sleep data...",
        "Reading your respiratory signals...",
        "Reading your movement data...",
    ]

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(progress) / Double(total)
    }

    // Advance callout index in sync with processing progress
    var currentCallout: String {
        guard total > 0 else { return callouts[0] }
        let idx = min(
            Int((progressFraction * Double(callouts.count - 1)).rounded()),
            callouts.count - 1
        )
        return callouts[idx]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

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

            // Progress bar + sequential callout
            VStack(spacing: 14) {
                ProgressView(
                    value: progressFraction,
                    total: 1.0
                )
                .tint(ChronosTheme.gold)
                .padding(.horizontal, 32)

                Text(total == 0 ? "Scanning your health history..." : currentCallout)
                    .font(.jost(size: 12, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .animation(.easeInOut(duration: 0.4), value: progress)

                if total > 0 {
                    Text("Processing day \(progress) of \(total)...")
                        .font(.jost(size: 11, weight: .light))
                        .foregroundColor(ChronosTheme.faint)
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

            Spacer()
        }
        .onAppear {
            // Auto-start — no "Start Sync" button per PDR
            Task {
                guard let userId = supabase.session?.userId else { return }
                do {
                    try await SyncCoordinator.shared.runBaselineBootstrap(
                        userId: userId
                    ) { done, totalDays in
                        Task { @MainActor in
                            self.progress = done
                            self.total    = totalDays
                        }
                    }
                    isDone = true
                    onComplete()
                } catch {
                    self.error = "Some data couldn't be read — your score will improve as more history accumulates."
                    // Still route forward after a brief pause
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    onComplete()
                }
            }
        }
    }
}

// ─────────────────────────────────────────
// STAGE 6b — COMPLETION & HANDOFF
// PDR Screen 6.2
// onboarding_complete flips on screen LOAD, not button tap
// ─────────────────────────────────────────

struct OnboardingCompletionView: View {
    @EnvironmentObject var supabase: SupabaseService
    let firstName: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Checkmark clock mark
                ZStack {
                    Circle()
                        .stroke(ChronosTheme.gold.opacity(0.2), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .ultraLight))
                        .foregroundColor(ChronosTheme.gold)
                }

                VStack(spacing: 10) {
                    // Personalised headline
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

                    // Re-engagement hook — exact PDR copy
                    Text("Your score updates every morning.\nCome back tomorrow to see how you changed.")
                        .font(.cormorantItalic(size: 15))
                        .foregroundColor(ChronosTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.top, 4)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            ChronosPrimaryButton(title: "Open My Dashboard") {
                Task {
                    // Reload user so app root picks up onboarding_complete = true
                    if let userId = supabase.session?.userId {
                        _ = try? await supabase.loadCurrentUser(userId: userId)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .onAppear {
            // onboarding_complete flips on SCREEN LOAD per PDR Section 6.2
            Task {
                guard let userId = supabase.session?.userId else { return }
                try? await supabase.markOnboardingComplete(userId: userId)
            }
        }
    }
}

// ─────────────────────────────────────────
// CHRONOS PRIMARY BUTTON
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
