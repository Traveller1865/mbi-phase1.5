// ios/MBI/MBI/Views/AdminView.swift
// MBI Phase 1.5 — Admin View

import SwiftUI

struct AdminUserSummary: Identifiable {
    let id = UUID()
    let displayName: String
    let scores: [AdminScoreRow]

    var latestScore: Double? { scores.first?.chronosScore }
    var latestBand: String? { scores.first?.scoreBand }
    var trend: [Double] { scores.prefix(7).map { $0.chronosScore }.reversed() }
}

struct AdminScoreRow: Identifiable {
    let id = UUID()
    let date: String
    let chronosScore: Double
    let scoreBand: String
    let driver1: String
    let driver2: String
    let failState: String?
    let isProvisional: Bool
}

struct AdminView: View {
    @EnvironmentObject var supabase: SupabaseService
    @EnvironmentObject var sync: SyncCoordinator
    @State private var users: [AdminUserSummary] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var isResyncing = false
    @State private var resyncProgress = 0
    @State private var resyncTotal = 0
    @State private var resyncDone = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                HStack {
                    Text("Admin")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: load) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // ── Re-sync History Card ──
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Full History Sync")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Text("Read all available HealthKit history and score each day.")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .lineSpacing(3)
                        }
                        Spacer()
                        if resyncDone {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green.opacity(0.7))
                                .font(.system(size: 20))
                        }
                    }

                    if isResyncing {
                        VStack(spacing: 8) {
                            ProgressView(
                                value: resyncTotal > 0 ? Double(resyncProgress) : 0,
                                total: resyncTotal > 0 ? Double(resyncTotal) : 1
                            )
                            .tint(.white)

                            Text(resyncTotal == 0
                                 ? "Scanning history..."
                                 : "Processing day \(resyncProgress) of \(resyncTotal)...")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else {
                        Button(action: runResync) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(resyncDone ? "Sync Again" : "Start Full Sync")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // ── Users ──
                if isLoading {
                    Spacer()
                    ProgressView().tint(.white.opacity(0.5))
                    Spacer()
                } else if let error = error {
                    Spacer()
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                    Spacer()
                } else if users.isEmpty {
                    Spacer()
                    Text("No users yet.")
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(users) { user in
                                AdminUserCard(user: user)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task { load() }
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let raw = try await supabase.fetchAdminData()
                users = raw.compactMap { parseUser($0) }
            } catch {
                self.error = "Admin data unavailable."
            }
            isLoading = false
        }
    }

    private func runResync() {
        guard let userId = supabase.session?.userId else { return }
        isResyncing = true
        resyncProgress = 0
        resyncTotal = 0
        resyncDone = false

        Task {
            do {
                try await SyncCoordinator.shared.runBaselineBootstrap(
                    userId: userId
                ) { done, total in
                    Task { @MainActor in
                        self.resyncProgress = done
                        self.resyncTotal = total
                    }
                }
                resyncDone = true
                // Reload admin data and dashboard after sync
                load()
            } catch {
                self.error = "Sync failed: \(error.localizedDescription)"
            }
            isResyncing = false
        }
    }

    private func parseUser(_ dict: [String: Any]) -> AdminUserSummary? {
        guard let name = dict["display_name"] as? String,
              let rawScores = dict["scores"] as? [[String: Any]] else { return nil }

        let scores = rawScores.compactMap { s -> AdminScoreRow? in
            guard let date = s["date"] as? String,
                  let score = s["chronos_score"] as? Double,
                  let band = s["score_band"] as? String else { return nil }
            return AdminScoreRow(
                date: date,
                chronosScore: score,
                scoreBand: band,
                driver1: (s["driver_1"] as? String) ?? "—",
                driver2: (s["driver_2"] as? String) ?? "—",
                failState: s["fail_state"] as? String,
                isProvisional: (s["is_provisional"] as? Bool) ?? false
            )
        }

        return AdminUserSummary(displayName: name, scores: scores)
    }
}

struct AdminUserCard: View {
    let user: AdminUserSummary
    @State private var isExpanded = false

    var bandColor: Color {
        switch user.latestBand {
        case "Thriving":  return Color(red: 0.3, green: 0.85, blue: 0.5)
        case "Recovering": return Color(red: 0.4, green: 0.7,  blue: 1.0)
        case "Drifting":  return Color(red: 1.0, green: 0.75, blue: 0.2)
        case "Redline":   return Color(red: 1.0, green: 0.35, blue: 0.35)
        default: return .white.opacity(0.4)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        if let band = user.latestBand {
                            Text(band)
                                .font(.system(size: 12))
                                .foregroundColor(bandColor)
                        }
                    }
                    Spacer()
                    if user.trend.count > 1 {
                        MiniSparkline(scores: user.trend)
                            .frame(width: 60, height: 24)
                    }
                    if let score = user.latestScore {
                        Text("\(Int(score))")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(bandColor)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(16)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                    ForEach(user.scores.prefix(7)) { row in
                        AdminScoreRowView(row: row)
                        if row.id != user.scores.prefix(7).last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }
}

struct AdminScoreRowView: View {
    let row: AdminScoreRow

    var body: some View {
        HStack {
            Text(row.date)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            if let fail = row.failState {
                Text(fail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
            if row.isProvisional {
                Text("provisional")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.25))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
            }
            Text("\(row.driver1) · \(row.driver2)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.35))
            Text("\(Int(row.chronosScore))")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct MiniSparkline: View {
    let scores: [Double]

    var body: some View {
        Canvas { context, size in
            guard scores.count > 1 else { return }
            let min = (scores.min() ?? 0) - 5
            let max = (scores.max() ?? 100) + 5
            let range = max - min
            let step = size.width / CGFloat(scores.count - 1)
            var path = Path()
            for (i, score) in scores.enumerated() {
                let x = CGFloat(i) * step
                let y = size.height - CGFloat((score - min) / range) * size.height
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 1.5)
        }
    }
}
