// ios/MBI/MBI/Views/AccountView.swift
// MBI Phase 1.5 — Account Full Build · E-10 (R-04)
// Pinned header · Tabbed layout: Overview / Goals / Health Info / Settings
// R-03b: ResyncCard added to Settings tab
// Fix: HorizonPlaceholderView moved to top level (was nested in AccountInfoNote)

import SwiftUI

// ─────────────────────────────────────────
// ACCOUNT VIEW
// ─────────────────────────────────────────

struct AccountView: View {
    @EnvironmentObject var supabase: SupabaseService
    @EnvironmentObject var sync: SyncCoordinator
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: AccountTab = .overview
    @State private var showSignOutConfirm = false
    @State private var founderTapCount = 0
    @State private var showFounderSection = false

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Dismiss ──
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                            .padding(10)
                            .background(Circle().fill(ChronosTheme.surface))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // ── Pinned profile header ──
                AccountProfileHeader(
                    user: supabase.currentUser,
                    score: sync.dashboard?.score,
                    onAvatarTap: {
                        founderTapCount += 1
                        if founderTapCount >= 7 {
                            withAnimation(.easeInOut) { showFounderSection = true }
                        }
                    }
                )

                // ── Tab selector ──
                AccountTabBar(selected: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                // ── Tab content ──
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .overview:
                            AccountOverviewTab(
                                score: sync.dashboard?.score,
                                showSignOutConfirm: $showSignOutConfirm
                            )
                        case .goals:
                            AccountGoalsTab(user: supabase.currentUser)
                        case .healthInfo:
                            AccountHealthInfoTab(user: supabase.currentUser)
                        case .settings:
                            AccountSettingsTab()
                                .environmentObject(supabase)
                                .environmentObject(sync)
                        }

                        // Founder section — tap avatar 7× to reveal
                        if showFounderSection {
                            VStack(spacing: 0) {
                                HStack {
                                    Rectangle().fill(ChronosTheme.gold.opacity(0.2)).frame(height: 1)
                                    Text("FOUNDER")
                                        .font(.jost(size: 8, weight: .light))
                                        .foregroundColor(ChronosTheme.gold.opacity(0.5))
                                        .tracking(3).padding(.horizontal, 12)
                                    Rectangle().fill(ChronosTheme.gold.opacity(0.2)).frame(height: 1)
                                }
                                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)

                                AdminView()
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Text("Chronos · MBI · Confidential")
                            .font(.jost(size: 9, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                            .tracking(2)
                            .padding(.top, 32)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { supabase.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign back in.")
        }
    }
}

// ─────────────────────────────────────────
// ACCOUNT TAB ENUM
// ─────────────────────────────────────────

enum AccountTab: String, CaseIterable {
    case overview   = "Overview"
    case goals      = "Goals"
    case healthInfo = "Health Info"
    case settings   = "Settings"
}

// ─────────────────────────────────────────
// TAB BAR
// ─────────────────────────────────────────

struct AccountTabBar: View {
    @Binding var selected: AccountTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AccountTab.allCases, id: \.self) { tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.18)) { selected = tab } }) {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.jost(size: 11, weight: selected == tab ? .medium : .light))
                            .foregroundColor(selected == tab ? ChronosTheme.gold : ChronosTheme.muted)
                            .tracking(0.5)

                        Rectangle()
                            .fill(selected == tab ? ChronosTheme.gold : Color.clear)
                            .frame(height: 1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(ChronosTheme.border).frame(height: 1)
        }
    }
}

// ─────────────────────────────────────────
// PINNED PROFILE HEADER
// ─────────────────────────────────────────

struct AccountProfileHeader: View {
    let user: MBIUser?
    let score: DailyScore?
    let onAvatarTap: () -> Void

    var bandColor: Color {
        switch score?.scoreBand {
        case .thriving:   return Color(red: 0.40, green: 0.82, blue: 0.50)
        case .recovering: return ChronosTheme.goldLight
        case .drifting:   return Color(red: 1.0, green: 0.78, blue: 0.28)
        case .redline:    return Color(red: 1.0, green: 0.40, blue: 0.40)
        case .none:       return ChronosTheme.muted
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onAvatarTap) {
                ZStack {
                    Circle()
                        .fill(ChronosTheme.goldDim)
                        .overlay(Circle().stroke(ChronosTheme.gold.opacity(0.3), lineWidth: 1))
                        .frame(width: 60, height: 60)
                    Text(initials(from: user?.displayName))
                        .font(.cormorant(size: 24, weight: .light))
                        .foregroundColor(ChronosTheme.gold)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName ?? "—")
                    .font(.cormorant(size: 24, weight: .light))
                    .foregroundColor(ChronosTheme.text)

                Text(user?.email ?? "")
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(ChronosTheme.muted)

                if let band = score?.scoreBand {
                    Text(band.rawValue.uppercased())
                        .font(.jost(size: 8, weight: .medium))
                        .foregroundColor(bandColor)
                        .tracking(2)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(bandColor.opacity(0.1))
                                .overlay(Capsule().stroke(bandColor.opacity(0.25), lineWidth: 1))
                        )
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func initials(from name: String?) -> String {
        guard let name, !name.isEmpty else { return "C" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

// ─────────────────────────────────────────
// OVERVIEW TAB
// ─────────────────────────────────────────

struct AccountOverviewTab: View {
    let score: DailyScore?
    @Binding var showSignOutConfirm: Bool

    var body: some View {
        VStack(spacing: 16) {

            if let score {
                AccountStatsPills(score: score)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 10) {
                AccountRow(icon: "heart.fill",
                           label: "Apple Health",
                           value: "Connected",
                           valueColor: Color(red: 0.40, green: 0.82, blue: 0.50))

                if let score {
                    AccountRow(icon: "waveform.path.ecg",
                               label: "Score Status",
                               value: score.isProvisional ? "Building baseline" : "Baseline active",
                               valueColor: score.isProvisional
                                   ? ChronosTheme.gold
                                   : Color(red: 0.40, green: 0.82, blue: 0.50))

                    AccountRow(icon: "cpu",
                               label: "Engine",
                               value: score.domainVersion)
                }
            }
            .padding(.horizontal, 20)

            Button(action: { showSignOutConfirm = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 13, weight: .light))
                    Text("Sign Out")
                        .font(.jost(size: 13, weight: .light))
                        .tracking(1)
                }
                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45).opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.15), lineWidth: 1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.top, 20)
    }
}

// ─────────────────────────────────────────
// GOALS TAB
// ─────────────────────────────────────────

struct AccountGoalsTab: View {
    let user: MBIUser?

    var body: some View {
        VStack(spacing: 10) {
            if let user {
                AccountRow(icon: "figure.walk",
                           label: "Daily Step Goal",
                           value: "\(user.stepGoal) steps")
            }

            AccountRow(icon: "moon.stars",
                       label: "Brief Delivery",
                       value: "Morning",
                       valueColor: ChronosTheme.gold)

            AccountRow(icon: "target",
                       label: "Health Goal",
                       value: user != nil ? "Longevity" : "—",
                       valueColor: ChronosTheme.muted)

            AccountInfoNote(text: "Goal editing and brief delivery time preferences coming in the next update. Wake and sleep time prefs will personalize your morning and evening briefs.")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// ─────────────────────────────────────────
// HEALTH INFO TAB
// ─────────────────────────────────────────

struct AccountHealthInfoTab: View {
    let user: MBIUser?

    var body: some View {
        VStack(spacing: 10) {
            AccountRow(icon: "ruler",       label: "Height",      value: "—")
            AccountRow(icon: "scalemass",   label: "Weight",      value: "—")
            AccountRow(icon: "calendar",    label: "Age",         value: "—")
            AccountRow(icon: "heart.text.square", label: "Health Goal", value: "—")

            AccountInfoNote(text: "Health info is captured during onboarding. Writing these values to your profile is coming in a future update.")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// ─────────────────────────────────────────
// SETTINGS TAB
// Notifications · HealthKit · Wake/sleep · Resync
// ─────────────────────────────────────────

struct AccountSettingsTab: View {
    @EnvironmentObject var supabase: SupabaseService
    @EnvironmentObject var sync: SyncCoordinator

    var body: some View {
        VStack(spacing: 10) {
            AccountRow(icon: "bell",
                       label: "Morning Brief",
                       value: "On",
                       valueColor: Color(red: 0.40, green: 0.82, blue: 0.50))

            AccountRow(icon: "moon.fill",
                       label: "Wake Time",
                       value: "6:00 AM",
                       valueColor: ChronosTheme.muted)

            AccountRow(icon: "moon.zzz",
                       label: "Sleep Time",
                       value: "10:00 PM",
                       valueColor: ChronosTheme.muted)

            AccountRow(icon: "applewatch",
                       label: "HealthKit",
                       value: "Connected",
                       valueColor: Color(red: 0.40, green: 0.82, blue: 0.50))

            // ── History Resync ──────────────────────────────────────
            ResyncCard()
                .environmentObject(supabase)
                .environmentObject(sync)

            AccountInfoNote(text: "Wake and sleep time editing, notification controls, and HealthKit re-authorization coming in the next update.")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// ─────────────────────────────────────────
// RESYNC CARD
// Full history re-score. Used after backend changes
// (e.g. R-03b D5 fix) to populate new domain scores.
// ─────────────────────────────────────────

struct ResyncCard: View {
    @EnvironmentObject var supabase: SupabaseService
    @EnvironmentObject var sync: SyncCoordinator

    @State private var isResyncing = false
    @State private var progress = 0
    @State private var total = 0
    @State private var isDone = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(ChronosTheme.gold)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Resync History")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                    Text("Re-scores all available Apple Health history.")
                        .font(.jost(size: 11, weight: .light))
                        .foregroundColor(ChronosTheme.faint)
                        .lineSpacing(3)
                }

                Spacer()

                if isDone {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(Color(red: 0.40, green: 0.82, blue: 0.50))
                }
            }

            // Progress bar — visible while running
            if isResyncing {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ChronosTheme.faint.opacity(0.3))
                                .frame(height: 2)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(LinearGradient(
                                    colors: [ChronosTheme.gold.opacity(0.6), ChronosTheme.goldLight],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(
                                    width: total > 0
                                        ? geo.size.width * CGFloat(progress) / CGFloat(total)
                                        : 0,
                                    height: 2
                                )
                        }
                    }
                    .frame(height: 2)

                    Text(total == 0
                         ? "Scanning history..."
                         : "Day \(progress) of \(total)")
                        .font(.jost(size: 10, weight: .light))
                        .foregroundColor(ChronosTheme.faint)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            // Error
            if let err = errorMessage {
                Text(err)
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                    .lineSpacing(3)
            }

            // Button — hidden while running
            if !isResyncing {
                Button(action: runResync) {
                    Text(isDone ? "Sync Again" : "Start Resync")
                        .font(.jost(size: 12, weight: .medium))
                        .foregroundColor(ChronosTheme.gold)
                        .tracking(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ChronosTheme.gold.opacity(0.35), lineWidth: 1)
                        )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ChronosTheme.border, lineWidth: 1))
        )
    }

    private func runResync() {
        guard let userId = supabase.session?.userId else { return }
        isResyncing = true
        progress = 0
        total = 0
        isDone = false
        errorMessage = nil

        Task {
            do {
                try await SyncCoordinator.shared.runBaselineBootstrap(
                    userId: userId
                ) { done, t in
                    Task { @MainActor in
                        self.progress = done
                        self.total = t
                    }
                }
                await sync.loadDashboard(userId: userId)
                isDone = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isResyncing = false
        }
    }
}

// ─────────────────────────────────────────
// SHARED SUBCOMPONENTS
// ─────────────────────────────────────────

struct AccountStatsPills: View {
    let score: DailyScore

    var body: some View {
        HStack(spacing: 10) {
            AccountStatPill(label: "Today",
                            value: "\(Int(score.chronosScore))",
                            color: ChronosTheme.goldLight)
            AccountStatPill(label: "D1",
                            value: score.d1Autonomic.map { "\(Int($0))" } ?? "—",
                            color: domainColor(score.d1Autonomic))
            AccountStatPill(label: "D2",
                            value: score.d2Sleep.map { "\(Int($0))" } ?? "—",
                            color: domainColor(score.d2Sleep))
            AccountStatPill(label: "D3",
                            value: score.d3Activity.map { "\(Int($0))" } ?? "—",
                            color: domainColor(score.d3Activity))
        }
    }

    private func domainColor(_ val: Double?) -> Color {
        guard let v = val else { return ChronosTheme.faint }
        if v >= 80 { return Color(red: 0.40, green: 0.82, blue: 0.50) }
        if v >= 60 { return ChronosTheme.goldLight }
        if v >= 40 { return Color(red: 1.0, green: 0.78, blue: 0.28) }
        return Color(red: 1.0, green: 0.40, blue: 0.40)
    }
}

struct AccountStatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.cormorant(size: 20, weight: .light))
                .foregroundColor(color)
            Text(label.uppercased())
                .font(.jost(size: 8, weight: .light))
                .foregroundColor(ChronosTheme.muted)
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(ChronosTheme.border, lineWidth: 1))
        )
    }
}

struct AccountRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = ChronosTheme.muted

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.gold)
                .frame(width: 20)
            Text(label)
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.text)
            Spacer()
            Text(value)
                .font(.jost(size: 12, weight: .light))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ChronosTheme.border, lineWidth: 1))
        )
    }
}

struct AccountInfoNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(ChronosTheme.gold.opacity(0.5))
                .padding(.top, 1)
            Text(text)
                .font(.jost(size: 11, weight: .light))
                .foregroundColor(ChronosTheme.faint)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}


