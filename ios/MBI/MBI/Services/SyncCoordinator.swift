// ios/MBI/Services/SyncCoordinator.swift
// MBI Phase 1 — Sync Coordinator
// Orchestrates: HealthKit reads → ingest → score → narrate
// iOS client never computes or interprets values.

import Foundation

enum SyncState: Equatable {
    case idle
    case syncing(String)
    case complete
    case failed(String)
    case stale // cached data, sync not yet run this session
}

@MainActor
class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    @Published var syncState: SyncState = .idle
    @Published var dashboard: DashboardData?
    @Published var lastSyncDate: Date?
    @Published var trendData: [TrendPoint] = []

    private let healthKit = HealthKitManager.shared
    private let supabase = SupabaseService.shared

    // ─────────────────────────────────────────
    // DAILY SYNC — triggered on app open
    // ─────────────────────────────────────────

    func runDailySync(userId: String) async {
        guard syncState != .syncing("") else { return }

        // Check if already synced today
        if let last = lastSyncDate, Calendar.current.isDateInToday(last) {
            await loadDashboard(userId: userId)
            return
        }

        syncState = .syncing("Reading Apple Health data...")

        do {
            // 1. Read yesterday's metrics from HealthKit
            let metrics = try await healthKit.readYesterday()

            syncState = .syncing("Syncing to server...")

            // 2. Send to ingest → score → narrate pipeline
            let payload = metrics.toPayloadDict(userId: userId)
            let timeOfDay = TimeOfDay.current.rawValue   // "morning" | "daytime" | "evening"
            try await supabase.triggerDailySync(userId: userId, payload: payload)

            // 3. Load dashboard
            syncState = .syncing("Loading your score...")
            await loadDashboard(userId: userId)

            lastSyncDate = Date()
            syncState = .complete

        } catch {
            let msg = error.localizedDescription
            // 404 means no data for today — not an error, just empty
            if msg.contains("404") {
                syncState = .complete
            } else {
                syncState = .failed(msg)
            }
            // Still try to load cached dashboard
            await loadDashboard(userId: userId)
        }
    }

    // ─────────────────────────────────────────
    // BASELINE BOOTSTRAP — first launch
    // Reads 7 days of history, sends all at once
    // ─────────────────────────────────────────

    func runBaselineBootstrap(userId: String, onProgress: @escaping (Int, Int) -> Void) async throws {
        syncState = .syncing("Reading your Apple Health history...")

        // Read full available history, up to 90 days
        let history = try await healthKit.readFullHistory(maxDays: 90)
        let total = max(history.count, 1)

        // Signal the total to the UI immediately so progress bar renders correctly
        onProgress(0, total)

        for (i, day) in history.enumerated() {
            onProgress(i + 1, total)
            let payload = day.toPayloadDict(userId: userId)
            do {
                try await supabase.triggerDailySync(userId: userId, payload: payload)
            } catch {
                // Log but don't crash — partial history is handled gracefully
                print("[bootstrap] Day \(day.date) failed: \(error)")
            }
        }

        await loadDashboard(userId: userId)
        lastSyncDate = Date()
        syncState = .complete
    }

    // ─────────────────────────────────────────
    // LOAD DASHBOARD (from Supabase)
    // ─────────────────────────────────────────

    func loadDashboard(userId: String) async {
        do {
            // Try today first
            if let data = try await supabase.fetchTodayDashboard(userId: userId) {
                dashboard = data
                return
            }
            // Fall back to most recent score
            if let data = try await supabase.fetchMostRecentDashboard(userId:userId){
                dashboard = data
            } else {
                print("[loadDashboard] fetchMostRecentDashboard returned nil")
            }
        } catch {
            print("[loadDashboard] \(error)")
        }
    }
    
    func loadTrendData(userId: String) async {
        do {
            let points = try await supabase.fetchTrendData(userId: userId)
            trendData = points
        } catch {
            print("[loadTrendData] \(error)")
        }
    }

    func markStale() {
        syncState = .stale
    }
}
